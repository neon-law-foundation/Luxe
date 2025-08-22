import ArgumentParser
import Dali
import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import Yams

enum SeedsError: Error {
    case unsupportedDatabase
    case missingRequiredField(String)
    case invalidYAMLStructure
    case invalidFieldValue(String, String)
}

struct SeedsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "seeds",
        abstract: "Create seeded records from YAML files"
    )

    func run() async throws {
        let logger = Logger(label: "palette-seeds")
        logger.info("Starting seeds command")

        // Create database connection
        let databases = try await createDatabase(logger: logger)
        let database = databases.database(logger: logger, on: MultiThreadedEventLoopGroup.singleton.next())!

        // Process Seeds files in order
        let seedOrder = [
            "Legal__Jurisdictions",
            "Legal__EntityTypes",
            "Directory__People",
            "Directory__Entities",
            "Directory__Addresses",
            "Mail__Mailboxes",
            "Legal__Credentials",
            "Standards__Questions",
        ]

        for seedFile in seedOrder {
            logger.info("Processing seed file: \(seedFile)")
            try await processSeedFile(seedFile, database: database, logger: logger)
        }

        logger.info("Seeds command completed successfully")

        // Important: We cannot call databases.shutdown() in async context
        // The databases will be cleaned up when the process exits
    }

    // This method is used for testing - allows passing in an existing database
    func run(withDatabase database: Database) async throws {
        let logger = Logger(label: "palette-seeds")
        logger.info("Starting seeds command")

        // Process Seeds files in order
        let seedOrder = [
            "Legal__Jurisdictions",
            "Legal__EntityTypes",
            "Directory__People",
            "Directory__Entities",
            "Directory__Addresses",
            "Mail__Mailboxes",
            "Legal__Credentials",
            "Standards__Questions",
        ]

        for seedFile in seedOrder {
            logger.info("Processing seed file: \(seedFile)")
            try await processSeedFile(seedFile, database: database, logger: logger)
        }

        logger.info("Seeds command completed successfully")
    }

    private func createDatabase(logger: Logger) async throws -> Databases {
        var databaseURL =
            ProcessInfo.processInfo.environment["DATABASE_URL"]
            ?? "postgres://postgres@localhost:5432/luxe?sslmode=disable"
        // SQLPostgresConfiguration expects "postgres://" not "postgresql://"
        databaseURL = databaseURL.replacingOccurrences(of: "postgresql://", with: "postgres://")

        logger.info(
            "Connecting to database with URL: \(databaseURL.replacingOccurrences(of: ":[^@]+@", with: ":****@", options: .regularExpression))"
        )

        guard let postgresURL = URL(string: databaseURL) else {
            throw SeedsError.invalidFieldValue("DATABASE_URL", "Invalid database URL")
        }
        var config = try SQLPostgresConfiguration(url: postgresURL)
        config.searchPath = [
            "auth", "directory", "mail", "accounting", "equity", "estates", "standards", "legal", "matters",
            "documents", "service", "admin", "public",
        ]

        let databases = Databases(threadPool: NIOThreadPool.singleton, on: MultiThreadedEventLoopGroup.singleton)
        databases.use(.postgres(configuration: config), as: .psql)

        return databases
    }

    private func processSeedFile(_ seedFile: String, database: Database, logger: Logger) async throws {
        let filePath = URL(fileURLWithPath: "Sources/Palette/Seeds/\(seedFile).yaml")
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            logger.warning("Seed file not found: \(seedFile).yaml")
            return
        }

        logger.info("Reading seed file: \(filePath.path)")
        let yamlData = try Data(contentsOf: filePath)
        let seedData = try Self.parseYAML(from: yamlData)

        // Handle different seed file types
        if seedFile.contains("Question") {
            try await Self.processQuestionRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) question records")
        } else if seedFile.contains("Jurisdiction") {
            try await Self.processLegalJurisdictionRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) legal jurisdiction records")
        } else if seedFile.contains("EntityType") {
            try await Self.processEntityTypeRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) entity type records")
        } else if seedFile.contains("People") {
            try await Self.processPersonRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) person records")
        } else if seedFile.contains("Entities") {
            try await Self.processEntityRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) entity records")
        } else if seedFile.contains("Addresses") {
            try await Self.processAddressRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) address records")
        } else if seedFile.contains("Mailboxes") {
            try await Self.processMailboxRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) mailbox records")
        } else if seedFile.contains("Credential") {
            try await Self.processCredentialRecords(seedData: seedData, database: database)
            logger.info("Successfully processed \(seedData.records.count) credential records")
        } else {
            logger.warning("Unsupported seed file type: \(seedFile)")
        }
    }

    // MARK: - Static Methods for Testing

    static func parseYAML(from data: Data) throws -> SeedData {
        let yaml = try Yams.load(yaml: String(data: data, encoding: .utf8)!)

        guard let yamlDict = yaml as? [String: Any] else {
            throw SeedsError.invalidYAMLStructure
        }

        let lookupFields = yamlDict["lookup_fields"] as? [String] ?? []
        let records = yamlDict["records"] as? [[String: Any]] ?? []

        return SeedData(lookupFields: lookupFields, records: records)
    }

    static func processQuestionRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processQuestionRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    static func processLegalJurisdictionRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processLegalJurisdictionRecord(
                record: record,
                lookupFields: seedData.lookupFields,
                database: database
            )
        }
    }

    static func processPersonRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processPersonRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    static func processCredentialRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processCredentialRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    static func processEntityTypeRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processEntityTypeRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    static func processEntityRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processEntityRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    static func processAddressRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processAddressRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    static func processMailboxRecords(seedData: SeedData, database: Database) async throws {
        for record in seedData.records {
            try await processMailboxRecord(record: record, lookupFields: seedData.lookupFields, database: database)
        }
    }

    private static func processQuestionRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        for field in lookupFields {
            if let value = record[field] as? String {
                switch field {
                case "code":
                    // Check if record exists using Fluent ORM
                    let existingQuestion = try await Question.query(on: database)
                        .filter(\.$code == value)
                        .first()

                    if let question = existingQuestion {
                        existingId = question.id
                    }
                default:
                    break
                }
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateQuestion(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createQuestion(from: record, database: database)
        }
    }

    private static func createQuestion(from record: [String: Any], database: Database) async throws {
        let question = Question()

        if let code = record["code"] as? String {
            question.code = code
        }
        if let prompt = record["prompt"] as? String {
            question.prompt = prompt
        }
        if let helpText = record["help_text"] as? String {
            question.helpText = helpText
        }
        if let questionTypeString = record["question_type"] as? String {
            question.questionType = Question.QuestionType(rawValue: questionTypeString) ?? .string
        }

        // Handle choices field if present
        if let choicesArray = record["choices"] as? [String] {
            question.choices = Question.Choices(choicesArray)
        }
        // If no choices provided, use empty array (default)

        try await question.create(on: database)
    }

    private static func updateQuestion(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing question
        guard let question = try await Question.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "Question not found")
        }

        // Update fields if provided
        if let prompt = record["prompt"] as? String {
            question.prompt = prompt
        }
        if let helpText = record["help_text"] as? String {
            question.helpText = helpText
        }
        if let questionTypeString = record["question_type"] as? String {
            question.questionType = Question.QuestionType(rawValue: questionTypeString) ?? .string
        }

        // Handle choices field if present
        if let choicesArray = record["choices"] as? [String] {
            question.choices = Question.Choices(choicesArray)
        }
        // If no choices provided, use empty array (default)

        try await question.update(on: database)
    }

    private static func processLegalJurisdictionRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        for field in lookupFields {
            if let value = record[field] as? String {
                switch field {
                case "name":
                    // Check if record exists using Fluent ORM
                    let existingJurisdiction = try await LegalJurisdiction.query(on: database)
                        .filter(\.$name == value)
                        .first()

                    if let jurisdiction = existingJurisdiction {
                        existingId = jurisdiction.id
                    }
                case "code":
                    // Check if record exists using Fluent ORM
                    let existingJurisdiction = try await LegalJurisdiction.query(on: database)
                        .filter(\.$code == value)
                        .first()

                    if let jurisdiction = existingJurisdiction {
                        existingId = jurisdiction.id
                    }
                default:
                    break
                }
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateLegalJurisdiction(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createLegalJurisdiction(from: record, database: database)
        }
    }

    private static func createLegalJurisdiction(from record: [String: Any], database: Database) async throws {
        let jurisdiction = LegalJurisdiction()

        if let name = record["name"] as? String {
            jurisdiction.name = name
        }
        if let code = record["code"] as? String {
            jurisdiction.code = code
        }

        try await jurisdiction.create(on: database)
    }

    private static func updateLegalJurisdiction(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing jurisdiction
        guard let jurisdiction = try await LegalJurisdiction.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "LegalJurisdiction not found")
        }

        // Update fields if provided
        if let name = record["name"] as? String {
            jurisdiction.name = name
        }
        if let code = record["code"] as? String {
            jurisdiction.code = code
        }

        try await jurisdiction.update(on: database)
    }

    private static func processPersonRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var lookupQuery = Person.query(on: database)

        for field in lookupFields {
            if let value = record[field] as? String {
                switch field {
                case "email":
                    lookupQuery = lookupQuery.filter(\.$email == value)
                case "name":
                    lookupQuery = lookupQuery.filter(\.$name == value)
                default:
                    break
                }
            }
        }

        // Check if record exists
        let existingPerson = try await lookupQuery.first()

        if let existing = existingPerson {
            // Update existing record
            try await updatePerson(existing, with: record, database: database)
        } else {
            // Create new record
            try await createPerson(from: record, database: database)
        }
    }

    private static func createPerson(from record: [String: Any], database: Database) async throws {
        let person = Person()

        if let name = record["name"] as? String {
            person.name = name
        }

        if let email = record["email"] as? String {
            person.email = email
        }

        try await person.create(on: database)
    }

    private static func updatePerson(_ person: Person, with record: [String: Any], database: Database) async throws {
        if let name = record["name"] as? String {
            person.name = name
        }

        if let email = record["email"] as? String {
            person.email = email
        }

        try await person.update(on: database)
    }

    private static func processCredentialRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        for field in lookupFields {
            if let value = record[field] as? String {
                switch field {
                case "license_number":
                    // Check if record exists using Fluent ORM
                    let existingCredential = try await Credential.query(on: database)
                        .filter(\.$licenseNumber == value)
                        .first()

                    if let credential = existingCredential {
                        existingId = credential.id
                    }
                default:
                    break
                }
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateCredential(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createCredential(from: record, database: database)
        }
    }

    private static func createCredential(from record: [String: Any], database: Database) async throws {
        // Need to resolve foreign key relationships
        // Handle nested structure: directory__person: { email: ... }
        var personEmail: String?
        if let personDict = record["directory__person"] as? [String: Any],
            let email = personDict["email"] as? String
        {
            personEmail = email
        } else if let email = record["person__email"] as? String {
            // Fallback to flat structure for backward compatibility
            personEmail = email
        }

        guard let personEmail = personEmail else {
            throw SeedsError.missingRequiredField("directory__person.email or person__email")
        }

        // Handle nested structure: legal__jurisdiction: { name: ... }
        var jurisdictionName: String?
        if let jurisdictionDict = record["legal__jurisdiction"] as? [String: Any],
            let name = jurisdictionDict["name"] as? String
        {
            jurisdictionName = name
        } else if let name = record["jurisdiction__name"] as? String {
            // Fallback to flat structure for backward compatibility
            jurisdictionName = name
        }

        guard let jurisdictionName = jurisdictionName else {
            throw SeedsError.missingRequiredField("legal__jurisdiction.name or jurisdiction__name")
        }

        guard let licenseNumber = record["license_number"] as? String else {
            throw SeedsError.missingRequiredField("license_number")
        }

        // Find the person
        guard
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
        else {
            throw SeedsError.missingRequiredField("person with email: \(personEmail)")
        }

        // Find the jurisdiction using Fluent ORM
        guard
            let jurisdiction = try await LegalJurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
        else {
            throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
        }

        let credential = Credential(
            personID: person.id!,
            jurisdictionID: jurisdiction.id!,
            licenseNumber: licenseNumber
        )

        try await credential.create(on: database)
    }

    private static func updateCredential(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing credential
        guard let credential = try await Credential.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "Credential not found")
        }

        // Update fields if provided
        if let licenseNumber = record["license_number"] as? String {
            credential.licenseNumber = licenseNumber
        }

        // Note: We don't update foreign key relationships in updates
        // as that would be a significant data change

        try await credential.update(on: database)
    }

    private static func processEntityTypeRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        for field in lookupFields {
            switch field {
            case "name":
                if record["name"] as? String != nil {
                    // For EntityType, we need both name and jurisdiction to uniquely identify
                    // We'll handle the compound lookup below
                    continue
                }
            case "jurisdiction_id", "legal_jurisdiction_id":
                // This will be handled in compound lookup
                continue
            default:
                break
            }
        }

        // Handle compound lookup for name + jurisdiction
        if lookupFields.contains("name")
            && (lookupFields.contains("jurisdiction_id") || lookupFields.contains("legal_jurisdiction_id")),
            let name = record["name"] as? String
        {

            // Get jurisdiction from nested structure
            var jurisdictionName: String?
            if let jurisdictionDict = record["legal__jurisdiction"] as? [String: Any],
                let jName = jurisdictionDict["name"] as? String
            {
                jurisdictionName = jName
            }

            guard let jurisdictionName = jurisdictionName else {
                throw SeedsError.missingRequiredField("legal__jurisdiction.name")
            }

            // Find the jurisdiction first
            guard
                let jurisdiction = try await LegalJurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()
            else {
                throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
            }

            // Check if EntityType exists with this name and jurisdiction
            let existingEntityType = try await EntityType.query(on: database)
                .filter(\.$name == name)
                .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                .first()

            if let entityType = existingEntityType {
                existingId = entityType.id
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateEntityType(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createEntityType(from: record, database: database)
        }
    }

    private static func createEntityType(from record: [String: Any], database: Database) async throws {
        // Get jurisdiction from nested structure
        var jurisdictionName: String?
        if let jurisdictionDict = record["legal__jurisdiction"] as? [String: Any],
            let jName = jurisdictionDict["name"] as? String
        {
            jurisdictionName = jName
        }

        guard let jurisdictionName = jurisdictionName else {
            throw SeedsError.missingRequiredField("legal__jurisdiction.name")
        }

        guard let name = record["name"] as? String else {
            throw SeedsError.missingRequiredField("name")
        }

        // Find the jurisdiction
        guard
            let jurisdiction = try await LegalJurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
        else {
            throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
        }

        let entityType = EntityType(
            legalJurisdictionID: jurisdiction.id!,
            name: name
        )

        try await entityType.create(on: database)
    }

    private static func updateEntityType(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing entity type
        guard let entityType = try await EntityType.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "EntityType not found")
        }

        // Update fields if provided
        if let name = record["name"] as? String {
            entityType.name = name
        }

        // Note: We don't update foreign key relationships in updates
        // as that would be a significant data change

        try await entityType.update(on: database)
    }

    private static func processEntityRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        // Handle compound lookup for name + entity_type_id
        if lookupFields.contains("name") && lookupFields.contains("legal_entity_type_id"),
            let name = record["name"] as? String
        {

            // Get entity type from nested structure
            var entityTypeName: String?
            var jurisdictionName: String?
            if let entityTypeDict = record["legal__entity_type"] as? [String: Any],
                let etName = entityTypeDict["name"] as? String
            {
                entityTypeName = etName

                // Get jurisdiction from nested structure within entity type
                if let jurisdictionDict = entityTypeDict["legal__jurisdiction"] as? [String: Any],
                    let jName = jurisdictionDict["name"] as? String
                {
                    jurisdictionName = jName
                }
            }

            guard let entityTypeName = entityTypeName,
                let jurisdictionName = jurisdictionName
            else {
                throw SeedsError.missingRequiredField("legal__entity_type.name and legal__jurisdiction.name")
            }

            // Find the jurisdiction first
            guard
                let jurisdiction = try await LegalJurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()
            else {
                throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
            }

            // Find the entity type
            guard
                let entityType = try await EntityType.query(on: database)
                    .filter(\.$name == entityTypeName)
                    .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                    .first()
            else {
                throw SeedsError.missingRequiredField(
                    "entity type with name: \(entityTypeName) in jurisdiction: \(jurisdictionName)"
                )
            }

            // Check if Entity exists with this name and entity type
            let existingEntity = try await Entity.query(on: database)
                .filter(\.$name == name)
                .filter(\.$legalEntityType.$id == entityType.id!)
                .first()

            if let entity = existingEntity {
                existingId = entity.id
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateEntity(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createEntity(from: record, database: database)
        }
    }

    private static func createEntity(from record: [String: Any], database: Database) async throws {
        guard let name = record["name"] as? String else {
            throw SeedsError.missingRequiredField("name")
        }

        // Get entity type from nested structure
        var entityTypeName: String?
        var jurisdictionName: String?
        if let entityTypeDict = record["legal__entity_type"] as? [String: Any],
            let etName = entityTypeDict["name"] as? String
        {
            entityTypeName = etName

            // Get jurisdiction from nested structure within entity type
            if let jurisdictionDict = entityTypeDict["legal__jurisdiction"] as? [String: Any],
                let jName = jurisdictionDict["name"] as? String
            {
                jurisdictionName = jName
            }
        }

        guard let entityTypeName = entityTypeName,
            let jurisdictionName = jurisdictionName
        else {
            throw SeedsError.missingRequiredField("legal__entity_type.name and legal__jurisdiction.name")
        }

        // Find the jurisdiction first
        guard
            let jurisdiction = try await LegalJurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
        else {
            throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
        }

        // Find the entity type
        guard
            let entityType = try await EntityType.query(on: database)
                .filter(\.$name == entityTypeName)
                .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                .first()
        else {
            throw SeedsError.missingRequiredField(
                "entity type with name: \(entityTypeName) in jurisdiction: \(jurisdictionName)"
            )
        }

        let entity = Entity(
            name: name,
            legalEntityTypeID: entityType.id!
        )

        try await entity.create(on: database)
    }

    private static func updateEntity(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing entity
        guard let entity = try await Entity.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "Entity not found")
        }

        // Update fields if provided
        if let name = record["name"] as? String {
            entity.name = name
        }

        // Note: We don't update foreign key relationships in updates
        // as that would be a significant data change

        try await entity.update(on: database)
    }

    private static func processAddressRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        // Handle compound lookup for entity_id + zip
        if lookupFields.contains("legal_entity_id") && lookupFields.contains("zip"),
            let zip = record["zip"] as? String
        {
            // Get entity from nested structure
            var entityName: String?
            var entityTypeName: String?
            var jurisdictionName: String?
            if let entityDict = record["legal__entity"] as? [String: Any],
                let eName = entityDict["name"] as? String
            {
                entityName = eName

                // Get entity type from nested structure within entity
                if let entityTypeDict = entityDict["legal__entity_type"] as? [String: Any],
                    let etName = entityTypeDict["name"] as? String
                {
                    entityTypeName = etName

                    // Get jurisdiction from nested structure within entity type
                    if let jurisdictionDict = entityTypeDict["legal__jurisdiction"] as? [String: Any],
                        let jName = jurisdictionDict["name"] as? String
                    {
                        jurisdictionName = jName
                    }
                }
            }

            guard let entityName = entityName,
                let entityTypeName = entityTypeName,
                let jurisdictionName = jurisdictionName
            else {
                throw SeedsError.missingRequiredField("legal__entity.name, entity_type.name and jurisdiction.name")
            }

            // Find the jurisdiction first
            guard
                let jurisdiction = try await LegalJurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()
            else {
                throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
            }

            // Find the entity type
            guard
                let entityType = try await EntityType.query(on: database)
                    .filter(\.$name == entityTypeName)
                    .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                    .first()
            else {
                throw SeedsError.missingRequiredField(
                    "entity type with name: \(entityTypeName) in jurisdiction: \(jurisdictionName)"
                )
            }

            // Find the entity
            guard
                let entity = try await Entity.query(on: database)
                    .filter(\.$name == entityName)
                    .filter(\.$legalEntityType.$id == entityType.id!)
                    .first()
            else {
                throw SeedsError.missingRequiredField(
                    "entity with name: \(entityName) and entity type: \(entityTypeName)"
                )
            }

            // Check if Address exists with this entity and zip
            let existingAddress = try await Address.query(on: database)
                .filter(\.$entity.$id == entity.id!)
                .filter(\.$zip == zip)
                .first()

            if let address = existingAddress {
                existingId = address.id
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateAddress(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createAddress(from: record, database: database)
        }
    }

    private static func createAddress(from record: [String: Any], database: Database) async throws {
        // Get entity from nested structure
        var entityName: String?
        var entityTypeName: String?
        var jurisdictionName: String?
        if let entityDict = record["legal__entity"] as? [String: Any],
            let eName = entityDict["name"] as? String
        {
            entityName = eName

            // Get entity type from nested structure within entity
            if let entityTypeDict = entityDict["legal__entity_type"] as? [String: Any],
                let etName = entityTypeDict["name"] as? String
            {
                entityTypeName = etName

                // Get jurisdiction from nested structure within entity type
                if let jurisdictionDict = entityTypeDict["legal__jurisdiction"] as? [String: Any],
                    let jName = jurisdictionDict["name"] as? String
                {
                    jurisdictionName = jName
                }
            }
        }

        guard let entityName = entityName,
            let entityTypeName = entityTypeName,
            let jurisdictionName = jurisdictionName
        else {
            throw SeedsError.missingRequiredField("legal__entity.name, entity_type.name and jurisdiction.name")
        }

        guard let street = record["street"] as? String,
            let city = record["city"] as? String,
            let country = record["country"] as? String
        else {
            throw SeedsError.missingRequiredField("street, city, and country")
        }

        // Find the jurisdiction first
        guard
            let jurisdiction = try await LegalJurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
        else {
            throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
        }

        // Find the entity type
        guard
            let entityType = try await EntityType.query(on: database)
                .filter(\.$name == entityTypeName)
                .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                .first()
        else {
            throw SeedsError.missingRequiredField(
                "entity type with name: \(entityTypeName) in jurisdiction: \(jurisdictionName)"
            )
        }

        // Find the entity
        guard
            let entity = try await Entity.query(on: database)
                .filter(\.$name == entityName)
                .filter(\.$legalEntityType.$id == entityType.id!)
                .first()
        else {
            throw SeedsError.missingRequiredField(
                "entity with name: \(entityName) and entity type: \(entityTypeName)"
            )
        }

        let address = Address(
            entityID: entity.id!,
            street: street,
            city: city,
            state: record["state"] as? String,
            zip: record["zip"] as? String,
            country: country,
            isVerified: record["is_verified"] as? Bool ?? false
        )

        try await address.create(on: database)
    }

    private static func updateAddress(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing address
        guard let address = try await Address.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "Address not found")
        }

        // Update fields if provided
        if let street = record["street"] as? String {
            address.street = street
        }
        if let city = record["city"] as? String {
            address.city = city
        }
        if let state = record["state"] as? String {
            address.state = state
        }
        if let zip = record["zip"] as? String {
            address.zip = zip
        }
        if let country = record["country"] as? String {
            address.country = country
        }
        if let isVerified = record["is_verified"] as? Bool {
            address.isVerified = isVerified
        }

        try await address.update(on: database)
    }

    private static func processMailboxRecord(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Extract the lookup values to find existing records
        var existingId: UUID?

        // Handle compound lookup for directory_address_id + mailbox_number
        if lookupFields.contains("directory_address_id") && lookupFields.contains("mailbox_number"),
            let mailboxNumber = record["mailbox_number"] as? Int
        {
            // Get address from nested structure
            var addressStreet: String?
            var addressZip: String?
            var entityName: String?
            var entityTypeName: String?
            var jurisdictionName: String?

            if let addressDict = record["directory__address"] as? [String: Any],
                let street = addressDict["street"] as? String,
                let zip = addressDict["zip"] as? String
            {
                addressStreet = street
                addressZip = zip

                // Get entity from nested structure within address
                if let entityDict = addressDict["legal__entity"] as? [String: Any],
                    let eName = entityDict["name"] as? String
                {
                    entityName = eName

                    // Get entity type from nested structure within entity
                    if let entityTypeDict = entityDict["legal__entity_type"] as? [String: Any],
                        let etName = entityTypeDict["name"] as? String
                    {
                        entityTypeName = etName

                        // Get jurisdiction from nested structure within entity type
                        if let jurisdictionDict = entityTypeDict["legal__jurisdiction"] as? [String: Any],
                            let jName = jurisdictionDict["name"] as? String
                        {
                            jurisdictionName = jName
                        }
                    }
                }
            }

            guard let addressStreet = addressStreet,
                let addressZip = addressZip,
                let entityName = entityName,
                let entityTypeName = entityTypeName,
                let jurisdictionName = jurisdictionName
            else {
                throw SeedsError.missingRequiredField("directory__address details with entity information")
            }

            // Find the jurisdiction first
            guard
                let jurisdiction = try await LegalJurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()
            else {
                throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
            }

            // Find the entity type
            guard
                let entityType = try await EntityType.query(on: database)
                    .filter(\.$name == entityTypeName)
                    .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                    .first()
            else {
                throw SeedsError.missingRequiredField(
                    "entity type with name: \(entityTypeName) in jurisdiction: \(jurisdictionName)"
                )
            }

            // Find the entity
            guard
                let entity = try await Entity.query(on: database)
                    .filter(\.$name == entityName)
                    .filter(\.$legalEntityType.$id == entityType.id!)
                    .first()
            else {
                throw SeedsError.missingRequiredField(
                    "entity with name: \(entityName) and entity type: \(entityTypeName)"
                )
            }

            // Find the address
            guard
                let address = try await Address.query(on: database)
                    .filter(\.$entity.$id == entity.id!)
                    .filter(\.$street == addressStreet)
                    .filter(\.$zip == addressZip)
                    .first()
            else {
                throw SeedsError.missingRequiredField(
                    "address with street: \(addressStreet) and zip: \(addressZip) for entity: \(entityName)"
                )
            }

            // Check if Mailbox exists with this address and mailbox number
            let existingMailbox = try await Mailbox.query(on: database)
                .filter(\.$directoryAddressId == address.id!)
                .filter(\.$mailboxNumber == mailboxNumber)
                .first()

            if let mailbox = existingMailbox {
                existingId = mailbox.id
            }
        }

        if let id = existingId {
            // Update existing record
            try await updateMailbox(id: id, with: record, database: database)
        } else {
            // Create new record
            try await createMailbox(from: record, database: database)
        }
    }

    private static func createMailbox(from record: [String: Any], database: Database) async throws {
        guard let mailboxNumber = record["mailbox_number"] as? Int else {
            throw SeedsError.missingRequiredField("mailbox_number")
        }

        // Get address from nested structure
        var addressStreet: String?
        var addressZip: String?
        var entityName: String?
        var entityTypeName: String?
        var jurisdictionName: String?

        if let addressDict = record["directory__address"] as? [String: Any],
            let street = addressDict["street"] as? String,
            let zip = addressDict["zip"] as? String
        {
            addressStreet = street
            addressZip = zip

            // Get entity from nested structure within address
            if let entityDict = addressDict["legal__entity"] as? [String: Any],
                let eName = entityDict["name"] as? String
            {
                entityName = eName

                // Get entity type from nested structure within entity
                if let entityTypeDict = entityDict["legal__entity_type"] as? [String: Any],
                    let etName = entityTypeDict["name"] as? String
                {
                    entityTypeName = etName

                    // Get jurisdiction from nested structure within entity type
                    if let jurisdictionDict = entityTypeDict["legal__jurisdiction"] as? [String: Any],
                        let jName = jurisdictionDict["name"] as? String
                    {
                        jurisdictionName = jName
                    }
                }
            }
        }

        guard let addressStreet = addressStreet,
            let addressZip = addressZip,
            let entityName = entityName,
            let entityTypeName = entityTypeName,
            let jurisdictionName = jurisdictionName
        else {
            throw SeedsError.missingRequiredField("directory__address details with entity information")
        }

        // Find the jurisdiction first
        guard
            let jurisdiction = try await LegalJurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
        else {
            throw SeedsError.missingRequiredField("jurisdiction with name: \(jurisdictionName)")
        }

        // Find the entity type
        guard
            let entityType = try await EntityType.query(on: database)
                .filter(\.$name == entityTypeName)
                .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                .first()
        else {
            throw SeedsError.missingRequiredField(
                "entity type with name: \(entityTypeName) in jurisdiction: \(jurisdictionName)"
            )
        }

        // Find the entity
        guard
            let entity = try await Entity.query(on: database)
                .filter(\.$name == entityName)
                .filter(\.$legalEntityType.$id == entityType.id!)
                .first()
        else {
            throw SeedsError.missingRequiredField(
                "entity with name: \(entityName) and entity type: \(entityTypeName)"
            )
        }

        // Find the address
        guard
            let address = try await Address.query(on: database)
                .filter(\.$entity.$id == entity.id!)
                .filter(\.$street == addressStreet)
                .filter(\.$zip == addressZip)
                .first()
        else {
            throw SeedsError.missingRequiredField(
                "address with street: \(addressStreet) and zip: \(addressZip) for entity: \(entityName)"
            )
        }

        let mailbox = Mailbox(
            directoryAddressId: address.id!,
            mailboxNumber: mailboxNumber,
            isActive: record["is_active"] as? Bool ?? true
        )

        try await mailbox.create(on: database)
    }

    private static func updateMailbox(
        id: UUID,
        with record: [String: Any],
        database: Database
    ) async throws {
        // First, get the existing mailbox
        guard let mailbox = try await Mailbox.find(id, on: database) else {
            throw SeedsError.invalidFieldValue("id", "Mailbox not found")
        }

        // Update fields if provided
        if let mailboxNumber = record["mailbox_number"] as? Int {
            mailbox.mailboxNumber = mailboxNumber
        }
        if let isActive = record["is_active"] as? Bool {
            mailbox.isActive = isActive
        }

        try await mailbox.update(on: database)
    }
}

// MARK: - Supporting Types

struct SeedData {
    let lookupFields: [String]
    let records: [[String: Any]]
}
