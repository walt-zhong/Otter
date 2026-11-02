#!/usr/bin/env python3
"""Generate OTIOS/OtterDemo.xcodeproj. Run from OTIOS."""
import hashlib
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "OtterDemo.xcodeproj")


def uid(text):
    return hashlib.md5(text.encode()).hexdigest()[:24].upper()


def files(folder, suffixes):
    found = []
    for dirpath, _, names in os.walk(os.path.join(ROOT, folder)):
        for name in sorted(names):
            if name.endswith(suffixes):
                found.append(os.path.relpath(os.path.join(dirpath, name), ROOT))
    return found


core = [p for p in files("Sources/OtterCore", (".swift",)) if "/Tests/" not in p]
layout = files("Sources/OtterLayout", (".swift",))
expression_swift = files("Sources/OtterExpression", (".swift",))
ui = files("Sources/OtterUI", (".swift",))
demo = files("Demo", (".swift",))
stretch_swift = files("ThirdParty/StretchKit/Classes", (".swift",))
cpp = [
    "ThirdParty/OtterAnalyzeBridge/OTExpressionBridge.mm",
    "../../OTAndroid/src/main/cpp/OTAnalyze.cpp",
    "../../OTAndroid/src/main/cpp/OTATSNode.cpp",
    "../../OTAndroid/src/main/cpp/OTWordAnalyze.cpp",
]
# Paths in the pbxproj are relative to the project directory (OTIOS).
cpp = [
    "ThirdParty/OtterAnalyzeBridge/OTExpressionBridge.mm",
    "../OTAndroid/src/main/cpp/OTAnalyze.cpp",
    "../OTAndroid/src/main/cpp/OTATSNode.cpp",
    "../OTAndroid/src/main/cpp/OTWordAnalyze.cpp",
]

objects = {}


def add(obj_id, isa, **fields):
    objects[obj_id] = (isa, fields)
    return obj_id


def file_ref(path, kind):
    ref = uid("ref:" + path)
    add(ref, "PBXFileReference", lastKnownFileType=kind, path=path, sourceTree="SOURCE_ROOT")
    return ref


def source_file(path, kind, target_phase):
    ref = file_ref(path, kind)
    build = uid("build:" + target_phase + ":" + path)
    add(build, "PBXBuildFile", fileRef=ref)
    return build


def emit_dict(fields, indent):
    lines = ["{"]
    for key, value in fields.items():
        pad = "\t" * indent
        if isinstance(value, list):
            lines.append(f"{pad}{key} = (")
            for item in value:
                if isinstance(item, tuple):
                    lines.append(f"{pad}\t{item[0]} /* {item[1]} */,")
                else:
                    lines.append(f"{pad}\t{item},")
            lines.append(f"{pad});")
        elif isinstance(value, dict):
            body = emit_dict(value, indent + 1)
            lines.append(f"{pad}{key} = {body};")
        else:
            lines.append(f"{pad}{key} = {value};")
    lines.append("\t" * (indent - 1) + "}")
    return "\n".join(lines)


kinds = {
    ".swift": "sourcecode.swift",
    ".mm": "sourcecode.cpp.objcpp",
    ".cpp": "sourcecode.cpp.cpp",
    ".h": "sourcecode.c.h",
    ".a": "archive.ar",
    ".plist": "text.plist.xml",
}


def kind_for(path):
    for suffix, kind in kinds.items():
        if path.endswith(suffix):
            return kind
    return "text"


phases = {}
products = {}
targets = []


def make_target(name, sources, extra_libs, deps, app=False, bridging=None, headers=None, module=None):
    phase_id = uid("phase:" + name)
    builds = []
    for path in sources:
        builds.append(source_file(path, kind_for(path), name))
    add(phase_id, "PBXSourcesBuildPhase", buildActionMask="2147483647", files=builds, runOnlyForDeploymentPostprocessing="0")
    framework_id = uid("fw:" + name)
    fw_builds = []
    for lib in extra_libs:
        ref = lib if lib.startswith("ID:") else None
        if lib.startswith("ID:"):
            fw_builds.append(uid("link:" + name + ":" + lib))
            add(fw_builds[-1], "PBXBuildFile", fileRef=lib[3:])
        else:
            ref = file_ref(lib, kind_for(lib))
            fw_builds.append(uid("link:" + name + ":" + lib))
            add(fw_builds[-1], "PBXBuildFile", fileRef=ref)
    add(framework_id, "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=fw_builds, runOnlyForDeploymentPostprocessing="0")
    product_type = "com.apple.product-type.application" if app else "com.apple.product-type.library.static"
    product_name = name + (".app" if app else ".a")
    product_ref = uid("product:" + name)
    add(
        product_ref,
        "PBXFileReference",
        explicitFileType="wrapper.application" if app else "archive.ar",
        includeInIndex="0",
        path=product_name,
        sourceTree="BUILT_PRODUCTS_DIR",
    )
    config_list = uid("cfglist:" + name)
    target_id = uid("target:" + name)
    dep_ids = []
    for dep in deps:
        dep_id = uid("dep:" + name + ":" + dep)
        add(dep_id, "PBXTargetDependency", target=uid("target:" + dep))
        dep_ids.append(dep_id)
    resource_id = None
    phase_ids = [phase_id, framework_id]
    if app:
        resource_id = uid("res:" + name)
        asset_ref = file_ref("../Demo/src/main/assets", "folder")
        res_ref = file_ref("../Demo/src/main/res", "folder")
        # folder references
        objects[asset_ref] = (
            "PBXFileReference",
            dict(lastKnownFileType="folder", path="../Demo/src/main/assets", sourceTree="SOURCE_ROOT"),
        )
        objects[res_ref] = (
            "PBXFileReference",
            dict(lastKnownFileType="folder", name="android-res", path="../Demo/src/main/res", sourceTree="SOURCE_ROOT"),
        )
        asset_build = uid("resbuild:assets")
        res_build = uid("resbuild:res")
        add(asset_build, "PBXBuildFile", fileRef=asset_ref)
        add(res_build, "PBXBuildFile", fileRef=res_ref)
        add(resource_id, "PBXResourcesBuildPhase", buildActionMask="2147483647", files=[asset_build, res_build], runOnlyForDeploymentPostprocessing="0")
        phase_ids = [phase_id, framework_id, resource_id]
    add(
        target_id,
        "PBXNativeTarget",
        buildConfigurationList=config_list,
        buildPhases=phase_ids,
        buildRules=[],
        dependencies=dep_ids,
        name=name,
        productName=name,
        productReference=product_ref,
        productType=product_type,
    )
    settings = {
        "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
        "SDKROOT": "iphoneos",
        "TARGETED_DEVICE_FAMILY": '"1,2"',
        "SWIFT_VERSION": "5.0",
        "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++17"',
        "CLANG_ENABLE_MODULES": "YES",
        "ENABLE_BITCODE": "NO",
        "DEFINES_MODULE": "YES",
        "PRODUCT_MODULE_NAME": module or name,
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SKIP_INSTALL": "YES" if not app else "NO",
        "MACH_O_TYPE": "staticlib" if not app else "mh_execute",
        "CODE_SIGN_STYLE": "Automatic",
        "CODE_SIGNING_ALLOWED": "NO",
        "GENERATE_INFOPLIST_FILE": "NO" if app else "YES",
        "ONLY_ACTIVE_ARCH": "YES",
    }
    if headers:
        settings["HEADER_SEARCH_PATHS"] = headers
    if bridging:
        settings["SWIFT_OBJC_BRIDGING_HEADER"] = bridging
    if not app:
        settings["PRODUCT_BUNDLE_IDENTIFIER"] = f"com.otter.{name}"
    else:
        settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.otter.demo"
        settings["INFOPLIST_FILE"] = "Demo/Info.plist"
        settings["LD_RUNPATH_SEARCH_PATHS"] = '"$(inherited) @executable_path/Frameworks"'
        settings["OTHER_LDFLAGS"] = '"$(inherited) -lc++"'
    debug = dict(settings)
    debug["DEBUG_INFORMATION_FORMAT"] = "dwarf"
    debug["SWIFT_OPTIMIZATION_LEVEL"] = '"-Onone"'
    debug["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
    release = dict(settings)
    release["DEBUG_INFORMATION_FORMAT"] = '"dwarf-with-dsym"'
    release["SWIFT_OPTIMIZATION_LEVEL"] = '"-O"'
    debug_id = uid("cfg:debug:" + name)
    release_id = uid("cfg:release:" + name)
    add(debug_id, "XCBuildConfiguration", name="Debug", buildSettings=debug)
    add(release_id, "XCBuildConfiguration", name="Release", buildSettings=release)
    add(config_list, "XCConfigurationList", buildConfigurations=[debug_id, release_id], defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
    products[name] = product_ref
    targets.append(target_id)
    return product_ref


core_product = make_target("OtterCore", core, [], [])
stretch_product = make_target(
    "StretchKit",
    stretch_swift,
    ["ThirdParty/StretchKit/Libraries/libstretch.a"],
    [],
    bridging="ThirdParty/StretchKit/StretchBridge.h",
    headers='("$(SRCROOT)/ThirdParty/StretchKit/Headers")',
)
expression_product = make_target(
    "OtterExpression",
    expression_swift + cpp,
    [],
    ["OtterCore"],
    bridging="Sources/OtterExpression/ExpressionBridge.h",
    headers='("$(SRCROOT)/ThirdParty/OtterAnalyzeBridge/include" "$(SRCROOT)/../OTAndroid/src/main/cpp")',
)
layout_product = make_target("OtterLayout", layout, [], ["OtterCore", "StretchKit"])
# Link the static products.
demo_libs = ["ID:" + products[name] for name in ["OtterCore", "StretchKit", "OtterExpression", "OtterLayout"]]
demo_libs.append("ThirdParty/StretchKit/Libraries/libstretch.a")
make_target(
    "OtterDemo",
    ui + demo,
    demo_libs,
    ["OtterCore", "StretchKit", "OtterExpression", "OtterLayout"],
    app=True,
)

project_configs = uid("projcfg")
proj_debug = uid("projdebug")
proj_release = uid("projrelease")
add(proj_debug, "XCBuildConfiguration", name="Debug", buildSettings={
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++17"',
    "CLANG_ENABLE_MODULES": "YES",
    "SDKROOT": "iphoneos",
    "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
    "SWIFT_VERSION": "5.0",
    "CODE_SIGNING_ALLOWED": "NO",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
})
add(proj_release, "XCBuildConfiguration", name="Release", buildSettings={
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++17"',
    "CLANG_ENABLE_MODULES": "YES",
    "SDKROOT": "iphoneos",
    "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
    "SWIFT_VERSION": "5.0",
    "CODE_SIGNING_ALLOWED": "NO",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
})
add(project_configs, "XCConfigurationList", buildConfigurations=[proj_debug, proj_release], defaultConfigurationIsVisible="0", defaultConfigurationName="Release")

project_id = uid("project")
main_group = uid("maingroup")
product_group = uid("productgroup")
add(product_group, "PBXGroup", children=list(products.values()), name="Products", sourceTree="<group>")
add(main_group, "PBXGroup", children=[product_group], sourceTree="<group>")
add(
    project_id,
    "PBXProject",
    attributes={"LastUpgradeCheck": "1600", "ORGANIZATIONNAME": "Otter"},
    buildConfigurationList=project_configs,
    compatibilityVersion='"Xcode 14.0"',
    developmentRegion="en",
    hasScannedForEncodings="0",
    knownRegions=["en", "Base"],
    mainGroup=main_group,
    productRefGroup=product_group,
    projectDirPath='""',
    projectRoot='""',
    targets=targets,
)

# Scheme
scheme_dir = os.path.join(OUT, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
target_demo = uid("target:OtterDemo")
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_demo}" BuildableName="OtterDemo.app" BlueprintName="OtterDemo" ReferencedContainer="container:OtterDemo.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_demo}" BuildableName="OtterDemo.app" BlueprintName="OtterDemo" ReferencedContainer="container:OtterDemo.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
</Scheme>
"""
with open(os.path.join(scheme_dir, "OtterDemo.xcscheme"), "w") as handle:
    handle.write(scheme)

def q(value):
    if isinstance(value, str) and (value.startswith('"') or value.startswith("(") or value in ("YES", "NO", "SOURCE_ROOT", "<group>") or value.replace(".", "", 1).isdigit()):
        return value
    if isinstance(value, str) and value[:1].isalnum() and " " not in value and "/" not in value and ":" not in value and "$" not in value:
        return value
    return '"' + str(value).replace('"', "") + '"' if not str(value).startswith('"') else value


lines = [
    "// !$*UTF8*$!",
    "{",
    "\tarchiveVersion = 1;",
    "\tclasses = {};",
    "\tobjectVersion = 56;",
    "\tobjects = {",
]
for obj_id, (isa, fields) in objects.items():
    lines.append(f"\t\t{obj_id} = {{")
    lines.append(f"\t\t\tisa = {isa};")
    for key, value in fields.items():
        if isinstance(value, list):
            lines.append(f"\t\t\t{key} = (")
            for item in value:
                token = item if isinstance(item, str) else item
                lines.append(f"\t\t\t\t{token},")
            lines.append("\t\t\t);")
        elif isinstance(value, dict):
            lines.append(f"\t\t\t{key} = {{")
            for inner, inner_value in value.items():
                rendered = inner_value if isinstance(inner_value, str) and (inner_value.startswith('"') or inner_value.startswith("(") or inner_value in ("YES", "NO")) else f'"{inner_value}"' if not str(inner_value).replace(".", "", 1).isdigit() else inner_value
                if key == "buildSettings":
                    rendered = inner_value
                lines.append(f"\t\t\t\t{inner} = {rendered};")
            lines.append("\t\t\t};")
        else:
            rendered = value
            if isinstance(value, str) and not (value.startswith('"') or value.startswith("(") or value in ("YES", "NO", "SOURCE_ROOT", "<group>") or value[:1].isdigit()):
                if " " in value or "/" in value or "$" in value:
                    rendered = f'"{value}"'
            lines.append(f"\t\t\t{key} = {rendered};")
    lines.append("\t\t};")
lines += [
    "\t};",
    "\trootObject = " + project_id + ";",
    "}",
    "",
]
os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "project.pbxproj"), "w") as handle:
    handle.write("\n".join(lines))
print("wrote", OUT, "targets", len(targets), "objects", len(objects))
