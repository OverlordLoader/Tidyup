#!/usr/bin/env python3
"""Regenerate ios/App/App.xcodeproj/project.pbxproj and the App.xcscheme.

Run from the repo root:  python3 scripts/generate_project.py
The output is deterministic; commit the results.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJ_DIR = ROOT / "ios/App/App.xcodeproj"
SCHEME_DIR = PROJ_DIR / "xcshareddata/xcschemes"

SWIFT_SOURCES = [
    "TidyUpApp.swift",
    "Game/Palette.swift",
    "Game/Models.swift",
    "Game/LevelGenerator.swift",
    "Game/GameEngine.swift",
    "Game/SoundManager.swift",
    "Game/Haptics.swift",
    "Game/ProgressStore.swift",
    "Game/AdsManager.swift",
    "Game/StoreManager.swift",
    "Game/Views/ContentView.swift",
    "Game/Views/LevelSelectView.swift",
    "Game/Views/GameView.swift",
    "Game/Views/BoardScene.swift",
    "Game/Views/TubeNode.swift",
    "Game/Views/SettingsView.swift",
]
RESOURCE_FILES = [
    ("Assets.xcassets", "wrapper.assetcatalog"),
    ("PrivacyInfo.xcprivacy", "text.plist.xml"),
]
FRAMEWORKS = ["SpriteKit.framework", "AVFoundation.framework", "StoreKit.framework"]

# Swift Package Manager dependencies. Each entry becomes an
# XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency.
SPM_PACKAGES = [
    {
        "name": "swift-package-manager-google-mobile-ads",
        "url": "https://github.com/googleads/swift-package-manager-google-mobile-ads",
        "kind": "upToNextMajorVersion",
        "minimumVersion": "12.0.0",
        "products": ["GoogleMobileAds"],
    },
]

_ids = {}
_counter = [0]

def nid(name):
    if name not in _ids:
        _counter[0] += 1
        _ids[name] = "%024X" % _counter[0]
    return _ids[name]

def main():
    L = []
    a = L.append
    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {")
    a("\t};")
    a("\tobjectVersion = 56;")
    a("\tobjects = {")

    # ---- file references ----
    for src in SWIFT_SOURCES:
        fid = nid("file:" + src)
        a(f"\t\t{fid} /* {src} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {src}; sourceTree = \"<group>\"; }};")
    for res, ftype in RESOURCE_FILES:
        fid = nid("file:" + res)
        a(f"\t\t{fid} /* {res} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {res}; sourceTree = \"<group>\"; }};")
    plist_id = nid("file:Info.plist")
    a(f"\t\t{plist_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    for fw in FRAMEWORKS:
        fid = nid("file:" + fw)
        a(f"\t\t{fid} /* {fw} */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {fw}; path = System/Library/Frameworks/{fw}; sourceTree = SDKROOT; }};")
    app_product_id = nid("product:App.app")
    a(f"\t\t{app_product_id} /* App.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = App.app; sourceTree = BUILT_PRODUCTS_DIR; }};")

    # ---- build files ----
    for src in SWIFT_SOURCES:
        bid = nid("build:" + src)
        a(f"\t\t{bid} /* {src} in Sources */ = {{isa = PBXBuildFile; fileRef = {nid('file:' + src)} /* {src} */; }};")
    for res, _ in RESOURCE_FILES:
        bid = nid("buildres:" + res)
        a(f"\t\t{bid} /* {res} in Resources */ = {{isa = PBXBuildFile; fileRef = {nid('file:' + res)} /* {res} */; }};")
    for fw in FRAMEWORKS:
        bid = nid("buildfw:" + fw)
        a(f"\t\t{bid} /* {fw} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {nid('file:' + fw)} /* {fw} */; }};")

    # ---- Swift packages ----
    spm_pkg_ids = []
    spm_dep_ids = []
    for pkg in SPM_PACKAGES:
        pkg_id = nid("spmpkg:" + pkg["name"])
        spm_pkg_ids.append(pkg_id)
        a(f"\t\t{pkg_id} /* XCRemoteSwiftPackageReference \"{pkg['name']}\" */ = {{isa = XCRemoteSwiftPackageReference; repositoryURL = \"{pkg['url']}\"; requirement = {{kind = {pkg['kind']}; minimumVersion = {pkg['minimumVersion']}; }}; }};")
        for product in pkg["products"]:
            dep_id = nid("spmdep:" + pkg["name"] + ":" + product)
            spm_dep_ids.append(dep_id)
            a(f"\t\t{dep_id} /* {product} */ = {{isa = XCSwiftPackageProductDependency; package = {pkg_id} /* XCRemoteSwiftPackageReference \"{pkg['name']}\" */; productName = {product}; }};")

    # ---- phases ----
    sources_id = nid("phase:sources")
    a(f"\t\t{sources_id} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (")
    for src in SWIFT_SOURCES:
        a(f"\t\t\t{nid('build:' + src)} /* {src} in Sources */,")
    a("\t\t); runOnlyForDeploymentPostprocessing = 0; };")
    fw_id = nid("phase:frameworks")
    a(f"\t\t{fw_id} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (")
    for fw in FRAMEWORKS:
        a(f"\t\t\t{nid('buildfw:' + fw)} /* {fw} in Frameworks */,")
    a("\t\t); runOnlyForDeploymentPostprocessing = 0; };")
    res_id = nid("phase:resources")
    a(f"\t\t{res_id} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (")
    for res, _ in RESOURCE_FILES:
        a(f"\t\t\t{nid('buildres:' + res)} /* {res} in Resources */,")
    a("\t\t); runOnlyForDeploymentPostprocessing = 0; };")

    # ---- groups ----
    def group(gid_name, children, path=None, comment=""):
        gid = nid(gid_name)
        a(f"\t\t{gid} /* {comment} */ = {{isa = PBXGroup; children = (")
        for c in children:
            a(f"\t\t\t{c},")
        a("\t\t); " + (f"path = {path}; " if path else "") + 'sourceTree = "<group>"; };')
        return gid
    views_children = [nid("file:" + s) for s in SWIFT_SOURCES if s.startswith("Game/Views/")]
    game_children = [nid("file:" + s) for s in SWIFT_SOURCES if s.startswith("Game/") and "/" not in s[len("Game/"):]] + [nid("group:Views")]
    app_children = [nid("file:TidyUpApp.swift"), plist_id, nid("file:Assets.xcassets"), nid("file:PrivacyInfo.xcprivacy"), nid("group:Game")]
    group("group:Views", views_children, comment="Views")
    group("group:Game", game_children, comment="Game")
    group("group:App", app_children, path="App", comment="App")
    group("group:Products", [app_product_id], comment="Products")
    main_children = [nid("group:App"), nid("group:Products")]
    main_gid = nid("group:main")
    a(f"\t\t{main_gid} = {{isa = PBXGroup; children = (")
    for c in main_children:
        a(f"\t\t\t{c},")
    a('\t\t); sourceTree = "<group>"; };')

    # ---- target ----
    target_id = nid("target:App")
    target_cfg_list = nid("cfglist:target")
    a(f"\t\t{target_id} /* App */ = {{isa = PBXNativeTarget; buildConfigurationList = {target_cfg_list} /* Build configuration list for PBXNativeTarget \"App\" */; buildPhases = (")
    a(f"\t\t\t{sources_id} /* Sources */,")
    a(f"\t\t\t{fw_id} /* Frameworks */,")
    a(f"\t\t\t{res_id} /* Resources */,")
    a("\t\t); buildRules = (")
    a("\t\t); dependencies = (")
    a("\t\t); name = App;")
    if spm_dep_ids:
        a("\t\t\tpackageProductDependencies = (")
        for dep_id in spm_dep_ids:
            a(f"\t\t\t\t{dep_id} /* GoogleMobileAds */,")
        a("\t\t\t);")
    a("\t\tproductName = App; productReference = " + app_product_id + " /* App.app */; productType = \"com.apple.product-type.application\"; };")

    # ---- project ----
    project_id = nid("project")
    project_cfg_list = nid("cfglist:project")
    a(f"\t\t{project_id} /* Project object */ = {{")
    a("\t\t\tisa = PBXProject;")
    a(f"\t\t\tbuildConfigurationList = {project_cfg_list} /* Build configuration list for PBXProject */;")
    a("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a("\t\t\tdevelopmentRegion = en;")
    a("\t\t\thasScannedForEncodings = 0;")
    if spm_pkg_ids:
        a("\t\t\tpackageReferences = (")
        for pkg_id in spm_pkg_ids:
            a(f"\t\t\t\t{pkg_id} /* XCRemoteSwiftPackageReference \"swift-package-manager-google-mobile-ads\" */,")
        a("\t\t\t);")
    a(f"\t\t\tmainGroup = {main_gid};")
    a("\t\t\tproductRefGroup = " + nid("group:Products") + " /* Products */;")
    a("\t\t\tprojectDirPath = \"\";")
    a("\t\t\tprojectRoot = \"\";")
    a("\t\t\ttargets = (")
    a(f"\t\t\t\t{target_id} /* App */,")
    a("\t\t\t);")
    a("\t\t};")

    # ---- configurations ----
    def xcconfig(name, settings):
        cid = nid("config:" + name)
        a(f"\t\t{cid} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{")
        for k, v in settings.items():
            a(f"\t\t\t\t{k} = {v};")
        a("\t\t\t};")
        a(f"\t\t\tname = {name.split(':')[1]};")
        a("\t\t};")
        return cid
    proj_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "CODE_SIGN_IDENTITY": '"iPhone Developer"',
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJ_MSGSEND": "YES",
        "ENABLE_TESTABILITY": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0",
    }
    proj_debug = dict(proj_common); proj_debug["MTL_ENABLE_DEBUG_INFO"] = "INCLUDE_SOURCE"
    proj_release = dict(proj_common); proj_release.update({"COPY_PHASE_STRIP": "NO", "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"', "ENABLE_NS_ASSERTIONS": "NO", "MTL_ENABLE_DEBUG_INFO": "NO"})
    d1 = xcconfig("project:Debug", proj_debug)
    r1 = xcconfig("project:Release", proj_release)
    a(f"\t\t{project_cfg_list} /* Build configuration list for PBXProject */ = {{isa = XCConfigurationList; buildConfigurations = ({d1} /* Debug */, {r1} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")

    tgt_common = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "5U37FQG3VS",
        "INFOPLIST_FILE": "App/Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "app.tidyup.game",
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    tgt_debug = dict(tgt_common)
    tgt_release = dict(tgt_common); tgt_release["SWIFT_OPTIMIZATION_LEVEL"] = '"-O"'
    d2 = xcconfig("target:Debug", tgt_debug)
    r2 = xcconfig("target:Release", tgt_release)
    a(f"\t\t{target_cfg_list} /* Build configuration list for PBXNativeTarget \"App\" */ = {{isa = XCConfigurationList; buildConfigurations = ({d2} /* Debug */, {r2} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")

    a("\t};")
    a("\trootObject = " + project_id + " /* Project object */;")
    a("}")

    PROJ_DIR.mkdir(parents=True, exist_ok=True)
    (PROJ_DIR / "project.pbxproj").write_text("\n".join(L) + "\n")

    # ---- scheme ----
    SCHEME_DIR.mkdir(parents=True, exist_ok=True)
    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES" runPostActionsOnFailure = "NO">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{target_id}" BuildableName = "App.app" BlueprintName = "App" ReferencedContainer = "container:App.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES" shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{target_id}" BuildableName = "App.app" BlueprintName = "App" ReferencedContainer = "container:App.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{target_id}" BuildableName = "App.app" BlueprintName = "App" ReferencedContainer = "container:App.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (SCHEME_DIR / "App.xcscheme").write_text(scheme)
    print("wrote project.pbxproj and App.xcscheme")

if __name__ == "__main__":
    main()
