import ArgumentParser
import Foundation
import SotoCloudFormation
import SotoCore

struct CheckUserSimple: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check-user-simple",
        abstract: "Check if a user exists in the auth.users table using psql"
    )

    @Argument(help: "The email address or user ID to check")
    var userIdentifier: String

    func run() async throws {
        print("🔍 Checking for user: \(userIdentifier)")
        print("📍 Region: us-west-2 (Oregon)")

        // Get the connection details from environment variables
        guard let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            print("❌ AWS_ACCESS_KEY_ID environment variable not set")
            throw ExitCode.failure
        }

        guard let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            print("❌ AWS_SECRET_ACCESS_KEY environment variable not set")
            throw ExitCode.failure
        }

        guard let luxePassword = ProcessInfo.processInfo.environment["LUXE_PASSWORD"] else {
            print("❌ LUXE_PASSWORD environment variable not set")
            throw ExitCode.failure
        }

        // Connect to us-west-2 region where the RDS database is running
        let primaryRegion = Region.uswest2
        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        do {
            let cloudFormation = CloudFormation(client: luxeCloud.client, region: primaryRegion)

            // Get the RDS endpoint from CloudFormation stack outputs
            let rdsStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-rds")
            let rdsResponse = try await cloudFormation.describeStacks(rdsStackRequest)

            guard let rdsStack = rdsResponse.stacks?.first,
                let rdsOutputs = rdsStack.outputs,
                let endpointOutput = rdsOutputs.first(where: { $0.outputKey == "DatabaseEndpoint" }),
                let rdsEndpoint = endpointOutput.outputValue
            else {
                print("❌ Could not find oregon-rds stack or DatabaseEndpoint output")
                print("💡 Make sure the RDS infrastructure exists in us-west-2")
                throw ExitCode.failure
            }

            // Get the bastion host instance ID from CloudFormation stack outputs
            let bastionStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-bastion")
            let bastionResponse = try await cloudFormation.describeStacks(bastionStackRequest)

            guard let bastionStack = bastionResponse.stacks?.first,
                let bastionOutputs = bastionStack.outputs,
                let instanceOutput = bastionOutputs.first(where: { $0.outputKey == "BastionInstanceId" }),
                let bastionInstanceId = instanceOutput.outputValue
            else {
                print("❌ Could not find oregon-bastion stack or BastionInstanceId output")
                print("💡 Make sure the bastion host infrastructure exists in us-west-2")
                throw ExitCode.failure
            }

            print("📍 RDS Endpoint: \(rdsEndpoint)")
            print("🖥️ Bastion Instance: \(bastionInstanceId)")
            print("")

            // Use a unique local port to avoid conflicts
            let localPort = 15434

            // Final comprehensive check
            let sqlQuery = """
                SELECT 'Auth User Exists' as check_type,
                       CASE WHEN COUNT(*) > 0 THEN 'YES - Found' ELSE 'NO - Missing' END as result
                FROM auth.users WHERE username = '\(userIdentifier)'
                UNION ALL
                SELECT 'Auth User ID' as check_type,
                       COALESCE((SELECT id::text FROM auth.users WHERE username = '\(userIdentifier)'), 'NOT_FOUND') as result
                UNION ALL
                SELECT 'Auth User Role' as check_type,
                       COALESCE((SELECT role::text FROM auth.users WHERE username = '\(userIdentifier)'), 'NOT_FOUND') as result
                UNION ALL
                SELECT 'Auth User Person ID' as check_type,
                       COALESCE((SELECT person_id::text FROM auth.users WHERE username = '\(userIdentifier)'), 'NOT_FOUND') as result
                UNION ALL
                SELECT 'Directory Person Exists' as check_type,
                       CASE WHEN COUNT(*) > 0 THEN 'YES - Found' ELSE 'NO - Missing' END as result
                FROM directory.people WHERE email = '\(userIdentifier)'
                UNION ALL
                SELECT 'Directory Person ID' as check_type,
                       COALESCE((SELECT id::text FROM directory.people WHERE email = '\(userIdentifier)'), 'NOT_FOUND') as result
                UNION ALL
                SELECT 'Directory Person Name' as check_type,
                       COALESCE((SELECT name FROM directory.people WHERE email = '\(userIdentifier)'), 'NOT_FOUND') as result
                UNION ALL
                SELECT 'Link Check' as check_type,
                       CASE WHEN EXISTS(
                           SELECT 1 FROM auth.users u
                           JOIN directory.people p ON u.person_id = p.id
                           WHERE u.username = '\(userIdentifier)' AND p.email = '\(userIdentifier)'
                       ) THEN 'LINKED' ELSE 'NOT_LINKED' END as result;
                """

            // Start Session Manager tunnel
            print("🔗 Starting AWS Session Manager tunnel...")
            let tunnelProcess = Process()
            tunnelProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            tunnelProcess.arguments = [
                "aws", "ssm", "start-session",
                "--target", bastionInstanceId,
                "--document-name", "AWS-StartPortForwardingSessionToRemoteHost",
                "--parameters", "host=\"\(rdsEndpoint)\",portNumber=\"5432\",localPortNumber=\"\(localPort)\"",
            ]

            let tunnelOutput = Pipe()
            tunnelProcess.standardOutput = tunnelOutput
            tunnelProcess.standardError = tunnelOutput

            try tunnelProcess.run()

            // Wait for tunnel to establish
            try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

            if tunnelProcess.isRunning {
                print("📍 Local port: \(localPort)")
                print("📍 Remote endpoint: \(rdsEndpoint):5432")
                print("")

                // Execute the SQL query
                print("📊 Executing user check query...")
                let psqlProcess = Process()
                psqlProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                psqlProcess.arguments = [
                    "psql",
                    "postgresql://postgres:\(luxePassword)@127.0.0.1:\(localPort)/luxe?sslmode=prefer",
                    "-c", sqlQuery,
                ]

                let queryOutput = Pipe()
                let queryError = Pipe()
                psqlProcess.standardOutput = queryOutput
                psqlProcess.standardError = queryError

                try psqlProcess.run()
                psqlProcess.waitUntilExit()

                let outputData = queryOutput.fileHandleForReading.readDataToEndOfFile()
                let errorData = queryError.fileHandleForReading.readDataToEndOfFile()

                if psqlProcess.terminationStatus == 0 {
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    print("✅ Query Results:")
                    print(output)

                    // Check if we found the issue and suggest fix
                    if output.contains("NOT_LINKED") && output.contains("Auth User Person ID     | NOT_FOUND") {
                        print("\n🔧 ISSUE IDENTIFIED:")
                        print("   The auth.users record exists but person_id is NULL")
                        print("   This prevents the application from linking to directory.people")
                        print("\n💡 SUGGESTED FIX:")
                        print("   Run this SQL command to link the records:")
                        print("   UPDATE auth.users SET person_id = (")
                        print("     SELECT id FROM directory.people WHERE email = '\(userIdentifier)'")
                        print("   ) WHERE username = '\(userIdentifier)';")
                    }
                } else {
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    print("❌ Query failed:")
                    print(error)
                }

                // Terminate tunnel
                print("🔌 Terminating tunnel...")
                tunnelProcess.terminate()
                tunnelProcess.waitUntilExit()

            } else {
                print("❌ Failed to establish tunnel")
                try await luxeCloud.client.shutdown()
                throw ExitCode.failure
            }

            try await luxeCloud.client.shutdown()

        } catch {
            print("❌ Error: \(error)")
            try? await luxeCloud.client.shutdown()
            throw ExitCode.failure
        }
    }
}
