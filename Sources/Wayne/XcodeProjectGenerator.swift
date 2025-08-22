import Foundation

/// Generates Xcode projects for Swift package targets
struct XcodeProjectGenerator {

    /// Generate an Xcode project for the given target
    func generateProject(for target: TargetInfo, in outputDirectory: String) throws -> String {
        // Create a directory for the whole project
        let projectFolderName = "\(target.name)Project"
        let projectFolderPath = "\(outputDirectory)/\(projectFolderName)"
        let fileManager = FileManager.default

        // Remove existing project folder if it exists
        if fileManager.fileExists(atPath: projectFolderPath) {
            try fileManager.removeItem(atPath: projectFolderPath)
        }

        try fileManager.createDirectory(atPath: projectFolderPath, withIntermediateDirectories: true)

        // Create a Package.swift that wraps the main target
        let packagePath = "\(projectFolderPath)/Package.swift"
        let packageContent = generatePackageSwift(for: target)
        try packageContent.write(toFile: packagePath, atomically: true, encoding: .utf8)

        // Create the .xcodeproj bundle directory
        let xcodeProjectPath = "\(projectFolderPath)/\(target.name).xcodeproj"
        try fileManager.createDirectory(atPath: xcodeProjectPath, withIntermediateDirectories: true)

        // Create a basic project.pbxproj file
        let pbxprojPath = "\(xcodeProjectPath)/project.pbxproj"
        let pbxprojContent = generatePbxproj(for: target)
        try pbxprojContent.write(toFile: pbxprojPath, atomically: true, encoding: .utf8)

        return xcodeProjectPath
    }

    /// Generate a local Package.swift that references the main package
    private func generatePackageSwift(for target: TargetInfo) -> String {
        let luxePath = FileManager.default.currentDirectoryPath

        // Build clean dependencies for the target
        var cleanDependencies: [String] = []

        for dep in target.dependencies {
            if dep == "Dali" {
                cleanDependencies.append("\"Dali\"")
            } else if dep == "TouchMenu" {
                cleanDependencies.append("\"TouchMenu\"")
            } else if dep == "Logging" || dep == "swift-log" {
                cleanDependencies.append(".product(name: \"Logging\", package: \"Luxe\")")
            } else if !dep.contains("package") && !dep.contains("product") {
                // Only add if it's a simple dependency name
                cleanDependencies.append(".product(name: \"\(dep)\", package: \"Luxe\")")
            }
        }

        // Remove duplicates
        cleanDependencies = Array(Set(cleanDependencies))
        let dependenciesString = cleanDependencies.joined(separator: ",\n                ")

        return """
            // swift-tools-version: 6.1
            // The swift-tools-version declares the minimum version of Swift required to build this package.

            import PackageDescription

            let package = Package(
                name: "\(target.name)Project",
                platforms: [
                    .macOS(.v15)
                ],
                dependencies: [
                    // Reference to the main Luxe package for external dependencies
                    .package(path: "\(luxePath)")
                ],
                targets: [
                    // Copy of Dali target from main project
                    .target(
                        name: "Dali",
                        dependencies: [
                            .product(name: "Fluent", package: "Luxe"),
                            .product(name: "FluentPostgresDriver", package: "Luxe"),
                            .product(name: "Vapor", package: "Luxe"),
                            .product(name: "JSONSchema", package: "Luxe"),
                        ],
                        path: "\(luxePath)/Sources/Dali"
                    ),
                    // Copy of TouchMenu target if needed
                    .target(
                        name: "TouchMenu",
                        dependencies: [
                            .product(name: "VaporElementary", package: "Luxe"),
                            .product(name: "Markdown", package: "Luxe"),
                        ],
                        path: "\(luxePath)/Sources/TouchMenu"
                    ),
                    // Main \(target.name) target
                    .executableTarget(
                        name: "\(target.name)",
                        dependencies: [
                            \(dependenciesString)
                        ],
                        path: "\(luxePath)/Sources/\(target.name)"
                    )
                ]
            )
            """
    }

    /// Generate a simple main.swift that imports and runs the target
    private func generateMainSwift(for target: TargetInfo) -> String {
        // For Concierge, we need to import the module but not create a main since it has @main
        if target.name == "Concierge" {
            return """
                // This wrapper imports Concierge
                // The ConciergeApp has @main and will be launched automatically
                // when this target runs
                @_exported import Concierge
                """
        }

        // For other targets, create a generic main
        return """
            import \(target.name)

            // Entry point for \(target.name)
            // Add any initialization code here
            """
    }

    /// Generate a basic project.pbxproj file for Xcode
    private func generatePbxproj(for target: TargetInfo) -> String {
        let projectUUID = generateUUID()
        let targetUUID = generateUUID()
        let configListUUID = generateUUID()
        let debugConfigUUID = generateUUID()
        let releaseConfigUUID = generateUUID()

        return """
            // !$*UTF8*$!
            {
                archiveVersion = 1;
                classes = {
                };
                objectVersion = 77;
                objects = {
                    \(projectUUID) /* Project object */ = {
                        isa = PBXProject;
                        attributes = {
                            BuildIndependentTargetsInParallel = 1;
                            LastSwiftUpdateCheck = 1600;
                            LastUpgradeCheck = 1600;
                            TargetAttributes = {
                                \(targetUUID) = {
                                    CreatedOnToolsVersion = 16.0;
                                };
                            };
                        };
                        buildConfigurationList = \(configListUUID) /* Build configuration list for PBXProject */;
                        compatibilityVersion = "Xcode 15.0";
                        developmentRegion = en;
                        hasScannedForEncodings = 0;
                        knownRegions = (
                            en,
                            Base,
                        );
                        mainGroup = \(generateUUID());
                        projectDirPath = "";
                        projectRoot = "";
                        targets = (
                            \(targetUUID) /* \(target.name) */,
                        );
                    };
                    \(targetUUID) /* \(target.name) */ = {
                        isa = PBXNativeTarget;
                        buildConfigurationList = \(generateUUID()) /* Build configuration list for PBXNativeTarget */;
                        buildPhases = (
                        );
                        buildRules = (
                        );
                        dependencies = (
                        );
                        name = \(target.name);
                        productName = \(target.name);
                        productReference = \(generateUUID()) /* \(target.name) */;
                        productType = "com.apple.product-type.tool";
                    };
                    \(configListUUID) /* Build configuration list for PBXProject */ = {
                        isa = XCConfigurationList;
                        buildConfigurations = (
                            \(debugConfigUUID) /* Debug */,
                            \(releaseConfigUUID) /* Release */,
                        );
                        defaultConfigurationIsVisible = 0;
                        defaultConfigurationName = Release;
                    };
                    \(debugConfigUUID) /* Debug */ = {
                        isa = XCBuildConfiguration;
                        buildSettings = {
                            ALWAYS_SEARCH_USER_PATHS = NO;
                            CLANG_ANALYZER_NONNULL = YES;
                            CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                            CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                            CLANG_ENABLE_MODULES = YES;
                            CLANG_ENABLE_OBJC_ARC = YES;
                            CLANG_ENABLE_OBJC_WEAK = YES;
                            CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                            CLANG_WARN_BOOL_CONVERSION = YES;
                            CLANG_WARN_COMMA = YES;
                            CLANG_WARN_CONSTANT_CONVERSION = YES;
                            CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                            CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                            CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                            CLANG_WARN_EMPTY_BODY = YES;
                            CLANG_WARN_ENUM_CONVERSION = YES;
                            CLANG_WARN_INFINITE_RECURSION = YES;
                            CLANG_WARN_INT_CONVERSION = YES;
                            CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                            CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                            CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                            CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                            CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                            CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                            CLANG_WARN_STRICT_PROTOTYPES = YES;
                            CLANG_WARN_SUSPICIOUS_MOVE = YES;
                            CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                            CLANG_WARN_UNREACHABLE_CODE = YES;
                            CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                            COPY_PHASE_STRIP = NO;
                            DEBUG_INFORMATION_FORMAT = dwarf;
                            ENABLE_STRICT_OBJC_MSGSEND = YES;
                            ENABLE_TESTABILITY = YES;
                            GCC_C_LANGUAGE_STANDARD = gnu11;
                            GCC_DYNAMIC_NO_PIC = NO;
                            GCC_NO_COMMON_BLOCKS = YES;
                            GCC_OPTIMIZATION_LEVEL = 0;
                            GCC_PREPROCESSOR_DEFINITIONS = (
                                "DEBUG=1",
                                "$(inherited)",
                            );
                            GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                            GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                            GCC_WARN_UNDECLARED_SELECTOR = YES;
                            GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                            GCC_WARN_UNUSED_FUNCTION = YES;
                            GCC_WARN_UNUSED_VARIABLE = YES;
                            MACOSX_DEPLOYMENT_TARGET = 15.0;
                            MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
                            MTL_FAST_MATH = YES;
                            ONLY_ACTIVE_ARCH = YES;
                            SDKROOT = macosx;
                            SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
                            SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                        };
                        name = Debug;
                    };
                    \(releaseConfigUUID) /* Release */ = {
                        isa = XCBuildConfiguration;
                        buildSettings = {
                            ALWAYS_SEARCH_USER_PATHS = NO;
                            CLANG_ANALYZER_NONNULL = YES;
                            CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                            CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                            CLANG_ENABLE_MODULES = YES;
                            CLANG_ENABLE_OBJC_ARC = YES;
                            CLANG_ENABLE_OBJC_WEAK = YES;
                            CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                            CLANG_WARN_BOOL_CONVERSION = YES;
                            CLANG_WARN_COMMA = YES;
                            CLANG_WARN_CONSTANT_CONVERSION = YES;
                            CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                            CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                            CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                            CLANG_WARN_EMPTY_BODY = YES;
                            CLANG_WARN_ENUM_CONVERSION = YES;
                            CLANG_WARN_INFINITE_RECURSION = YES;
                            CLANG_WARN_INT_CONVERSION = YES;
                            CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                            CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                            CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                            CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                            CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                            CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                            CLANG_WARN_STRICT_PROTOTYPES = YES;
                            CLANG_WARN_SUSPICIOUS_MOVE = YES;
                            CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                            CLANG_WARN_UNREACHABLE_CODE = YES;
                            CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                            COPY_PHASE_STRIP = NO;
                            DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                            ENABLE_NS_ASSERTIONS = NO;
                            ENABLE_STRICT_OBJC_MSGSEND = YES;
                            GCC_C_LANGUAGE_STANDARD = gnu11;
                            GCC_NO_COMMON_BLOCKS = YES;
                            GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                            GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                            GCC_WARN_UNDECLARED_SELECTOR = YES;
                            GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                            GCC_WARN_UNUSED_FUNCTION = YES;
                            GCC_WARN_UNUSED_VARIABLE = YES;
                            MACOSX_DEPLOYMENT_TARGET = 15.0;
                            MTL_ENABLE_DEBUG_INFO = NO;
                            MTL_FAST_MATH = YES;
                            SDKROOT = macosx;
                            SWIFT_COMPILATION_MODE = wholemodule;
                            SWIFT_OPTIMIZATION_LEVEL = "-O";
                        };
                        name = Release;
                    };
                };
                rootObject = \(projectUUID) /* Project object */;
            }
            """
    }

    /// Generate a UUID for Xcode identifiers
    private func generateUUID() -> String {
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return String(uuid.prefix(24))
    }
}
