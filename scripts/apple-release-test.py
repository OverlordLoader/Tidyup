import importlib.util
from pathlib import Path
import re
import unittest
import json
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release', Path(__file__).with_name('apple-release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

class ReleaseSafetyTests(unittest.TestCase):
    def setUp(self):
        self.source = Path('ios/App/App.xcodeproj/project.pbxproj').read_text()
        self.bundle = re.search(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', self.source).group(1)
        self.uuid = '3ac5606f-04f1-4fef-afee-a562ada63754'

    def test_actual_project_changes_only_two_app_configurations(self):
        changed = release.configure_project(self.source,self.bundle,self.uuid,'1')
        self.assertEqual(changed.count('PROVISIONING_PROFILE_SPECIFIER = '),2)
        self.assertEqual(changed.count('CODE_SIGN_STYLE = Manual;'),2)
        self.assertEqual(changed.count('DEVELOPMENT_TEAM = 5U37FQG3VS;'),2)
        self.assertIn('CODE_SIGN_IDENTITY = "iPhone Developer";',changed)
        self.assertEqual(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;',changed),re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;',self.source))

    def test_wrong_app_profile_and_injected_input_are_rejected(self):
        for build in ('0','10000','1; CODE_SIGNING_ALLOWED = NO','1\n2','1.100'):
            with self.assertRaises(RuntimeError):
                release.configure_project(self.source,self.bundle,self.uuid,build)
        with self.assertRaises(RuntimeError):
            release.configure_project(self.source,'com.example.unknown',self.uuid,'1')
        with self.assertRaises(RuntimeError):
            release.configure_project(self.source,self.bundle,'unsafe;value','1')
        other = next(x for x in release.ALLOWED if x != self.bundle)
        with self.assertRaises(RuntimeError):
            release.configure_project(self.source,other,self.uuid,'1')

    def test_new_native_targets_require_explicit_signing_review(self):
        with self.assertRaises(RuntimeError):
            release.configure_project(self.source.replace(self.bundle,'com.example.extension',1),self.bundle,self.uuid,'1')

    def test_development_profile_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'Development/debug'):
            release.validate_profile({'TeamIdentifier':[release.TEAM],'Entitlements':{'application-identifier':release.TEAM+'.'+self.bundle,'get-task-allow':True}},self.bundle)

    def test_failed_signing_command_does_not_expose_credentials(self):
        with patch.object(release.subprocess, 'run') as run:
            run.return_value.returncode = 1
            with self.assertRaises(RuntimeError) as error:
                release.run_command(['security','import','certificate.p12','-P','secret-marker'],True)
            self.assertNotIn('secret-marker',str(error.exception))
            self.assertNotIn('certificate.p12',str(error.exception))
            self.assertFalse(run.call_args.kwargs['check'])

    def test_apple_zero_exit_is_not_delivery_confirmation(self):
        for result in ({'product-errors':[{'code':409}]},{'errors':['Rejected']},{},{'success-message':'No errors validating archive.'}):
            with self.assertRaises(RuntimeError):
                release.confirm_apple_result(json.dumps(result),'upload')
        with self.assertRaises(RuntimeError):
            release.confirm_apple_result('not JSON','upload')

    def test_apple_requires_matching_positive_confirmation(self):
        release.confirm_apple_result(json.dumps({'success-message':'No errors validating archive.'}),'validation')
        release.confirm_apple_result(json.dumps({'success-message':'No errors uploading archive.'}),'upload')

if __name__ == '__main__':
    unittest.main()
