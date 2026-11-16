#!/usr/bin/env python3
"""生成 iOS/LumaReaderIOS.xcodeproj/project.pbxproj。

显式列出源文件与资源，避免依赖 Xcode 的自动分组，保证命令行编译与 Xcode 打开一致。
新增 Swift 文件后重跑本脚本即可。
"""
import hashlib
import os
import sys

ROOT = "/Users/sun/Downloads/LumaReader-2/iOS"
APP_DIR = "LumaReaderIOS"
PROJECT = "LumaReaderIOS.xcodeproj"
TARGET_NAME = "LumaReader"
UITEST_DIR = "LumaReaderIOSUITests"
UITEST_TARGET = "LumaReaderUITests"
UITEST_FILES = ["LumaReaderSmokeTests.swift"]

SWIFT_FILES = [
    "App/LumaReaderIOSApp.swift",
    "App/Theme.swift",
    "Core/Models.swift",
    "Core/LumaCoreBridge.swift",
    "Core/StudyStore.swift",
    "Core/DictationEngine.swift",
    "Core/SpeechService.swift",
    "Core/CloudSyncService.swift",
    "Features/Dictation/DictationHomeView.swift",
    "Features/Vocabulary/VocabularyHomeView.swift",
    "Features/Settings/SettingsView.swift",
    "Features/Reader/MiniZip.swift",
    "Features/Reader/BookLibrary.swift",
    "Features/Reader/ReaderViews.swift",
]

RESOURCE_FILES = [
    "Resources/Reader.css",
    "Resources/Reader.js",
    "Resources/ReadingVocabulary.json",
    "Resources/sample.epub",
]


def oid(key: str) -> str:
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def main() -> int:
    missing = [f for f in SWIFT_FILES + RESOURCE_FILES if not os.path.exists(os.path.join(ROOT, APP_DIR, f))]
    missing += [f for f in UITEST_FILES if not os.path.exists(os.path.join(ROOT, UITEST_DIR, f))]
    if missing:
        print("缺少文件：\n  " + "\n  ".join(missing))
        return 1

    project_id = oid("project")
    target_id = oid("target")
    product_id = oid("product")
    main_group = oid("group:main")
    app_group = oid("group:app")
    products_group = oid("group:products")
    sources_phase = oid("phase:sources")
    frameworks_phase = oid("phase:frameworks")
    resources_phase = oid("phase:resources")
    project_config_list = oid("configlist:project")
    target_config_list = oid("configlist:target")
    project_debug = oid("config:project:debug")
    project_release = oid("config:project:release")
    target_debug = oid("config:target:debug")
    target_release = oid("config:target:release")
    test_target_id = oid("target:uitest")
    test_product_id = oid("product:uitest")
    test_group = oid("group:uitest")
    test_sources_phase = oid("phase:uitest:sources")
    test_frameworks_phase = oid("phase:uitest:frameworks")
    test_resources_phase = oid("phase:uitest:resources")
    test_config_list = oid("configlist:uitest")
    test_debug = oid("config:uitest:debug")
    test_release = oid("config:uitest:release")
    test_dependency_id = oid("dependency:uitest")
    test_proxy_id = oid("proxy:uitest")
    core_pkg_ref = oid("pkg:lumacore")
    core_product = oid("pkgproduct:lumacore")
    core_build_file = oid("build:lumacore")

    lines = []
    add = lines.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")

    # PBXBuildFile
    add("\n/* Begin PBXBuildFile section */")
    for path in SWIFT_FILES:
        add(f"\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Sources */ = {{isa = PBXBuildFile; fileRef = {oid('file:' + path)} /* {os.path.basename(path)} */; }};")
    for path in RESOURCE_FILES:
        add(f"\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Resources */ = {{isa = PBXBuildFile; fileRef = {oid('file:' + path)} /* {os.path.basename(path)} */; }};")
    for path in UITEST_FILES:
        add(f"\t\t{oid('build:uitest:' + path)} /* {os.path.basename(path)} in Sources */ = {{isa = PBXBuildFile; fileRef = {oid('file:uitest:' + path)} /* {os.path.basename(path)} */; }};")
    add("/* End PBXBuildFile section */")

    # PBXFileReference
    add("\n/* Begin PBXFileReference section */")
    add(f"\t\t{product_id} /* {TARGET_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {TARGET_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for path in SWIFT_FILES:
        add(f"\t\t{oid('file:' + path)} /* {os.path.basename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{os.path.basename(path)}\"; sourceTree = \"<group>\"; }};")
    for path in RESOURCE_FILES:
        ext = os.path.splitext(path)[1].lstrip(".")
        types = {"css": "text.css", "js": "sourcecode.javascript", "json": "text.json"}
        add(f"\t\t{oid('file:' + path)} /* {os.path.basename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = {types.get(ext, 'text')}; path = \"{os.path.basename(path)}\"; sourceTree = \"<group>\"; }};")
    add(f"\t\t{oid('file:Info.plist')} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    add(f"\t\t{test_product_id} /* {UITEST_TARGET}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {UITEST_TARGET}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for path in UITEST_FILES:
        add(f"\t\t{oid('file:uitest:' + path)} /* {os.path.basename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{os.path.basename(path)}\"; sourceTree = \"<group>\"; }};")
    add("/* End PBXFileReference section */")

    # Groups
    add("\n/* Begin PBXGroup section */")
    add(f"\t\t{main_group} = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{app_group} /* {APP_DIR} */,")
    add(f"\t\t\t\t{test_group} /* {UITEST_DIR} */,")
    add(f"\t\t\t\t{products_group} /* Products */,")
    add("\t\t\t);")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")

    def group(gid, name, children):
        add(f"\t\t{gid} /* {name} */ = {{")
        add("\t\t\tisa = PBXGroup;")
        add("\t\t\tchildren = (")
        for child in children:
            add(f"\t\t\t\t{child},")
        add("\t\t\t);")
        add(f"\t\t\tpath = \"{name}\";" if name != APP_DIR else f"\t\t\tpath = \"{name}\";")
        add("\t\t\tsourceTree = \"<group>\";")
        add("\t\t};")

    app_children = [
        oid("group:App"), oid("group:Core"), oid("group:Features"),
        oid("group:Resources"), oid("file:Info.plist"),
    ]
    group(app_group, APP_DIR, app_children)
    group(oid("group:App"), "App", [oid("file:" + p) for p in SWIFT_FILES if p.startswith("App/")])
    group(oid("group:Core"), "Core", [oid("file:" + p) for p in SWIFT_FILES if p.startswith("Core/")])
    group(oid("group:Features"), "Features", [
        oid("group:Features/Dictation"), oid("group:Features/Vocabulary"),
        oid("group:Features/Reader"), oid("group:Features/Settings"),
    ])
    for feature in ["Dictation", "Vocabulary", "Reader", "Settings"]:
        group(oid(f"group:Features/{feature}"), feature,
              [oid("file:" + p) for p in SWIFT_FILES if p.startswith(f"Features/{feature}/")])
    group(oid("group:Resources"), "Resources", [oid("file:" + p) for p in RESOURCE_FILES])

    group(test_group, UITEST_DIR, [oid("file:uitest:" + p) for p in UITEST_FILES])

    add(f"\t\t{products_group} /* Products */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{product_id} /* {TARGET_NAME}.app */,")
    add(f"\t\t\t\t{test_product_id} /* {UITEST_TARGET}.xctest */,")
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    add("/* End PBXGroup section */")

    # Native target
    add("\n/* Begin PBXNativeTarget section */")
    add(f"\t\t{target_id} /* {TARGET_NAME} */ = {{")
    add("\t\t\tisa = PBXNativeTarget;")
    add(f"\t\t\tbuildConfigurationList = {target_config_list} /* Build configuration list for PBXNativeTarget \"{TARGET_NAME}\" */;")
    add("\t\t\tbuildPhases = (")
    add(f"\t\t\t\t{sources_phase} /* Sources */,")
    add(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
    add(f"\t\t\t\t{resources_phase} /* Resources */,")
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add(f"\t\t\tpackageProductDependencies = (")
    add(f"\t\t\t\t{core_product} /* LumaCore */,")
    add(f"\t\t\t);")
    add(f"\t\t\tname = {TARGET_NAME};")
    add(f"\t\t\tproductName = {TARGET_NAME};")
    add(f"\t\t\tproductReference = {product_id} /* {TARGET_NAME}.app */;")
    add("\t\t\tproductType = \"com.apple.product-type.application\";")
    add("\t\t};")
    add(f"\t\t{test_target_id} /* {UITEST_TARGET} */ = {{")
    add("\t\t\tisa = PBXNativeTarget;")
    add(f"\t\t\tbuildConfigurationList = {test_config_list} /* Build configuration list for PBXNativeTarget \"{UITEST_TARGET}\" */;")
    add("\t\t\tbuildPhases = (")
    add(f"\t\t\t\t{test_sources_phase} /* Sources */,")
    add(f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,")
    add(f"\t\t\t\t{test_resources_phase} /* Resources */,")
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add(f"\t\t\t\t{test_dependency_id} /* PBXTargetDependency */,")
    add("\t\t\t);")
    add(f"\t\t\tname = {UITEST_TARGET};")
    add(f"\t\t\tproductName = {UITEST_TARGET};")
    add(f"\t\t\tproductReference = {test_product_id} /* {UITEST_TARGET}.xctest */;")
    add("\t\t\tproductType = \"com.apple.product-type.bundle.ui-testing\";")
    add("\t\t};")
    add("/* End PBXNativeTarget section */")

    add("\n/* Begin PBXTargetDependency section */")
    add(f"\t\t{test_dependency_id} /* PBXTargetDependency */ = {{")
    add("\t\t\tisa = PBXTargetDependency;")
    add(f"\t\t\ttarget = {target_id} /* {TARGET_NAME} */;")
    add(f"\t\t\ttargetProxy = {test_proxy_id} /* PBXContainerItemProxy */;")
    add("\t\t};")
    add("/* End PBXTargetDependency section */")

    add("\n/* Begin PBXContainerItemProxy section */")
    add(f"\t\t{test_proxy_id} /* PBXContainerItemProxy */ = {{")
    add("\t\t\tisa = PBXContainerItemProxy;")
    add(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    add("\t\t\tproxyType = 1;")
    add(f"\t\t\tremoteGlobalIDString = {target_id};")
    add(f"\t\t\tremoteInfo = {TARGET_NAME};")
    add("\t\t};")
    add("/* End PBXContainerItemProxy section */")

    # Project
    add("\n/* Begin PBXProject section */")
    add(f"\t\t{project_id} /* Project object */ = {{")
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    add("\t\t\t\tLastUpgradeCheck = 1600;")
    add("\t\t\t\tTargetAttributes = {")
    add(f"\t\t\t\t\t{target_id} = {{")
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    add("\t\t\t\t\t};")
    add(f"\t\t\t\t\t{test_target_id} = {{")
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    add(f"\t\t\t\t\t\tTestTargetID = {target_id};")
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"{TARGET_NAME}\" */;")
    add("\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
    add("\t\t\tdevelopmentRegion = \"zh-Hans\";")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\t\"zh-Hans\",")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f"\t\t\tmainGroup = {main_group};")
    add(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
    add("\t\t\tprojectDirPath = \"\";")
    add("\t\t\tprojectRoot = \"\";")
    add(f"\t\t\tpackageReferences = (\n\t\t\t\t{core_pkg_ref} /* XCLocalSwiftPackageReference \"../Packages/LumaCore\" */,\n\t\t\t);")
    add("\t\t\ttargets = (")
    add(f"\t\t\t\t{target_id} /* {TARGET_NAME} */,")
    add(f"\t\t\t\t{test_target_id} /* {UITEST_TARGET} */,")
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")

    # Phases
    add("\n/* Begin PBXResourcesBuildPhase section */")
    add(f"\t\t{resources_phase} /* Resources */ = {{")
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for path in RESOURCE_FILES:
        add(f"\t\t\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Resources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")

    add("\n/* Begin PBXSourcesBuildPhase section */")
    add(f"\t\t{sources_phase} /* Sources */ = {{")
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for path in SWIFT_FILES:
        add(f"\t\t\t\t{oid('build:' + path)} /* {os.path.basename(path)} in Sources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")

    add("\n/* Begin PBXFrameworksBuildPhase section */")
    add(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
    add("\t\t\tisa = PBXFrameworksBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add(f"\t\t\t\t{core_build_file} /* LumaCore in Frameworks */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")

    add("\n/* Begin PBXBuildFile section (LumaCore) */")
    add(f"\t\t{core_build_file} /* LumaCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {core_product} /* LumaCore */; }};")
    add("/* End PBXBuildFile section (LumaCore) */")

    add("\n/* Begin XCLocalSwiftPackageReference section */")
    add(f"\t\t{core_pkg_ref} /* XCLocalSwiftPackageReference \"../Packages/LumaCore\" */ = {{")
    add("\t\t\tisa = XCLocalSwiftPackageReference;")
    add('\t\t\trelativePath = "../Packages/LumaCore";')
    add("\t\t};")
    add("/* End XCLocalSwiftPackageReference section */")

    add("\n/* Begin XCSwiftPackageProductDependency section */")
    add(f"\t\t{core_product} /* LumaCore */ = {{")
    add("\t\t\tisa = XCSwiftPackageProductDependency;")
    add("\t\t\tproductName = LumaCore;")
    add("\t\t};")
    add("/* End XCSwiftPackageProductDependency section */")

    add("\n/* Begin PBXSourcesBuildPhase section (UI test) */")
    add(f"\t\t{test_sources_phase} /* Sources */ = {{")
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for path in UITEST_FILES:
        add(f"\t\t\t\t{oid('build:uitest:' + path)} /* {os.path.basename(path)} in Sources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXSourcesBuildPhase section (UI test) */")

    add("\n/* Begin PBXResourcesBuildPhase section (UI test) */")
    add(f"\t\t{test_resources_phase} /* Resources */ = {{")
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section (UI test) */")

    add("\n/* Begin PBXFrameworksBuildPhase section (UI test) */")
    add(f"\t\t{test_frameworks_phase} /* Frameworks */ = {{")
    add("\t\t\tisa = PBXFrameworksBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section (UI test) */")

    # Build configurations
    def config_block(cid, name, settings):
        add(f"\t\t{cid} /* {name} */ = {{")
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        for key in sorted(settings):
            add(f"\t\t\t\t{key} = {settings[key]};")
        add("\t\t\t};")
        add(f"\t\t\tname = {name};")
        add("\t\t};")

    common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
    }
    debug_settings = dict(common)
    debug_settings.update({
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "\"DEBUG $(inherited)\"",
        "SWIFT_OPTIMIZATION_LEVEL": "\"-Onone\"",
    })
    release_settings = dict(common)
    release_settings.update({
        "DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "\"-O\"",
        "VALIDATE_PRODUCT": "YES",
    })

    target_common = {
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "\"\"",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "5",
        "DEVELOPMENT_TEAM": "\"\"",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "\"LumaReaderIOS/Info.plist\"",
        "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t)",
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "app.luma.reader.ios",
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "SUPPORTED_PLATFORMS": "\"iphoneos iphonesimulator\"",
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "TARGETED_DEVICE_FAMILY": "1",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
    }

    test_common = dict(common)
    test_common.update({
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "5",
        "DEVELOPMENT_TEAM": "\"\"",
        "GENERATE_INFOPLIST_FILE": "YES",
        "LD_RUNPATH_SEARCH_PATHS": "(\n\t\t\t\t\t\"$(inherited)\",\n\t\t\t\t\t\"@executable_path/Frameworks\",\n\t\t\t\t\t\"@loader_path/Frameworks\",\n\t\t\t\t)",
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "app.luma.reader.ios.uitests",
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "SUPPORTED_PLATFORMS": "\"iphoneos iphonesimulator\"",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
        "TARGETED_DEVICE_FAMILY": "1",
        "TEST_TARGET_NAME": TARGET_NAME,
    })

    add("\n/* Begin XCBuildConfiguration section */")
    config_block(project_debug, "Debug", debug_settings)
    config_block(project_release, "Release", release_settings)
    config_block(target_debug, "Debug", target_common)
    config_block(target_release, "Release", target_common)
    config_block(test_debug, "Debug", test_common)
    config_block(test_release, "Release", test_common)
    add("/* End XCBuildConfiguration section */")

    add("\n/* Begin XCConfigurationList section */")
    for cid, label, debug_id, release_id in [
        (project_config_list, f"PBXProject \"{TARGET_NAME}\"", project_debug, project_release),
        (target_config_list, f"PBXNativeTarget \"{TARGET_NAME}\"", target_debug, target_release),
        (test_config_list, f"PBXNativeTarget \"{UITEST_TARGET}\"", test_debug, test_release),
    ]:
        add(f"\t\t{cid} /* Build configuration list for {label} */ = {{")
        add("\t\t\tisa = XCConfigurationList;")
        add("\t\t\tbuildConfigurations = (")
        add(f"\t\t\t\t{debug_id} /* Debug */,")
        add(f"\t\t\t\t{release_id} /* Release */,")
        add("\t\t\t);")
        add("\t\t\tdefaultConfigurationIsVisible = 0;")
        add("\t\t\tdefaultConfigurationName = Release;")
        add("\t\t};")
    add("/* End XCConfigurationList section */")

    add("\t};")
    add(f"\trootObject = {project_id} /* Project object */;")
    add("}")

    target_dir = os.path.join(ROOT, PROJECT)
    os.makedirs(target_dir, exist_ok=True)
    with open(os.path.join(target_dir, "project.pbxproj"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"已写入 {target_dir}/project.pbxproj（{len(SWIFT_FILES)} 个 Swift 文件，{len(RESOURCE_FILES)} 个资源）")

    # 共享 scheme：否则别人拿到工程要等 Xcode 自动生成，命令行 `-scheme` 也不稳。
    scheme_dir = os.path.join(target_dir, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{TARGET_NAME}.app"
               BlueprintName = "{TARGET_NAME}"
               ReferencedContainer = "container:{PROJECT}">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "NO" buildForProfiling = "NO" buildForArchiving = "NO" buildForAnalyzing = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target_id}"
               BuildableName = "{UITEST_TARGET}.xctest"
               BlueprintName = "{UITEST_TARGET}"
               ReferencedContainer = "container:{PROJECT}">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target_id}"
               BuildableName = "{UITEST_TARGET}.xctest"
               BlueprintName = "{UITEST_TARGET}"
               ReferencedContainer = "container:{PROJECT}">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{TARGET_NAME}.app"
            BlueprintName = "{TARGET_NAME}"
            ReferencedContainer = "container:{PROJECT}">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{TARGET_NAME}.app"
            BlueprintName = "{TARGET_NAME}"
            ReferencedContainer = "container:{PROJECT}">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
'''
    with open(os.path.join(scheme_dir, f"{TARGET_NAME}.xcscheme"), "w", encoding="utf-8") as handle:
        handle.write(scheme)
    print(f"已写入 {scheme_dir}/{TARGET_NAME}.xcscheme")
    return 0


if __name__ == "__main__":
    sys.exit(main())
