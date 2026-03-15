import os

# Static UUIDs (Xcode uses 24-char uppercase hex)
IDs = {
    'proj': 'AA000001000000000000001',
    'main_group': 'AA000001000000000000002',
    'app_group': 'AA000001000000000000003',
    'ds_group': 'AA000001000000000000004',
    'models_group': 'AA000001000000000000005',
    'comp_group': 'AA000001000000000000006',
    'views_group': 'AA000001000000000000007',
    'views_home': 'AA000001000000000000008',
    'views_active': 'AA000001000000000000009',
    'views_sessions': 'AA000001000000000000010',
    'views_settings': 'AA000001000000000000011',
    'views_auth': 'AA000001000000000000012',
    'views_prompts': 'AA000001000000000000013',
    'products_group': 'AA000001000000000000014',
    'target': 'AA000001000000000000015',
    'build_config_list_proj': 'AA000001000000000000016',
    'build_config_list_target': 'AA000001000000000000017',
    'debug_proj': 'AA000001000000000000018',
    'release_proj': 'AA000001000000000000019',
    'debug_target': 'AA000001000000000000020',
    'release_target': 'AA000001000000000000021',
    'sources_phase': 'AA000001000000000000022',
    'product_ref': 'AA000001000000000000023',
}

files = [
    ('HealthBeeApp.swift', 'App', 'AA100000000000000000001', 'AA200000000000000000001'),
    ('ContentView.swift', 'App', 'AA100000000000000000002', 'AA200000000000000000002'),
    ('AppTheme.swift', 'DesignSystem', 'AA100000000000000000003', 'AA200000000000000000003'),
    ('ThemeEnvironment.swift', 'DesignSystem', 'AA100000000000000000004', 'AA200000000000000000004'),
    ('TypographyModifiers.swift', 'DesignSystem', 'AA100000000000000000005', 'AA200000000000000000005'),
    ('AppModels.swift', 'Models', 'AA100000000000000000006', 'AA200000000000000000006'),
    ('AppState.swift', 'Models', 'AA100000000000000000007', 'AA200000000000000000007'),
    ('PersonaChip.swift', 'Components', 'AA100000000000000000008', 'AA200000000000000000008'),
    ('UplinkChip.swift', 'Components', 'AA100000000000000000009', 'AA200000000000000000009'),
    ('DashboardCardRow.swift', 'Components', 'AA100000000000000000010', 'AA200000000000000000010'),
    ('InsightRow.swift', 'Components', 'AA100000000000000000011', 'AA200000000000000000011'),
    ('SessionRow.swift', 'Components', 'AA100000000000000000012', 'AA200000000000000000012'),
    ('LogMessageView.swift', 'Components', 'AA100000000000000000013', 'AA200000000000000000013'),
    ('TypewriterText.swift', 'Components', 'AA100000000000000000014', 'AA200000000000000000014'),
    ('LiveTranscriptText.swift', 'Components', 'AA100000000000000000015', 'AA200000000000000000015'),
    ('ModeSegmentedControl.swift', 'Components', 'AA100000000000000000016', 'AA200000000000000000016'),
    ('OrbView.swift', 'Views/Home', 'AA100000000000000000017', 'AA200000000000000000017'),
    ('HomeView.swift', 'Views/Home', 'AA100000000000000000018', 'AA200000000000000000018'),
    ('ActiveSessionRadarVisualizer.swift', 'Views/ActiveSession', 'AA100000000000000000019', 'AA200000000000000000019'),
    ('ActiveSessionView.swift', 'Views/ActiveSession', 'AA100000000000000000020', 'AA200000000000000000020'),
    ('SessionsListView.swift', 'Views/Sessions', 'AA100000000000000000021', 'AA200000000000000000021'),
    ('ChatHistoryView.swift', 'Views/Sessions', 'AA100000000000000000022', 'AA200000000000000000022'),
    ('SettingsView.swift', 'Views/Settings', 'AA100000000000000000023', 'AA200000000000000000023'),
    ('PhoneAuthView.swift', 'Views/Auth', 'AA100000000000000000024', 'AA200000000000000000024'),
    ('PromptsListView.swift', 'Views/Prompts', 'AA100000000000000000025', 'AA200000000000000000025'),
]

group_key = {
    'App': 'app_group',
    'DesignSystem': 'ds_group',
    'Models': 'models_group',
    'Components': 'comp_group',
    'Views/Home': 'views_home',
    'Views/ActiveSession': 'views_active',
    'Views/Sessions': 'views_sessions',
    'Views/Settings': 'views_settings',
    'Views/Auth': 'views_auth',
    'Views/Prompts': 'views_prompts',
}

folder_path = {
    'App': 'HealthBee/App',
    'DesignSystem': 'HealthBee/DesignSystem',
    'Models': 'HealthBee/Models',
    'Components': 'HealthBee/Components',
    'Views/Home': 'HealthBee/Views/Home',
    'Views/ActiveSession': 'HealthBee/Views/ActiveSession',
    'Views/Sessions': 'HealthBee/Views/Sessions',
    'Views/Settings': 'HealthBee/Views/Settings',
    'Views/Auth': 'HealthBee/Views/Auth',
    'Views/Prompts': 'HealthBee/Views/Prompts',
}

# Collect groups for children
group_children = {}
for name, folder, fref, bfile in files:
    gk = group_key[folder]
    group_children.setdefault(gk, []).append(fref)

# Build PBXBuildFile section
build_file_section = ""
for name, folder, fref, bfid in files:
    build_file_section += f"\t\t{bfid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};\n"

# Build PBXFileReference section
file_ref_section = ""
for name, folder, fref, bfid in files:
    file_ref_section += f"\t\t{fref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {name}; path = {folder_path[folder]}/{name}; sourceTree = \"<group>\"; }};\n"
# Product
file_ref_section += f"\t\t{IDs['product_ref']} /* HealthBee.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = HealthBee.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n"

# Source files build phase children
sources_children = "\n".join([f"\t\t\t\t{bfid} /* {name} in Sources */," for name, folder, fref, bfid in files])

# Group children strings
def group_children_str(gk):
    children = group_children.get(gk, [])
    return "\n".join([f"\t\t\t\t{c}," for c in children])

pbxproj = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_file_section}/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_ref_section}/* End PBXFileReference section */

/* Begin PBXGroup section */
\t\t{IDs['main_group']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{IDs['app_group']} /* App */,
\t\t\t\t{IDs['ds_group']} /* DesignSystem */,
\t\t\t\t{IDs['models_group']} /* Models */,
\t\t\t\t{IDs['comp_group']} /* Components */,
\t\t\t\t{IDs['views_group']} /* Views */,
\t\t\t\t{IDs['products_group']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['products_group']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{IDs['product_ref']} /* HealthBee.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['app_group']} /* App */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('app_group')}
\t\t\t);
\t\t\tname = App;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['ds_group']} /* DesignSystem */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('ds_group')}
\t\t\t);
\t\t\tname = DesignSystem;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['models_group']} /* Models */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('models_group')}
\t\t\t);
\t\t\tname = Models;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['comp_group']} /* Components */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('comp_group')}
\t\t\t);
\t\t\tname = Components;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_group']} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{IDs['views_home']} /* Home */,
\t\t\t\t{IDs['views_active']} /* ActiveSession */,
\t\t\t\t{IDs['views_sessions']} /* Sessions */,
\t\t\t\t{IDs['views_settings']} /* Settings */,
\t\t\t\t{IDs['views_auth']} /* Auth */,
\t\t\t\t{IDs['views_prompts']} /* Prompts */,
\t\t\t);
\t\t\tname = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_home']} /* Home */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('views_home')}
\t\t\t);
\t\t\tname = Home;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_active']} /* ActiveSession */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('views_active')}
\t\t\t);
\t\t\tname = ActiveSession;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_sessions']} /* Sessions */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('views_sessions')}
\t\t\t);
\t\t\tname = Sessions;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_settings']} /* Settings */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('views_settings')}
\t\t\t);
\t\t\tname = Settings;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_auth']} /* Auth */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('views_auth')}
\t\t\t);
\t\t\tname = Auth;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{IDs['views_prompts']} /* Prompts */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{group_children_str('views_prompts')}
\t\t\t);
\t\t\tname = Prompts;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{IDs['target']} /* HealthBee */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {IDs['build_config_list_target']} /* Build configuration list for PBXNativeTarget "HealthBee" */;
\t\t\tbuildPhases = (
\t\t\t\t{IDs['sources_phase']} /* Sources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = HealthBee;
\t\t\tproductName = HealthBee;
\t\t\tproductReference = {IDs['product_ref']} /* HealthBee.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{IDs['proj']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{IDs['target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {IDs['build_config_list_proj']} /* Build configuration list for PBXProject "HealthBee" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {IDs['main_group']};
\t\t\tproductRefGroup = {IDs['products_group']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{IDs['target']} /* HealthBee */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
\t\t{IDs['sources_phase']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_children}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{IDs['debug_proj']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "\$(inherited)");
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{IDs['release_proj']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{IDs['debug_target']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSTCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSTCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tBUNDLE_LOADER = "\$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.healthbee.app";
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{IDs['release_target']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSTCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSTCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tBUNDLE_LOADER = "\$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.healthbee.app";
\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{IDs['build_config_list_proj']} /* Build configuration list for PBXProject "HealthBee" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{IDs['debug_proj']} /* Debug */,
\t\t\t\t{IDs['release_proj']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{IDs['build_config_list_target']} /* Build configuration list for PBXNativeTarget "HealthBee" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{IDs['debug_target']} /* Debug */,
\t\t\t\t{IDs['release_target']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {IDs['proj']} /* Project object */;
}}
"""

with open('/Users/luyuan/Projects/Health-Bee/client/HealthBee.xcodeproj/project.pbxproj', 'w') as f:
    f.write(pbxproj)

print("Generated successfully")
