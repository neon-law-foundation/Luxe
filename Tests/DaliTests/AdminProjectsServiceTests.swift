import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Admin Projects Service Tests", .serialized)
struct AdminProjectsServiceTests {

    @Test("AdminProjectsService can list projects")
    func adminProjectsServiceCanListProjects() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            // Create a test project first
            let uniqueCodename = "TEST_PROJECT_\(UniqueCodeGenerator.generateISOCode(prefix: "PROJ"))"
            let testProject = Project()
            testProject.codename = uniqueCodename
            try await testProject.save(on: database)

            // Test listing projects
            let projects = try await service.listProjects()

            #expect(projects.count >= 1)
            #expect(projects.contains { $0.codename == uniqueCodename })
        }
    }

    @Test("AdminProjectsService can get project by ID")
    func adminProjectsServiceCanGetProjectById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            // Create a test project
            let uniqueCodename = "GET_TEST_\(UniqueCodeGenerator.generateISOCode(prefix: "GET"))"
            let testProject = Project()
            testProject.codename = uniqueCodename
            try await testProject.save(on: database)

            // Test getting project by ID
            guard let projectId = testProject.id else {
                throw ValidationError("Project ID not available after save")
            }

            let retrievedProject = try await service.getProject(projectId: projectId)

            #expect(retrievedProject != nil)
            #expect(retrievedProject?.codename == uniqueCodename)
        }
    }

    @Test("AdminProjectsService can create project")
    func adminProjectsServiceCanCreateProject() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            let uniqueCodename = "CREATE_TEST_\(UniqueCodeGenerator.generateISOCode(prefix: "CREATE"))"

            let createdProject = try await service.createProject(codename: uniqueCodename)

            #expect(createdProject.codename == uniqueCodename)
            #expect(createdProject.id != nil)

            // Verify project was actually saved to database
            let retrievedProject = try await service.getProject(projectId: createdProject.id!)
            #expect(retrievedProject?.codename == uniqueCodename)
        }
    }

    @Test("AdminProjectsService can update project")
    func adminProjectsServiceCanUpdateProject() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            // Create a test project first
            let originalCodename = "UPDATE_ORIG_\(UniqueCodeGenerator.generateISOCode(prefix: "ORIG"))"
            let testProject = Project()
            testProject.codename = originalCodename
            try await testProject.save(on: database)

            // Update the project
            let newCodename = "UPDATE_NEW_\(UniqueCodeGenerator.generateISOCode(prefix: "NEW"))"

            let updatedProject = try await service.updateProject(
                projectId: testProject.id!,
                codename: newCodename
            )

            #expect(updatedProject.codename == newCodename)
            #expect(updatedProject.id == testProject.id)

            // Verify changes were persisted
            let retrievedProject = try await service.getProject(projectId: testProject.id!)
            #expect(retrievedProject?.codename == newCodename)
        }
    }

    @Test("AdminProjectsService can delete project")
    func adminProjectsServiceCanDeleteProject() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            // Create a test project first
            let uniqueCodename = "DELETE_TEST_\(UniqueCodeGenerator.generateISOCode(prefix: "DELETE"))"
            let testProject = Project()
            testProject.codename = uniqueCodename
            try await testProject.save(on: database)

            // Verify project exists
            let projectBeforeDelete = try await service.getProject(projectId: testProject.id!)
            #expect(projectBeforeDelete != nil)

            // Delete the project
            try await service.deleteProject(projectId: testProject.id!)

            // Verify project no longer exists
            let projectAfterDelete = try await service.getProject(projectId: testProject.id!)
            #expect(projectAfterDelete == nil)
        }
    }

    @Test("AdminProjectsService handles non-existent project gracefully")
    func adminProjectsServiceHandlesNonExistentProject() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            let nonExistentId = UUID()
            let retrievedProject = try await service.getProject(projectId: nonExistentId)

            #expect(retrievedProject == nil)
        }
    }

    @Test("AdminProjectsService validates input data")
    func adminProjectsServiceValidatesInputData() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            // Test with empty codename
            do {
                _ = try await service.createProject(codename: "")
                #expect(Bool(false), "Should throw ValidationError for empty codename")
            } catch let error as ValidationError {
                #expect(error.message.contains("Codename cannot be empty"))
            }

            // Test with whitespace-only codename
            do {
                _ = try await service.createProject(codename: "   ")
                #expect(Bool(false), "Should throw ValidationError for whitespace-only codename")
            } catch let error as ValidationError {
                #expect(error.message.contains("Codename cannot be empty"))
            }
        }
    }

    @Test("AdminProjectsService trims whitespace from codename")
    func adminProjectsServiceTrimsWhitespaceFromCodename() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            let codenameParts = UniqueCodeGenerator.generateISOCode(prefix: "TRIM")
            let codeNameWithWhitespace = "  TRIMMED_\(codenameParts)  "
            let expectedCodename = "TRIMMED_\(codenameParts)"

            let createdProject = try await service.createProject(codename: codeNameWithWhitespace)

            #expect(createdProject.codename == expectedCodename)

            // Verify trimmed value was saved
            let retrievedProject = try await service.getProject(projectId: createdProject.id!)
            #expect(retrievedProject?.codename == expectedCodename)
        }
    }

    @Test("AdminProjectsService lists projects in descending creation order")
    func adminProjectsServiceListsProjectsInDescendingOrder() async throws {
        try await TestUtilities.withApp { app, database in
            let service = AdminProjectsService(database: database)

            // Create multiple test projects with slight time differences
            let uniqueId = UniqueCodeGenerator.generateISOCode(prefix: "ORDER")
            let firstCodename = "FIRST_\(uniqueId)"
            let secondCodename = "SECOND_\(uniqueId)"

            let firstProject = Project()
            firstProject.codename = firstCodename
            try await firstProject.save(on: database)

            // Small delay to ensure different creation times
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

            let secondProject = Project()
            secondProject.codename = secondCodename
            try await secondProject.save(on: database)

            // List projects and verify order (newest first)
            let projects = try await service.listProjects()

            // Find our test projects in the results
            guard let firstIndex = projects.firstIndex(where: { $0.codename == firstCodename }),
                let secondIndex = projects.firstIndex(where: { $0.codename == secondCodename })
            else {
                throw ValidationError("Test projects not found in results")
            }

            // Second project should come before first project (descending order)
            #expect(secondIndex < firstIndex)
        }
    }
}
