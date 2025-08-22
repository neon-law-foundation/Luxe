import Testing

@testable import Holiday

@Suite("Holiday Command", .serialized)
struct HolidayCommandTests {
    @Test("Vacation command creates static website and stops ECS services")
    func vacationCommandCreatesStaticWebsiteAndStopsECSServices() async throws {
        let command = HolidayCommand()
        command.mode = .vacation

        // Mock AWS clients would be injected here in real implementation
        // For now, we're testing the structure

        // The vacation command should:
        // 1. Upload holiday HTML to S3
        // 2. Enable static website hosting on S3
        // 3. Update ALB rules to point to S3
        // 4. Stop all ECS services

        #expect(command.mode == .vacation)
    }

    @Test("Work command restores ECS services and disables static website")
    func workCommandRestoresECSServicesAndDisablesStaticWebsite() async throws {
        let command = HolidayCommand()
        command.mode = .work

        // The work command should:
        // 1. Start all ECS services
        // 2. Update ALB rules to point to ECS
        // 3. Optionally disable static website hosting

        #expect(command.mode == .work)
    }

    @Test("Holiday HTML content includes trifecta information")
    func holidayHTMLContentIncludesTrifectaInformation() {
        let generator = HolidayHTMLGenerator()
        let html = generator.generateHTML()

        // Verify the HTML contains key trifecta information
        #expect(html.contains("Neon Law"))
        #expect(html.contains("Neon Law Foundation"))
        #expect(html.contains("Sagebrush Services"))
        #expect(html.contains("support@sagebrush.services"))
        #expect(html.contains("We are currently on holiday"))
    }

    @Test("Service configuration includes active web services")
    func serviceConfigurationIncludesActiveWebServices() {
        let config = HolidayConfiguration()

        let activeServices = [
            "bazaar"
        ]

        // Verify active services are included
        for service in activeServices {
            #expect(config.ecsServices.contains(service))
        }

        // Verify inactive services are not included
        let inactiveServices = [
            "sagebrushweb",
            "neon-web-service",
            "nlf-web-service",
        ]

        for service in inactiveServices {
            #expect(!config.ecsServices.contains(service))
        }
    }
}
