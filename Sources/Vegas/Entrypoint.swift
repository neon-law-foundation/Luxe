import ArgumentParser
import Foundation
import SotoCloudFormation
import SotoCore
import SotoECS

@main
struct Vegas: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "Vegas",
        abstract: "AWS infrastructure management tool",
        subcommands: [
            Infrastructure.self, Deploy.self, Versions.self, Elephants.self, Refresh.self, CheckUser.self,
            CheckUserSimple.self, SESSetup.self,
        ]
    )
}
