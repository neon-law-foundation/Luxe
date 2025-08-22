import Fluent
import FluentPostgresDriver
import Foundation
import Vapor

/// Configures the application's database.
// func configureDatabase(app: Application) async throws {
//     let postgresURL = URL(string: "postgres://postgres@localhost:5432/postgres?sslmode=disable")!
//     try app.databases.use(.postgres(url: postgresURL), as: .psql)
//     app.migrations.add([
//         Migrations.CreateSchemas()
//     ])
//     try await app.autoMigrate()
// }

/// This is for debugging purposes until we add this to Bazaar.
struct Setup {
    static func main() async throws {
        print("TBD")
        // let app = try await Vapor.Application.make()
        // try await configureDatabase(app: app)
    }
}
