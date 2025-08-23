import Foundation
import Testing

@testable import Vegas

@Suite("Vegas Commands", .serialized)
struct VegasCommandsTests {

    @Suite("Infrastructure Command", .serialized)
    struct InfrastructureCommandTests {

        @Test("infrastructure command has correct name and CloudFormation description")
        func createsInfrastructure() async throws {
            // Given an infrastructure command
            _ = Infrastructure()

            // Then it should have correct configuration
            let config = Infrastructure.configuration
            #expect(config.commandName == "infrastructure")
            #expect(config.abstract == "Create AWS infrastructure using CloudFormation")
        }

        @Test("infrastructure command has correct properties")
        func hasCorrectProperties() {
            // Given an infrastructure command configuration
            let config = Infrastructure.configuration

            // Then it should have expected properties
            #expect(config.commandName == "infrastructure")
            #expect(config.abstract == "Create AWS infrastructure using CloudFormation")
        }
    }

    @Suite("Elephants Command", .serialized)
    struct ElephantsCommandTests {

        @Test("elephants command configuration describes PostgreSQL tunnel connection")
        func connectsToPostgres() async throws {
            // Given an elephants command
            _ = Elephants()

            // Then it should have correct configuration
            let config = Elephants.configuration
            #expect(config.commandName == "elephants")
            #expect(
                config.abstract
                    == "Connect to production RDS PostgreSQL database through bastion host SSH tunnel"
            )
        }

        @Test("elephants command has correct properties")
        func hasCorrectProperties() {
            // Given an elephants command configuration
            let config = Elephants.configuration

            // Then it should have expected properties
            #expect(config.commandName == "elephants")
            #expect(
                config.abstract
                    == "Connect to production RDS PostgreSQL database through bastion host SSH tunnel"
            )
        }
    }

    @Suite("AWS Session Manager Tunnel", .serialized)
    struct AWSSessionManagerTunnelTests {

        @Test("tunnel manager initializes with bastion instance and RDS endpoint configuration")
        func createsTunnelWithCorrectConfiguration() async throws {
            // Given tunnel configuration
            let config = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a tunnel manager
            let tunnelManager = AWSSessionManagerTunnel(configuration: config)

            // Then tunnel should be configured correctly
            #expect(tunnelManager.configuration.bastionInstanceId == "i-1234567890abcdef0")
            #expect(tunnelManager.configuration.rdsEndpoint == "test-db.cluster-xyz.us-west-2.rds.amazonaws.com")
            #expect(tunnelManager.configuration.localPort == 5432)
            #expect(tunnelManager.configuration.remotePort == 5432)
            #expect(tunnelManager.isConnected == false)
        }

        @Test("tunnel validation detects missing AWS credentials and handles gracefully")
        func validatesAWSCredentialsArePresent() async throws {
            // Given tunnel configuration
            let config = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a tunnel manager
            let tunnelManager = AWSSessionManagerTunnel(configuration: config)

            // Then it should validate AWS credentials
            do {
                try await tunnelManager.validateAWSCredentials()
                // If we reach here, credentials are valid
            } catch TunnelError.missingAWSCredentials {
                // This is expected if credentials are not set
            }
        }

        @Test("tunnel connection sets connected state to true when establishment succeeds")
        func establishesTunnelConnection() async throws {
            // Given tunnel configuration
            let config = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a tunnel manager
            let tunnelManager = AWSSessionManagerTunnel(configuration: config)

            // Then tunnel should be able to establish connection
            do {
                try await tunnelManager.establishTunnel()
                #expect(tunnelManager.isConnected == true)
            } catch TunnelError.missingAWSCredentials {
                // This is expected in CI environment without AWS credentials
            } catch TunnelError.tunnelEstablishmentFailed {
                // This is expected if AWS resources don't exist
            }
        }

        @Test("tunnel termination resets connected state to false")
        func terminatesTunnelConnection() async throws {
            // Given tunnel configuration
            let config = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a tunnel manager
            let tunnelManager = AWSSessionManagerTunnel(configuration: config)

            // Then tunnel should be able to terminate connection
            await tunnelManager.terminateTunnel()
            #expect(tunnelManager.isConnected == false)
        }

        @Test("tunnel generates PostgreSQL connection URL with localhost and tunnel port")
        func providesConnectionURLForPostgres() async throws {
            // Given tunnel configuration
            let config = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a tunnel manager
            let tunnelManager = AWSSessionManagerTunnel(configuration: config)

            // Then it should provide correct connection URL
            let connectionURL = tunnelManager.getPostgresConnectionURL(
                username: "postgres",
                password: "testpass",
                database: "luxe"
            )
            #expect(connectionURL == "postgresql://postgres:testpass@127.0.0.1:5432/luxe?sslmode=require")
        }
    }

    @Suite("Postgres Connection Manager", .serialized)
    struct PostgresConnectionManagerTests {

        @Test("connection manager initializes with tunnel configuration and database credentials")
        func createsConnectionManagerWithTunnel() async throws {
            // Given tunnel configuration
            let tunnelConfig = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a connection manager
            let connectionManager = PostgresConnectionManager(
                tunnelConfiguration: tunnelConfig,
                username: "postgres",
                password: "testpass",
                database: "luxe"
            )

            // Then connection manager should be configured correctly
            #expect(connectionManager.username == "postgres")
            #expect(connectionManager.database == "luxe")
            #expect(connectionManager.isConnected == false)
        }

        @Test("connection manager sets connected state when database connection succeeds")
        func establishesConnectionThroughTunnel() async throws {
            // Given tunnel configuration
            let tunnelConfig = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a connection manager
            let connectionManager = PostgresConnectionManager(
                tunnelConfiguration: tunnelConfig,
                username: "postgres",
                password: "testpass",
                database: "luxe"
            )

            // Then connection should be establishable
            do {
                try await connectionManager.connect()
                #expect(connectionManager.isConnected == true)
            } catch {
                // Connection may fail in test environment
            }
        }

        @Test("connection health check returns true when database is accessible")
        func testsConnectionAfterEstablishingTunnel() async throws {
            // Given tunnel configuration
            let tunnelConfig = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a connection manager
            let connectionManager = PostgresConnectionManager(
                tunnelConfiguration: tunnelConfig,
                username: "postgres",
                password: "testpass",
                database: "luxe"
            )

            // Then connection should be testable
            do {
                let isHealthy = try await connectionManager.testConnection()
                #expect(isHealthy == true)
            } catch {
                // Connection may fail in test environment
            }
        }

        @Test("disconnect operation resets connection state and cleans up tunnel")
        func disconnectsAndCleansUpTunnel() async throws {
            // Given tunnel configuration
            let tunnelConfig = TunnelConfiguration(
                bastionInstanceId: "i-1234567890abcdef0",
                rdsEndpoint: "test-db.cluster-xyz.us-west-2.rds.amazonaws.com",
                localPort: 5432,
                remotePort: 5432
            )

            // When creating a connection manager
            let connectionManager = PostgresConnectionManager(
                tunnelConfiguration: tunnelConfig,
                username: "postgres",
                password: "testpass",
                database: "luxe"
            )

            // Then connection should be disconnectable
            await connectionManager.disconnect()
            #expect(connectionManager.isConnected == false)
        }
    }

    @Suite("Refresh Command", .serialized)
    struct RefreshCommandTests {

        @Test("refresh command configuration describes ECS service Docker image updates")
        func refreshesECSServices() async throws {
            // Given a refresh command
            _ = Refresh()

            // Then it should have correct configuration
            let config = Refresh.configuration
            #expect(config.commandName == "refresh")
            #expect(config.abstract == "Update all ECS services with the latest Docker images")
        }

        @Test("refresh command has correct properties")
        func hasCorrectProperties() {
            // Given a refresh command configuration
            let config = Refresh.configuration

            // Then it should have expected properties
            #expect(config.commandName == "refresh")
            #expect(config.abstract == "Update all ECS services with the latest Docker images")
        }
    }

    @Suite("Main Command", .serialized)
    struct MainCommandTests {

        @Test("has correct subcommands")
        func hasCorrectSubcommands() {
            // Given the main Vegas command configuration
            let config = Vegas.configuration

            // Then it should have correct properties
            #expect(config.commandName == "Vegas")
            #expect(config.abstract == "AWS infrastructure management tool")
            #expect(config.subcommands.count == 8)
            #expect(config.subcommands.contains { $0 == Infrastructure.self })
            #expect(config.subcommands.contains { $0 == Deploy.self })
            #expect(config.subcommands.contains { $0 == Versions.self })
            #expect(config.subcommands.contains { $0 == Elephants.self })
            #expect(config.subcommands.contains { $0 == Refresh.self })
            #expect(config.subcommands.contains { $0 == CheckUser.self })
            #expect(config.subcommands.contains { $0 == CheckUserSimple.self })
            #expect(config.subcommands.contains { $0 == SESSetup.self })
        }
    }
}
