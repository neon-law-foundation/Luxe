import Foundation
import Testing

@testable import Wayne

@Suite("Wayne CLI Tests", .serialized)
struct WayneTests {

    @Test("Should identify macOS targets from Package.swift")
    func identifiesMacOSTargets() async throws {
        let packageContent = """
            let package = Package(
                name: "TestPackage",
                platforms: [.macOS(.v15)],
                targets: [
                    .executableTarget(name: "Concierge", dependencies: ["Dali"]),
                    .executableTarget(name: "Vegas", dependencies: []),
                    .target(name: "Dali", dependencies: [])
                ]
            )
            """

        let parser = PackageParser()
        let targets = try parser.parseTargets(from: packageContent)

        #expect(targets.count == 2)
        #expect(targets.contains { $0.name == "Concierge" })
        #expect(targets.contains { $0.name == "Vegas" })
    }

    @Test("Should generate Xcode project structure")
    func generatesXcodeProjectStructure() async throws {
        let targetInfo = TargetInfo(
            name: "TestApp",
            dependencies: ["Dali"],
            sourceFiles: ["TestApp.swift", "ContentView.swift"],
            isExecutable: true
        )

        let generator = XcodeProjectGenerator()
        let projectPath = try generator.generateProject(for: targetInfo, in: "/tmp/test")

        #expect(FileManager.default.fileExists(atPath: projectPath))
        #expect(projectPath.hasSuffix("TestApp.xcodeproj"))
    }

    @Test("Should create project in temporary directory")
    func createsProjectInTemporaryDirectory() async throws {
        let targetInfo = TargetInfo(
            name: "TestApp",
            dependencies: [],
            sourceFiles: ["TestApp.swift"],
            isExecutable: true
        )

        let generator = XcodeProjectGenerator()
        let tempPath = "/tmp/wayne-test"

        let projectPath = try generator.generateProject(for: targetInfo, in: tempPath)

        #expect(projectPath.contains("wayne-test"))
        #expect(projectPath.contains("TestApp.xcodeproj"))
    }

    @Test("Should handle target with no dependencies")
    func handlesTargetWithNoDependencies() async throws {
        let targetInfo = TargetInfo(
            name: "SimpleApp",
            dependencies: [],
            sourceFiles: ["SimpleApp.swift"],
            isExecutable: true
        )

        let generator = XcodeProjectGenerator()
        let projectPath = try generator.generateProject(for: targetInfo, in: "/tmp/test")

        #expect(FileManager.default.fileExists(atPath: projectPath))
    }

    @Test("Should validate target exists before generation")
    func validatesTargetExists() async throws {
        let packageContent = """
            let package = Package(
                name: "TestPackage",
                platforms: [.macOS(.v15)],
                targets: [
                    .executableTarget(name: "ExistingApp", dependencies: [])
                ]
            )
            """

        let parser = PackageParser()
        let targets = try parser.parseTargets(from: packageContent)

        #expect(targets.first?.name == "ExistingApp")
        #expect(!targets.contains { $0.name == "NonExistentApp" })
    }
}

@Suite("TargetInfo Tests", .serialized)
struct TargetInfoTests {

    @Test("Should create TargetInfo with all properties")
    func createsTargetInfoWithAllProperties() {
        let targetInfo = TargetInfo(
            name: "TestTarget",
            dependencies: ["Dep1", "Dep2"],
            sourceFiles: ["File1.swift", "File2.swift"],
            isExecutable: true
        )

        #expect(targetInfo.name == "TestTarget")
        #expect(targetInfo.dependencies == ["Dep1", "Dep2"])
        #expect(targetInfo.sourceFiles == ["File1.swift", "File2.swift"])
        #expect(targetInfo.isExecutable == true)
    }

    @Test("Should handle empty dependencies")
    func handlesEmptyDependencies() {
        let targetInfo = TargetInfo(
            name: "TestTarget",
            dependencies: [],
            sourceFiles: ["File1.swift"],
            isExecutable: true
        )

        #expect(targetInfo.dependencies.isEmpty)
        #expect(targetInfo.name == "TestTarget")
    }
}

@Suite("PackageParser Tests", .serialized)
struct PackageParserTests {

    @Test("Should parse executable targets only")
    func parsesExecutableTargetsOnly() async throws {
        let packageContent = """
            let package = Package(
                name: "TestPackage",
                platforms: [.macOS(.v15)],
                targets: [
                    .executableTarget(name: "App1", dependencies: []),
                    .target(name: "Library1", dependencies: []),
                    .executableTarget(name: "App2", dependencies: ["Library1"]),
                    .testTarget(name: "Tests", dependencies: ["App1"])
                ]
            )
            """

        let parser = PackageParser()
        let targets = try parser.parseTargets(from: packageContent)

        #expect(targets.count == 2)
        #expect(targets.allSatisfy { $0.isExecutable })
        #expect(targets.contains { $0.name == "App1" })
        #expect(targets.contains { $0.name == "App2" })
    }

    @Test("Should extract dependencies correctly")
    func extractsDependenciesCorrectly() async throws {
        let packageContent = """
            let package = Package(
                name: "TestPackage",
                platforms: [.macOS(.v15)],
                targets: [
                    .executableTarget(name: "App", dependencies: ["Dep1", "Dep2", .product(name: "ExternalDep", package: "external")])
                ]
            )
            """

        let parser = PackageParser()
        let targets = try parser.parseTargets(from: packageContent)

        #expect(targets.count == 1)
        #expect(targets.first?.dependencies.contains("Dep1") == true)
        #expect(targets.first?.dependencies.contains("Dep2") == true)
    }
}
