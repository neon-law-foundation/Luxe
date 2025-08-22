import ArgumentParser

@main
struct Palette: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "palette",
        abstract: "Database migration tool",
        subcommands: [NewCommand.self, MigrateCommand.self, SeedsCommand.self]
    )
}
