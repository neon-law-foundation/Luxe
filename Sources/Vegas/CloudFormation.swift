import SotoCloudFormation
import SotoCore

protocol Stack {
    var templateBody: String { get }
}

struct LuxeCloud {
    public let client: AWSClient

    init(accessKey: String, secretKey: String) {
        self.client = AWSClient(
            credentialProvider: .static(accessKeyId: accessKey, secretAccessKey: secretKey),
        )
    }

    public func upsertStack(
        stack: Stack,
        region: Region,
        stackParameters: [String: String],
        name: String
    ) async throws {
        let cloudFormationClient = CloudFormation(client: client, region: region)

        do {
            let response = try await cloudFormationClient.createStack(
                capabilities: [.capabilityNamedIam],
                enableTerminationProtection: true,
                parameters: stackParameters.map {
                    CloudFormation.Parameter(parameterKey: $0.key, parameterValue: $0.value)
                },
                stackName: name,
                templateBody: stack.templateBody,
            )

            print(response)
        } catch {
            print(error)

            do {
                let response = try await cloudFormationClient.updateStack(
                    capabilities: [.capabilityNamedIam],
                    parameters: stackParameters.map {
                        CloudFormation.Parameter(parameterKey: $0.key, parameterValue: $0.value)
                    },
                    stackName: name,
                    templateBody: stack.templateBody,
                )

                // Enable termination protection on the updated stack
                let _ = try await cloudFormationClient.updateTerminationProtection(
                    enableTerminationProtection: true,
                    stackName: name
                )

                print(response)
            } catch {
                print(error)
            }
        }
    }

    public func getStackOutput(
        stackName: String,
        outputKey: String,
        region: Region
    ) async throws -> String {
        let cloudFormationClient = CloudFormation(client: client, region: region)

        let response = try await cloudFormationClient.describeStacks(stackName: stackName)

        guard let stack = response.stacks?.first,
            let outputs = stack.outputs
        else {
            throw CloudFormationError.stackNotFound
        }

        guard let output = outputs.first(where: { $0.outputKey == outputKey }),
            let value = output.outputValue
        else {
            throw CloudFormationError.outputNotFound
        }

        return value
    }

    public func waitForStackCompletion(
        stackName: String,
        region: Region
    ) async throws {
        let cloudFormationClient = CloudFormation(client: client, region: region)

        print("⏳ Waiting for stack \(stackName) to complete...")

        while true {
            let response = try await cloudFormationClient.describeStacks(stackName: stackName)

            guard let stack = response.stacks?.first else {
                throw CloudFormationError.stackNotFound
            }

            let status = stack.stackStatus

            switch status {
            case .createComplete, .updateComplete:
                print("✅ Stack \(stackName) completed successfully")
                return
            case .createFailed, .updateFailed, .rollbackComplete, .updateRollbackComplete:
                throw CloudFormationError.stackFailed(status)
            case .createInProgress, .updateInProgress:
                // Continue waiting
                try await Task.sleep(nanoseconds: 10_000_000_000)  // Wait 10 seconds
            default:
                // Continue waiting for other statuses
                try await Task.sleep(nanoseconds: 10_000_000_000)  // Wait 10 seconds
            }
        }
    }
}

enum CloudFormationError: Error {
    case stackNotFound
    case outputNotFound
    case stackFailed(CloudFormation.StackStatus?)
}
