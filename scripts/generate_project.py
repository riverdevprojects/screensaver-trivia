"""Generate the checked-in Xcode project using only Python's standard library."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "ScreensaverTrivia.xcodeproj"


def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    objects = []

    def obj(key, isa, fields):
        objects.append(f"\t\t{ident(key)} = {{\n\t\t\tisa = {isa};\n" + "".join(f"\t\t\t{k} = {v};\n" for k, v in fields.items()) + "\t\t};")
        return ident(key)

    def array(values):
        return "(\n" + "".join(f"\t\t\t\t{value},\n" for value in values) + "\t\t\t)"

    def file(key, path, kind, group="<group>"):
        return obj(key, "PBXFileReference", {"lastKnownFileType": kind, "name": quote(Path(path).name), "path": quote(path), "sourceTree": quote(group)})

    def build(key, ref):
        return obj(key, "PBXBuildFile", {"fileRef": ref})

    groups = {}
    builds = {}
    for group_name, folder in [("app", "ScreensaverTrivia"), ("tests", "ScreensaverTriviaTests"), ("uitests", "ScreensaverTriviaUITests")]:
        refs, source_builds = [], []
        for path in sorted((ROOT / folder).rglob("*.swift")):
            relative = path.relative_to(ROOT / folder).as_posix()
            key = f"file:{folder}/{relative}"
            ref = file(key, relative, "sourcecode.swift")
            refs.append(ref)
            source_builds.append(build("build:" + key, ref))
        resource_builds = []
        if group_name == "app":
            for path, kind in [("Resources/Assets.xcassets", "folder.assetcatalog"), ("Resources/Media", "folder"),
                               ("Resources/locations.json", "text.json"), ("Resources/PrivacyInfo.xcprivacy", "text.xml")]:
                ref = file("file:" + path, path, kind)
                refs.append(ref)
                resource_builds.append(build("build:" + path, ref))
            refs.append(file("file:Info", "Resources/Info.plist", "text.plist.xml"))
        groups[group_name] = obj("group:" + group_name, "PBXGroup", {"children": array(refs), "path": quote(folder), "sourceTree": quote("<group>")})
        sources = obj("sources:" + group_name, "PBXSourcesBuildPhase", {"buildActionMask": "2147483647", "files": array(source_builds), "runOnlyForDeploymentPostprocessing": "0"})
        frameworks = obj("frameworks:" + group_name, "PBXFrameworksBuildPhase", {"buildActionMask": "2147483647", "files": "()", "runOnlyForDeploymentPostprocessing": "0"})
        resources = obj("resources:" + group_name, "PBXResourcesBuildPhase", {"buildActionMask": "2147483647", "files": array(resource_builds), "runOnlyForDeploymentPostprocessing": "0"})
        builds[group_name] = [sources, frameworks, resources]

    products = []
    for name, ext, kind in [("app", "app", "wrapper.application"), ("tests", "xctest", "wrapper.cfbundle"), ("uitests", "xctest", "wrapper.cfbundle")]:
        title = {"app": "ScreensaverTrivia", "tests": "ScreensaverTriviaTests", "uitests": "ScreensaverTriviaUITests"}[name]
        products.append(obj("product:" + name, "PBXFileReference", {"explicitFileType": kind, "includeInIndex": "0", "path": quote(title + "." + ext), "sourceTree": "BUILT_PRODUCTS_DIR"}))
    products_group = obj("group:products", "PBXGroup", {"children": array(products), "name": "Products", "sourceTree": quote("<group>")})
    main_group = obj("group:main", "PBXGroup", {"children": array([*groups.values(), products_group]), "sourceTree": quote("<group>")})

    def config_list(key, settings):
        configs = []
        for mode in ["Debug", "Release"]:
            values = dict(settings)
            if key == "project":
                values.update({"SWIFT_OPTIMIZATION_LEVEL": quote("-Onone" if mode == "Debug" else "-O"),
                               "DEBUG_INFORMATION_FORMAT": quote("dwarf" if mode == "Debug" else "dwarf-with-dsym")})
                if mode == "Debug":
                    values.update({"ENABLE_TESTABILITY": "YES", "GCC_PREPROCESSOR_DEFINITIONS": array([quote("DEBUG=1"), quote("$(inherited)")]), "SWIFT_ACTIVE_COMPILATION_CONDITIONS": quote("DEBUG $(inherited)"), "ONLY_ACTIVE_ARCH": "YES"})
                else:
                    values.update({"SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES"})
            settings_text = "{\n" + "".join(f"\t\t\t\t{k} = {v};\n" for k, v in sorted(values.items())) + "\t\t\t}"
            configs.append(obj("config:" + key + ":" + mode, "XCBuildConfiguration", {"buildSettings": settings_text, "name": mode}))
        return obj("configs:" + key, "XCConfigurationList", {"buildConfigurations": array(configs), "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"})

    project_configs = config_list("project", {
        "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES", "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "IPHONEOS_DEPLOYMENT_TARGET": "16.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0", "SWIFT_STRICT_CONCURRENCY": "targeted",
    })
    targets = []
    for name in ["app", "tests", "uitests"]:
        title = {"app": "ScreensaverTrivia", "tests": "ScreensaverTriviaTests", "uitests": "ScreensaverTriviaUITests"}[name]
        settings = {"PRODUCT_NAME": quote("$(TARGET_NAME)"), "TARGETED_DEVICE_FAMILY": "1",
            "CODE_SIGN_STYLE": "Automatic", "SUPPORTED_PLATFORMS": quote("iphoneos iphonesimulator"),
            "PRODUCT_BUNDLE_IDENTIFIER": quote("com.riverdevprojects.screensavertrivia" + {"app": "", "tests": ".tests", "uitests": ".uitests"}[name]),
            "GENERATE_INFOPLIST_FILE": "YES"}
        if name == "app":
            settings.update({"GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": quote("ScreensaverTrivia/Resources/Info.plist"),
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1", "SUPPORTS_MACCATALYST": "NO",
                "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO", "SWIFT_EMIT_LOC_STRINGS": "YES"})
        elif name == "tests":
            settings.update({"BUNDLE_LOADER": quote("$(TEST_HOST)"), "TEST_HOST": quote("$(BUILT_PRODUCTS_DIR)/ScreensaverTrivia.app/ScreensaverTrivia")})
        else:
            settings.update({"TEST_TARGET_NAME": "ScreensaverTrivia"})
        configs = config_list(name, settings)
        dependencies = []
        if name != "app":
            proxy = obj("proxy:" + name, "PBXContainerItemProxy", {"containerPortal": ident("project"), "proxyType": "1", "remoteGlobalIDString": ident("target:app"), "remoteInfo": "ScreensaverTrivia"})
            dependencies.append(obj("dependency:" + name, "PBXTargetDependency", {"target": ident("target:app"), "targetProxy": proxy}))
        targets.append(obj("target:" + name, "PBXNativeTarget", {"buildConfigurationList": configs,
            "buildPhases": array(builds[name]), "buildRules": "()", "dependencies": array(dependencies), "name": title,
            "productName": title, "productReference": ident("product:" + name),
            "productType": quote({"app": "com.apple.product-type.application", "tests": "com.apple.product-type.bundle.unit-test", "uitests": "com.apple.product-type.bundle.ui-testing"}[name])}))
    obj("project", "PBXProject", {"attributes": "{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }",
        "buildConfigurationList": project_configs, "compatibilityVersion": quote("Xcode 14.0"), "developmentRegion": "en",
        "hasScannedForEncodings": "0", "knownRegions": array(["en", "Base"]), "mainGroup": main_group,
        "productRefGroup": products_group, "projectDirPath": quote(""), "projectRoot": quote(""), "targets": array(targets)})
    PROJECT.mkdir(exist_ok=True)
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {ident('project')};\n}}\n", encoding="utf-8")

    def reference(name):
        title = {"app": "ScreensaverTrivia", "tests": "ScreensaverTriviaTests", "uitests": "ScreensaverTriviaUITests"}[name]
        ext = "app" if name == "app" else "xctest"
        return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:" + name)}" BuildableName="{title}.{ext}" BlueprintName="{title}" ReferencedContainer="container:ScreensaverTrivia.xcodeproj"/>'

    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference("app")}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO" parallelizable="NO">{reference("tests")}</TestableReference><TestableReference skipped="NO" parallelizable="NO">{reference("uitests")}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("app")}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference("app")}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    schemes = PROJECT / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    (schemes / "ScreensaverTrivia.xcscheme").write_text(scheme, encoding="utf-8")
    print("Generated ScreensaverTrivia.xcodeproj with app, unit-test and UI-test targets.")


if __name__ == "__main__":
    main()
