"""Sign and validate one reviewed iOS release on an isolated macOS runner."""
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess
import sys
import zipfile

TEAM = '5U37FQG3VS'
CERT_SHA256 = 'AD55F104A48F3C2962B61298645C20617180F75EACA0A29B982AB5A263AC1B1B'
ALLOWED = {'com.velioraworks.seena', 'com.ourveliora.parenting', 'app.nomondaydiet.app', 'com.celesthread.app', 'app.tidyup.game'}
KEY_ID = '6K3UZ87UDR'
ISSUER = '771d7892-7290-42e8-b8be-b7154988b623'

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def run_command(args, capture=False, cwd=None):
    # A CalledProcessError includes argv, which may contain a keychain password.
    result = subprocess.run([str(x) for x in args], cwd=cwd, check=False, stdout=subprocess.PIPE if capture else None)
    require(result.returncode == 0, Path(str(args[0])).name + ' failed with exit code ' + str(result.returncode))
    return result.stdout if capture else None

def confirm_apple_result(raw, operation):
    require(operation in ('validation','upload'), 'Unknown Apple operation')
    try:
        result = json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        raise RuntimeError('Apple returned an unrecognized response; delivery is not confirmed') from None
    require(isinstance(result,dict), 'Apple returned an unexpected response shape')
    errors = result.get('product-errors') or result.get('errors') or result.get('error')
    if errors:
        print(json.dumps({'appleOperation':operation,'errors':errors}))
    require(not errors, 'Apple reported an error; delivery is not confirmed')
    message = result.get('success-message','')
    expected = 'No errors validating' if operation == 'validation' else 'No errors uploading'
    require(isinstance(message,str) and message.startswith(expected), 'Apple did not explicitly confirm '+operation)
    print(json.dumps({'appleOperation':operation,'confirmed':True,'message':message}))

def validate_profile(profile, bundle):
    require(bundle in ALLOWED, 'Unknown app identity')
    ent = profile['Entitlements']
    require(profile['TeamIdentifier'] == [TEAM], 'Profile belongs to another team')
    require(ent['application-identifier'] == TEAM + '.' + bundle, 'Profile belongs to another app')
    require(ent.get('get-task-allow',False) is False, 'Development/debug profile rejected')
    require(not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'), 'Not an App Store profile')
    require(profile['ExpirationDate'].replace(tzinfo=dt.timezone.utc) > dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=1), 'Profile expires too soon')
    certificates = profile['DeveloperCertificates']
    require(len(certificates) == 1 and hashlib.sha256(certificates[0]).hexdigest().upper() == CERT_SHA256, 'Wrong distribution certificate')
    require(bool(ent.get('com.apple.developer.healthkit')) == (bundle == 'app.nomondaydiet.app'), 'Unexpected HealthKit permission')
    return profile['UUID']

def configure_project(text, bundle, profile_uuid, build):
    require(bundle in ALLOWED, 'Unknown app identity')
    require(re.fullmatch(r'[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}', build), 'Invalid Apple build number')
    require(re.fullmatch(r'[A-Fa-f0-9-]{36}', profile_uuid), 'Invalid profile identifier')
    changed = 0
    def replace(match):
        nonlocal changed
        body = match.group(1)
        identifier = re.search(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([^";]+)"?;', body)
        if not identifier:
            return match.group(0)
        require(identifier.group(1) == bundle, 'Unexpected native target; signing needs explicit review')
        settings = {'CODE_SIGN_STYLE':'Manual', 'DEVELOPMENT_TEAM':TEAM, 'CODE_SIGN_IDENTITY':'"Apple Distribution"', 'PROVISIONING_PROFILE_SPECIFIER':'"'+profile_uuid+'"', 'CURRENT_PROJECT_VERSION':build}
        for field, value in settings.items():
            expression = r'(?m)^\s*' + field + r'\s*=\s*[^;]+;'
            body = re.sub(expression, '\n\t\t\t\t'+field+' = '+value+';', body) if re.search(expression,body) else body+'\n\t\t\t\t'+field+' = '+value+';'
        changed += 1
        return 'buildSettings = {'+body+'\n'+match.group(2)+'};'
    result = re.sub(r'buildSettings = \{([\s\S]*?)\n(\s*)};', replace, text)
    require(changed == 2, 'Expected exactly the App Debug and Release target configurations')
    return result

def run_release():
    require(sys.platform == 'darwin', 'Signing requires the macOS build runner')
    require(os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'Only an explicit release dispatch can sign')
    require(os.environ.get('GITHUB_REF') == os.environ['RELEASE_REF'], 'Only the reviewed release branch can sign')
    bundle = os.environ['APP_BUNDLE_ID']
    build = os.environ['RELEASE_BUILD_NUMBER']
    require(bundle in ALLOWED, 'Unknown app identity')
    require(os.environ.get('UPLOAD_TO_APPLE') in ('true','false'), 'Invalid upload decision')
    upload = os.environ['UPLOAD_TO_APPLE'] == 'true'
    root = Path.cwd()
    temp_root = Path(os.environ['RUNNER_TEMP']).resolve()
    work = temp_root / 'orizon-apple-release'
    require(not work.exists(), 'Signing workspace already exists')
    work.mkdir(mode=0o700)
    keychain = work / 'signing.keychain-db'
    keychain_password = secrets.token_hex(32)
    profile_targets = []
    old_keychains = []
    os.umask(0o077)
    output = root / 'release-output'
    output.mkdir(exist_ok=True)
    secret_names = ('APPLE_DISTRIBUTION_P12_BASE64','APPLE_DISTRIBUTION_P12_PASSWORD','APPLE_PROFILE_BASE64','APP_STORE_CONNECT_KEY_BASE64')
    values = {name: os.environ.pop(name, '') for name in secret_names}
    require(all(values.values()), 'Signing credentials are not configured')
    def command(args, capture=False, cwd=root):
        return run_command(args, capture, cwd)
    try:
        p12 = work / 'distribution.p12'
        profile_path = work / 'distribution.mobileprovision'
        p12.write_bytes(base64.b64decode(values['APPLE_DISTRIBUTION_P12_BASE64'], validate=True))
        profile_path.write_bytes(base64.b64decode(values['APPLE_PROFILE_BASE64'], validate=True))
        key_dir = work / 'private_keys'
        key_dir.mkdir(mode=0o700)
        (key_dir / ('AuthKey_'+KEY_ID+'.p8')).write_bytes(base64.b64decode(values['APP_STORE_CONNECT_KEY_BASE64'], validate=True))
        os.environ['API_PRIVATE_KEYS_DIR'] = str(key_dir.resolve())
        profile = plistlib.loads(command(['security','cms','-D','-i',profile_path], True))
        profile_uuid = validate_profile(profile,bundle)
        old_keychains = re.findall(r'"([^"\n]+)"',command(['security','list-keychains','-d','user'],True).decode())
        command(['security','create-keychain','-p',keychain_password,keychain],True)
        command(['security','set-keychain-settings','-lut','7200',keychain],True)
        command(['security','unlock-keychain','-p',keychain_password,keychain],True)
        command(['security','import',p12,'-P',values['APPLE_DISTRIBUTION_P12_PASSWORD'],'-k',keychain,'-T','/usr/bin/codesign','-T','/usr/bin/security'],True)
        values.clear()
        command(['security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',keychain_password,keychain],True)
        command(['security','list-keychains','-d','user','-s',keychain,*old_keychains],True)
        identities = command(['security','find-identity','-v','-p','codesigning',keychain],True).decode()
        require('Apple Distribution: ORIZON SYSTEMS LLC ('+TEAM+')' in identities, 'macOS cannot validate the distribution signing identity')
        for directory in (Path.home()/'Library/MobileDevice/Provisioning Profiles', Path.home()/'Library/Developer/Xcode/UserData/Provisioning Profiles'):
            directory.mkdir(parents=True,exist_ok=True)
            target = directory/(profile_uuid+'.mobileprovision')
            require(not target.exists(), 'Refusing to overwrite an existing runner profile')
            shutil.copyfile(profile_path,target)
            profile_targets.append(target)
        project = root/'ios/App/App.xcodeproj/project.pbxproj'
        project.write_text(configure_project(project.read_text(),bundle,profile_uuid,build))
        xcode = command(['xcodebuild','-version'],True).decode()
        require(int(re.search(r'Xcode (\d+)',xcode).group(1)) >= 26, 'Xcode 26 or later is required')
        sdk = command(['xcrun','--sdk','iphoneos','--show-sdk-version'],True).decode().strip()
        require(int(sdk.split('.')[0]) >= 26, 'iOS 26 SDK or later is required')
        archive = work/'App.xcarchive'
        command(['xcodebuild','-project','ios/App/App.xcodeproj','-scheme','App','-configuration','Release','-sdk','iphoneos','-destination','generic/platform=iOS','-archivePath',archive,'-derivedDataPath',work/'DerivedData','archive'])
        options = {'method':'app-store-connect','destination':'export','teamID':TEAM,'signingStyle':'manual','signingCertificate':'Apple Distribution','provisioningProfiles':{bundle:profile_uuid},'manageAppVersionAndBuildNumber':False,'stripSwiftSymbols':True}
        export_options = work/'ExportOptions.plist'
        export_options.write_bytes(plistlib.dumps(options))
        command(['xcodebuild','-exportArchive','-archivePath',archive,'-exportPath',work/'export','-exportOptionsPlist',export_options])
        ipas = list((work/'export').glob('*.ipa'))
        require(len(ipas) == 1, 'Expected exactly one exported IPA')
        expanded = work/'verification'
        with zipfile.ZipFile(ipas[0]) as package:
            require(all(not n.startswith('/') and '..' not in Path(n).parts for n in package.namelist()), 'Unsafe archive member')
        command(['ditto','-x','-k',ipas[0],expanded])
        apps = list((expanded/'Payload').glob('*.app'))
        require(len(apps) == 1, 'Expected one application payload')
        app = apps[0]
        command(['codesign','--verify','--deep','--strict',app])
        info = plistlib.loads((app/'Info.plist').read_bytes())
        require(info['CFBundleIdentifier'] == bundle and info['CFBundleVersion'] == build, 'Exported identity/version mismatch')
        require(info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], 'Simulator export rejected')
        embedded = plistlib.loads(command(['security','cms','-D','-i',app/'embedded.mobileprovision'],True))
        require(validate_profile(embedded,bundle) == profile_uuid, 'Export used another profile')
        entitlements = plistlib.loads(command(['codesign','-d','--entitlements',':-',app],True))
        require(entitlements.get('application-identifier') == TEAM+'.'+bundle and entitlements.get('get-task-allow',False) is False, 'Invalid signed app entitlements')
        require(bool(entitlements.get('com.apple.developer.healthkit')) == (bundle == 'app.nomondaydiet.app'), 'Signed HealthKit entitlements differ')
        executable = app/info['CFBundleExecutable']
        require('arm64' in command(['lipo','-archs',executable],True).decode().split(), 'Missing arm64 device executable')
        manifests = list(app.rglob('PrivacyInfo.xcprivacy'))
        require(bool(manifests), 'No packaged privacy manifests')
        for manifest in manifests:
            require(plistlib.loads(manifest.read_bytes()).get('NSPrivacyTracking') is not True, 'Unexpected tracking declaration')
        ipa = output/'App.ipa'
        shutil.copyfile(ipas[0],ipa)
        receipt = {'bundleId':bundle,'team':TEAM,'buildNumber':build,'version':info['CFBundleShortVersionString'],'sourceCommit':os.environ['GITHUB_SHA'],'profileUuid':profile_uuid,'certificateSha256':CERT_SHA256,'ipaSha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),'bytes':ipa.stat().st_size,'sdk':sdk,'xcode':xcode.strip(),'privacyManifestCount':len(manifests),'signatureVerified':True,'appleValidation':False,'uploaded':False,'appReviewSubmitted':False,'checkedAt':dt.datetime.now(dt.timezone.utc).isoformat()}
        receipt_path = output/'release-manifest.json'
        receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
        confirmation = command(['xcrun','altool','--validate-app','--type','ios','--file',ipa,'--apiKey',KEY_ID,'--apiIssuer',ISSUER,'--output-format','json'],capture=True,cwd=work)
        confirm_apple_result(confirmation,'validation')
        receipt['appleValidation'] = True
        receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
        if upload:
            confirmation = command(['xcrun','altool','--upload-app','--type','ios','--file',ipa,'--apiKey',KEY_ID,'--apiIssuer',ISSUER,'--output-format','json'],capture=True,cwd=work)
            confirm_apple_result(confirmation,'upload')
            receipt['uploaded'] = True
            receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
        print(json.dumps(receipt,indent=2))
    finally:
        values.clear()
        os.environ.pop('API_PRIVATE_KEYS_DIR',None)
        if old_keychains:
            subprocess.run(['security','list-keychains','-d','user','-s',*old_keychains],check=False,stdout=subprocess.DEVNULL)
        if keychain.exists():
            subprocess.run(['security','delete-keychain',str(keychain)],check=False,stdout=subprocess.DEVNULL)
        for target in profile_targets:
            target.unlink(missing_ok=True)
        require(work.parent == temp_root and work.name == 'orizon-apple-release', 'Unsafe cleanup path')
        shutil.rmtree(work)

if __name__ == '__main__':
    run_release()
