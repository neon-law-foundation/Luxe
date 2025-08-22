import Foundation

do {
    let parser = CommandLineParser()
    let repositoryName = try parser.parseRepositoryName()

    print("Creating repository: \(repositoryName)")

    let miseEnPlace = MiseEnPlace()
    try await miseEnPlace.createRepository(name: repositoryName)
    try await miseEnPlace.shutdown()

    print("✅ Successfully created repository: https://github.com/neon-law/\(repositoryName)")

} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}
