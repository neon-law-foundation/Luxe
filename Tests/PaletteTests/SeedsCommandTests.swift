import Dali
import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import DaliTests
@testable import Palette

@Suite("Seeds Command Tests", .serialized)
struct SeedsCommandTests {

    @Test("Seeds command should be available as a subcommand")
    func seedsCommandIsAvailable() {
        let paletteConfiguration = Palette.configuration
        let subcommandNames = paletteConfiguration.subcommands.map { $0.configuration.commandName }
        #expect(subcommandNames.contains("seeds"))
    }

    @Test("Seeds command should have correct configuration")
    func seedsCommandConfiguration() {
        let configuration = SeedsCommand.configuration
        #expect(configuration.commandName == "seeds")
        #expect(configuration.abstract == "Create seeded records from YAML files")
    }

    @Test("Seeds command should parse YAML files correctly")
    func seedsCommandParsesYAML() async throws {
        let yamlContent = """
            lookup_fields:
              - code
            records:
              - code: test_question
                prompt: What is your test answer?
                question_type: string
                help_text: This is a test question
            """

        let yamlData = yamlContent.data(using: .utf8)!
        let seedData = try SeedsCommand.parseYAML(from: yamlData)

        #expect(seedData.lookupFields == ["code"])
        #expect(seedData.records.count == 1)

        let record = seedData.records.first!
        #expect(record["code"] as? String == "test_question")
        #expect(record["prompt"] as? String == "What is your test answer?")
        #expect(record["question_type"] as? String == "string")
        #expect(record["help_text"] as? String == "This is a test question")
    }

    @Test("Seeds command should create Question records from YAML")
    func seedsCommandCreatesQuestionRecords() async throws {
        do {
            try await withApp { app in
                let yamlContent = """
                    lookup_fields:
                      - code
                    records:
                      - code: personal_address_test
                        prompt: What is your personal address?
                        question_type: address
                        help_text: Please verify your address.
                      - code: personal_name_test
                        prompt: What is your name?
                        help_text: Please include your first, middle, and last name.
                        question_type: string
                    """

                let yamlData = yamlContent.data(using: .utf8)!
                let seedData = try SeedsCommand.parseYAML(from: yamlData)

                try await SeedsCommand.processQuestionRecords(
                    seedData: seedData,
                    database: app.db
                )

                // Query questions using raw SQL
                guard let postgresDB = app.db as? PostgresDatabase else {
                    throw SeedsError.unsupportedDatabase
                }

                let rows = try await postgresDB.sql()
                    .raw(
                        """
                            SELECT id, prompt, question_type, code, help_text
                            FROM standards.questions
                            WHERE code LIKE '%_test'
                        """
                    )
                    .all()

                #expect(rows.count == 2)

                // Check personal_address_test
                let personalAddressRow = rows.first { row in
                    (try? row.decode(column: "code", as: String.self)) == "personal_address_test"
                }
                #expect(personalAddressRow != nil)
                if let row = personalAddressRow {
                    #expect(try row.decode(column: "prompt", as: String.self) == "What is your personal address?")
                    #expect(try row.decode(column: "question_type", as: String.self) == "address")
                    #expect(try row.decode(column: "help_text", as: String.self) == "Please verify your address.")
                }

                // Check personal_name_test
                let personalNameRow = rows.first { row in
                    (try? row.decode(column: "code", as: String.self)) == "personal_name_test"
                }
                #expect(personalNameRow != nil)
                if let row = personalNameRow {
                    #expect(try row.decode(column: "prompt", as: String.self) == "What is your name?")
                    #expect(try row.decode(column: "question_type", as: String.self) == "string")
                    #expect(
                        try row.decode(column: "help_text", as: String.self)
                            == "Please include your first, middle, and last name."
                    )
                }
            }
        } catch {
            print("DEBUG UPDATE QUESTION ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should update existing Question records")
    func seedsCommandUpdatesExistingQuestionRecords() async throws {
        do {
            try await withApp { app in

                // Create an existing question with unique code
                let uniqueCode =
                    "test_question_" + UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
                let existingQuestion = Question(
                    prompt: "Original prompt",
                    questionType: .string,
                    code: uniqueCode,
                    helpText: "Original help text"
                )
                try await existingQuestion.create(on: app.db)

                // Seed with updated data
                let yamlContent = """
                    lookup_fields:
                      - code
                    records:
                      - code: \(uniqueCode)
                        prompt: Updated prompt
                        question_type: text
                        help_text: Updated help text
                    """

                let yamlData = yamlContent.data(using: .utf8)!
                let seedData = try SeedsCommand.parseYAML(from: yamlData)

                try await SeedsCommand.processQuestionRecords(
                    seedData: seedData,
                    database: app.db
                )

                let updatedQuestion = try await Question.query(on: app.db)
                    .filter(\.$code == uniqueCode)
                    .first()

                #expect(updatedQuestion != nil)
                #expect(updatedQuestion?.id == existingQuestion.id)
                #expect(updatedQuestion?.prompt == "Updated prompt")
                #expect(updatedQuestion?.questionType == .text)
                #expect(updatedQuestion?.helpText == "Updated help text")
                #expect(updatedQuestion?.code == uniqueCode)
            }
        } catch {
            print("DEBUG UPDATE EXISTING QUESTION ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should create LegalJurisdiction records from YAML")
    func seedsCommandCreatesLegalJurisdictionRecords() async throws {
        try await withApp { app in

            let yamlContent = """
                lookup_fields:
                  - name
                records:
                  - name: Nevada
                    code: NV
                  - name: California
                    code: CA
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processLegalJurisdictionRecords(
                seedData: seedData,
                database: app.db
            )

            let jurisdictions = try await LegalJurisdiction.query(on: app.db).all()
            let testJurisdictions = jurisdictions.filter { $0.name == "Nevada" || $0.name == "California" }
            #expect(testJurisdictions.count == 2)

            let nevadaJurisdiction = testJurisdictions.first { $0.name == "Nevada" }
            #expect(nevadaJurisdiction != nil)
            #expect(nevadaJurisdiction?.code == "NV")

            let californiaJurisdiction = testJurisdictions.first { $0.name == "California" }
            #expect(californiaJurisdiction != nil)
            #expect(californiaJurisdiction?.code == "CA")
        }
    }

    @Test("Seeds command should update existing LegalJurisdiction records")
    func seedsCommandUpdatesExistingLegalJurisdictionRecords() async throws {
        do {
            try await withApp { app in

                // Create an existing jurisdiction with unique name and code
                let uniqueCode = "TS_" + UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
                let uniqueName = "Test State \(uniqueCode)"
                let existingJurisdiction = LegalJurisdiction(name: uniqueName, code: uniqueCode)
                try await existingJurisdiction.create(on: app.db)

                // Seed with updated data
                let yamlContent = """
                    lookup_fields:
                      - name
                    records:
                      - name: \(uniqueName)
                        code: \(uniqueCode)_UPD
                    """

                let yamlData = yamlContent.data(using: .utf8)!
                let seedData = try SeedsCommand.parseYAML(from: yamlData)

                try await SeedsCommand.processLegalJurisdictionRecords(
                    seedData: seedData,
                    database: app.db
                )

                let updatedJurisdiction = try await LegalJurisdiction.query(on: app.db)
                    .filter(\.$name == uniqueName)
                    .first()

                #expect(updatedJurisdiction != nil)
                #expect(updatedJurisdiction?.id == existingJurisdiction.id)
                #expect(updatedJurisdiction?.name == uniqueName)
                #expect(updatedJurisdiction?.code == "\(uniqueCode)_UPD")
            }
        } catch {
            print("DEBUG UPDATE LEGAL JURISDICTION ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should process Legal__Jurisdictions.yaml file")
    func seedsCommandProcessesLegalJurisdictionsFile() async throws {
        try await withApp { app in

            let yamlContent = """
                lookup_fields:
                  - name
                records:
                  - name: Nevada
                    code: NV
                  - name: California
                    code: CA
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processLegalJurisdictionRecords(
                seedData: seedData,
                database: app.db
            )

            let jurisdictions = try await LegalJurisdiction.query(on: app.db).all()
            let nevadaJurisdiction = jurisdictions.first { $0.name == "Nevada" }
            #expect(nevadaJurisdiction != nil)
            #expect(nevadaJurisdiction?.code == "NV")
        }
    }

    @Test("Seeds command should handle Standards__Questions.yaml file")
    func seedsCommandHandlesStandardsQuestionsFile() async throws {
        do {
            try await withApp { app in

                let seedsCommand = SeedsCommand()
                try await seedsCommand.run(withDatabase: app.db)

                let questions = try await Question.query(on: app.db).all()
                #expect(questions.count > 0)

                // Verify specific questions from the YAML file
                let personalAddressQuestion = questions.first { $0.code == "personal_address" }
                #expect(personalAddressQuestion != nil)
                #expect(personalAddressQuestion?.prompt == "What is your personal address?")
                #expect(personalAddressQuestion?.questionType == .address)

                let personalNameQuestion = questions.first { $0.code == "personal_name" }
                #expect(personalNameQuestion != nil)
                #expect(personalNameQuestion?.prompt == "What is your name?")
                #expect(personalNameQuestion?.questionType == .string)
            }
        } catch {
            print("DEBUG STANDARDS QUESTIONS FILE ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should process jurisdictions before questions")
    func seedsCommandProcessesJurisdictionsBeforeQuestions() async throws {
        try await withApp { app in

            let seedsCommand = SeedsCommand()
            try await seedsCommand.run(withDatabase: app.db)

            // Verify both jurisdictions and questions were created
            let jurisdictions = try await LegalJurisdiction.query(on: app.db).all()
            let questions = try await Question.query(on: app.db).all()

            #expect(jurisdictions.count > 0)
            #expect(questions.count > 0)

            // Verify specific records from both YAML files
            let nevadaJurisdiction = jurisdictions.first { $0.name == "Nevada" }
            #expect(nevadaJurisdiction != nil)

            let personalAddressQuestion = questions.first { $0.code == "personal_address" }
            #expect(personalAddressQuestion != nil)
        }
    }

    @Test("Seeds command should create Person records from YAML")
    func seedsCommandCreatesPersonRecords() async throws {
        try await withApp { app in

            let yamlContent = """
                lookup_fields:
                  - email
                records:
                  - name: Test Person
                    email: test.person@example.com
                  - name: Another Person
                    email: another.person@example.com
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processPersonRecords(
                seedData: seedData,
                database: app.db
            )

            let people = try await Person.query(on: app.db).all()
            let testPeople = people.filter {
                $0.email == "test.person@example.com" || $0.email == "another.person@example.com"
            }
            #expect(testPeople.count == 2)

            let testPerson = testPeople.first { $0.email == "test.person@example.com" }
            #expect(testPerson != nil)
            #expect(testPerson?.name == "Test Person")

            let anotherPerson = testPeople.first { $0.email == "another.person@example.com" }
            #expect(anotherPerson != nil)
            #expect(anotherPerson?.name == "Another Person")
        }
    }

    @Test("Seeds command should update existing Person records")
    func seedsCommandUpdatesExistingPersonRecords() async throws {
        try await withApp { app in

            // Create an existing person with unique email
            let uniqueEmail =
                "test.update\(UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8))@example.com"
            let existingPerson = Person(name: "Original Name", email: uniqueEmail)
            try await existingPerson.create(on: app.db)

            // Seed with updated data
            let yamlContent = """
                lookup_fields:
                  - email
                records:
                  - name: Updated Name
                    email: \(uniqueEmail)
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processPersonRecords(
                seedData: seedData,
                database: app.db
            )

            let updatedPerson = try await Person.query(on: app.db)
                .filter(\.$email == uniqueEmail)
                .first()

            #expect(updatedPerson != nil)
            #expect(updatedPerson?.id == existingPerson.id)
            #expect(updatedPerson?.name == "Updated Name")
            #expect(updatedPerson?.email == uniqueEmail)
        }
    }

    @Test("Seeds command should create Credential records from YAML")
    func seedsCommandCreatesCredentialRecords() async throws {
        do {
            try await withApp { app in

                // Create test person and jurisdiction first with unique identifiers
                let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
                let uniqueEmail = "test.lawyer.\(uniqueId)@example.com"
                let person = Person(name: "Test Lawyer", email: uniqueEmail)
                try await person.create(on: app.db)

                let uniqueJurisdictionCode =
                    "TS_" + UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
                let uniqueJurisdictionName = "Test State \(uniqueJurisdictionCode)"
                let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
                try await jurisdiction.create(on: app.db)

                let yamlContent = """
                    lookup_fields:
                      - license_number
                    records:
                      - person__email: \(uniqueEmail)
                        jurisdiction__name: \(uniqueJurisdictionName)
                        license_number: "LIC123_\(UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8))"
                      - person__email: \(uniqueEmail)
                        jurisdiction__name: \(uniqueJurisdictionName)
                        license_number: "LIC456_\(UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8))"
                    """

                let yamlData = yamlContent.data(using: .utf8)!
                let seedData = try SeedsCommand.parseYAML(from: yamlData)

                try await SeedsCommand.processCredentialRecords(
                    seedData: seedData,
                    database: app.db
                )

                let credentials = try await Credential.query(on: app.db)
                    .with(\.$person)
                    .with(\.$jurisdiction)
                    .all()

                let testCredentials = credentials.filter { $0.person.email == uniqueEmail }
                #expect(testCredentials.count == 2)

                let licenseNumbers = Set(testCredentials.map { $0.licenseNumber })
                #expect(licenseNumbers.count == 2)
                #expect(licenseNumbers.allSatisfy { $0.hasPrefix("LIC") })
            }
        } catch {
            print("DEBUG CREATE CREDENTIAL ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should create EntityType records from YAML")
    func seedsCommandCreatesEntityTypeRecords() async throws {
        try await withApp { app in
            do {
                // Create test jurisdiction first
                let uniqueJurisdictionCode =
                    "TS_" + UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
                let uniqueJurisdictionName = "Test State \(uniqueJurisdictionCode)"
                let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
                try await jurisdiction.create(on: app.db)

                let yamlContent = """
                    lookup_fields:
                      - name
                      - jurisdiction_id
                    records:
                      - name: C-Corp
                        legal__jurisdiction:
                          name: \(uniqueJurisdictionName)
                      - name: Non-Profit
                        legal__jurisdiction:
                          name: \(uniqueJurisdictionName)
                    """

                let yamlData = yamlContent.data(using: .utf8)!
                let seedData = try SeedsCommand.parseYAML(from: yamlData)

                try await SeedsCommand.processEntityTypeRecords(
                    seedData: seedData,
                    database: app.db
                )

                let entityTypes = try await EntityType.query(on: app.db)
                    .with(\.$legalJurisdiction)
                    .all()

                let testEntityTypes = entityTypes.filter { $0.legalJurisdiction.name == uniqueJurisdictionName }
                #expect(testEntityTypes.count == 2)

                let entityTypeNames = Set(testEntityTypes.map { $0.name })
                #expect(entityTypeNames.contains("C-Corp"))
                #expect(entityTypeNames.contains("Non-Profit"))
            } catch {
                print("DEBUG CREATE ENTITY TYPE ERROR: \(String(reflecting: error))")
                throw error
            }
        }
    }

    @Test("Seeds command should update existing EntityType records")
    func seedsCommandUpdatesExistingEntityTypeRecords() async throws {
        try await withApp { app in

            // Create jurisdiction and existing entity type
            let uniqueJurisdictionCode = "TS_" + UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueJurisdictionCode)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let existingEntityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Non-Profit"
            )
            try await existingEntityType.create(on: app.db)

            // Seed with updated data (using same name and jurisdiction as lookup)
            let yamlContent = """
                lookup_fields:
                  - name
                  - jurisdiction_id
                records:
                  - name: Non-Profit
                    legal__jurisdiction:
                      name: \(uniqueJurisdictionName)
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processEntityTypeRecords(
                seedData: seedData,
                database: app.db
            )

            let updatedEntityType = try await EntityType.query(on: app.db)
                .filter(\.$name == "Non-Profit")
                .with(\.$legalJurisdiction)
                .filter(\.$legalJurisdiction.$id == jurisdiction.id!)
                .first()

            #expect(updatedEntityType != nil)
            #expect(updatedEntityType?.id == existingEntityType.id)
            #expect(updatedEntityType?.name == "Non-Profit")
        }
    }

    @Test("Seeds command should process Legal__EntityTypes.yaml file")
    func seedsCommandProcessesLegalEntityTypesFile() async throws {
        do {
            try await withApp { app in

                // Ensure required jurisdictions exist (create only if they don't exist)
                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Nevada").first() == nil {
                    let nevada = LegalJurisdiction(name: "Nevada", code: "NV")
                    try await nevada.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Delaware").first() == nil {
                    let delaware = LegalJurisdiction(name: "Delaware", code: "DE")
                    try await delaware.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "California").first() == nil {
                    let california = LegalJurisdiction(name: "California", code: "CA")
                    try await california.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Washington").first() == nil {
                    let washington = LegalJurisdiction(name: "Washington", code: "WA")
                    try await washington.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Germany").first() == nil {
                    let germany = LegalJurisdiction(name: "Germany", code: "DE")
                    try await germany.create(on: app.db)
                }

                let seedsCommand = SeedsCommand()
                try await seedsCommand.run(withDatabase: app.db)

                let entityTypes = try await EntityType.query(on: app.db)
                    .with(\.$legalJurisdiction)
                    .all()

                // Verify some expected entity types from the YAML
                let nevadaLLC = entityTypes.first {
                    $0.name == "Single Member LLC" && $0.legalJurisdiction.name == "Nevada"
                }
                #expect(nevadaLLC != nil)

                let delawareCCorp = entityTypes.first {
                    $0.name == "C-Corp" && $0.legalJurisdiction.name == "Delaware"
                }
                #expect(delawareCCorp != nil)
            }
        } catch {
            print("DEBUG LEGAL ENTITY TYPES FILE ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should create Entity records from YAML")
    func seedsCommandCreatesEntityRecords() async throws {
        try await withApp { app in

            // Create test jurisdiction and entity type first
            let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueId)"
            let uniqueJurisdictionCode = "TS\(uniqueId)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let entityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Multi Member LLC"
            )
            try await entityType.create(on: app.db)

            let yamlContent = """
                lookup_fields:
                  - name
                  - legal_entity_type_id
                records:
                  - name: Test Company \(uniqueId)
                    legal__entity_type:
                      name: Multi Member LLC
                      legal__jurisdiction:
                        name: \(uniqueJurisdictionName)
                  - name: Another Company \(uniqueId)
                    legal__entity_type:
                      name: Multi Member LLC
                      legal__jurisdiction:
                        name: \(uniqueJurisdictionName)
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processEntityRecords(
                seedData: seedData,
                database: app.db
            )

            let entities = try await Entity.query(on: app.db)
                .with(\.$legalEntityType)
                .all()

            let testEntities = entities.filter {
                $0.name == "Test Company \(uniqueId)" || $0.name == "Another Company \(uniqueId)"
            }
            #expect(testEntities.count == 2)

            let testCompany = testEntities.first { $0.name == "Test Company \(uniqueId)" }
            #expect(testCompany != nil)
            #expect(testCompany?.legalEntityType.name == "Multi Member LLC")

            let anotherCompany = testEntities.first { $0.name == "Another Company \(uniqueId)" }
            #expect(anotherCompany != nil)
            #expect(anotherCompany?.legalEntityType.name == "Multi Member LLC")
        }
    }

    @Test("Seeds command should update existing Entity records")
    func seedsCommandUpdatesExistingEntityRecords() async throws {
        try await withApp { app in

            // Create jurisdiction and entity type
            let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueId)"
            let uniqueJurisdictionCode = "TS\(uniqueId)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let entityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Multi Member LLC"
            )
            try await entityType.create(on: app.db)

            // Create existing entity
            let existingEntity = Entity(
                name: "Original Name \(uniqueId)",
                legalEntityTypeID: entityType.id!
            )
            try await existingEntity.create(on: app.db)

            // Seed with updated data
            let yamlContent = """
                lookup_fields:
                  - name
                  - legal_entity_type_id
                records:
                  - name: Original Name \(uniqueId)
                    legal__entity_type:
                      name: Multi Member LLC
                      legal__jurisdiction:
                        name: \(uniqueJurisdictionName)
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processEntityRecords(
                seedData: seedData,
                database: app.db
            )

            let updatedEntity = try await Entity.query(on: app.db)
                .filter(\.$name == "Original Name \(uniqueId)")
                .with(\.$legalEntityType)
                .first()

            #expect(updatedEntity != nil)
            #expect(updatedEntity?.id == existingEntity.id)
            #expect(updatedEntity?.name == "Original Name \(uniqueId)")
        }
    }

    @Test("Seeds command should process Directory__Entities.yaml file")
    func seedsCommandProcessesDirectoryEntitiesFile() async throws {
        do {
            try await withApp { app in

                // Ensure required jurisdictions exist (create only if they don't exist)
                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Nevada").first() == nil {
                    let nevada = LegalJurisdiction(name: "Nevada", code: "NV")
                    try await nevada.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Delaware").first() == nil {
                    let delaware = LegalJurisdiction(name: "Delaware", code: "DE")
                    try await delaware.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "California").first() == nil {
                    let california = LegalJurisdiction(name: "California", code: "CA")
                    try await california.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Germany").first() == nil {
                    let germany = LegalJurisdiction(name: "Germany", code: "DE")
                    try await germany.create(on: app.db)
                }

                if try await LegalJurisdiction.query(on: app.db).filter(\.$name == "Washington").first() == nil {
                    let washington = LegalJurisdiction(name: "Washington", code: "WA")
                    try await washington.create(on: app.db)
                }

                let seedsCommand = SeedsCommand()
                try await seedsCommand.run(withDatabase: app.db)

                let entities = try await Entity.query(on: app.db)
                    .with(\.$legalEntityType)
                    .all()

                // Verify some expected entities from the YAML
                let neonLaw = entities.first { $0.name == "Neon Law" }
                #expect(neonLaw != nil)

                let nicholasShook = entities.first { $0.name == "Nicholas Shook" }
                #expect(nicholasShook != nil)

                let widdix = entities.first { $0.name == "Widdix" }
                #expect(widdix != nil)
            }
        } catch {
            print("DEBUG DIRECTORY ENTITIES FILE ERROR: \(String(reflecting: error))")
            throw error
        }
    }

    @Test("Seeds command should create Address records from YAML")
    func seedsCommandCreatesAddressRecords() async throws {
        try await withApp { app in

            // Create test jurisdiction, entity type, and entity first
            let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueId)"
            let uniqueJurisdictionCode = "TS\(uniqueId)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let entityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Multi Member LLC"
            )
            try await entityType.create(on: app.db)

            let entity = Entity(
                name: "Test Company \(uniqueId)",
                legalEntityTypeID: entityType.id!
            )
            try await entity.create(on: app.db)

            let yamlContent = """
                lookup_fields:
                  - legal_entity_id
                  - zip
                records:
                  - legal__entity:
                      name: Test Company \(uniqueId)
                      legal__entity_type:
                        name: Multi Member LLC
                        legal__jurisdiction:
                          name: \(uniqueJurisdictionName)
                    street: 123 Test Street
                    city: Test City
                    state: TS
                    country: USA
                    zip: "12345"
                    is_verified: true
                  - legal__entity:
                      name: Test Company \(uniqueId)
                      legal__entity_type:
                        name: Multi Member LLC
                        legal__jurisdiction:
                          name: \(uniqueJurisdictionName)
                    street: 456 Another Street
                    city: Another City
                    state: TS
                    country: USA
                    zip: "67890"
                    is_verified: false
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processAddressRecords(
                seedData: seedData,
                database: app.db
            )

            let addresses = try await Address.query(on: app.db)
                .with(\.$entity)
                .all()

            let testAddresses = addresses.filter { $0.entity?.name == "Test Company \(uniqueId)" }
            #expect(testAddresses.count == 2)

            let firstAddress = testAddresses.first { $0.zip == "12345" }
            #expect(firstAddress != nil)
            #expect(firstAddress?.street == "123 Test Street")
            #expect(firstAddress?.city == "Test City")
            #expect(firstAddress?.state == "TS")
            #expect(firstAddress?.country == "USA")
            #expect(firstAddress?.isVerified == true)

            let secondAddress = testAddresses.first { $0.zip == "67890" }
            #expect(secondAddress != nil)
            #expect(secondAddress?.street == "456 Another Street")
            #expect(secondAddress?.city == "Another City")
            #expect(secondAddress?.isVerified == false)
        }
    }

    @Test("Seeds command should update existing Address records")
    func seedsCommandUpdatesExistingAddressRecords() async throws {
        try await withApp { app in

            // Create jurisdiction, entity type, and entity
            let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueId)"
            let uniqueJurisdictionCode = "TS\(uniqueId)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let entityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Multi Member LLC"
            )
            try await entityType.create(on: app.db)

            let entity = Entity(
                name: "Test Company \(uniqueId)",
                legalEntityTypeID: entityType.id!
            )
            try await entity.create(on: app.db)

            // Create existing address
            let existingAddress = Address(
                entityID: entity.id!,
                street: "Original Street",
                city: "Original City",
                state: "OS",
                zip: "12345",
                country: "USA",
                isVerified: false
            )
            try await existingAddress.create(on: app.db)

            // Seed with updated data
            let yamlContent = """
                lookup_fields:
                  - legal_entity_id
                  - zip
                records:
                  - legal__entity:
                      name: Test Company \(uniqueId)
                      legal__entity_type:
                        name: Multi Member LLC
                        legal__jurisdiction:
                          name: \(uniqueJurisdictionName)
                    street: Updated Street
                    city: Updated City
                    state: US
                    country: USA
                    zip: "12345"
                    is_verified: true
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processAddressRecords(
                seedData: seedData,
                database: app.db
            )

            let updatedAddress = try await Address.query(on: app.db)
                .filter(\.$entity.$id == entity.id!)
                .filter(\.$zip == "12345")
                .first()

            #expect(updatedAddress != nil)
            #expect(updatedAddress?.id == existingAddress.id)
            #expect(updatedAddress?.street == "Updated Street")
            #expect(updatedAddress?.city == "Updated City")
            #expect(updatedAddress?.state == "US")
            #expect(updatedAddress?.isVerified == true)
        }
    }

    @Test("Seeds command should create Mailbox records from YAML")
    func seedsCommandCreatesMailboxRecords() async throws {
        try await withApp { app in

            // Create test jurisdiction, entity type, entity, and address first
            let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueId)"
            let uniqueJurisdictionCode = "TS\(uniqueId)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let entityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Multi Member LLC"
            )
            try await entityType.create(on: app.db)

            let entity = Entity(
                name: "Test Company \(uniqueId)",
                legalEntityTypeID: entityType.id!
            )
            try await entity.create(on: app.db)

            let address = Address(
                entityID: entity.id!,
                street: "123 Test Street",
                city: "Test City",
                state: "TS",
                zip: "12345",
                country: "USA",
                isVerified: true
            )
            try await address.create(on: app.db)

            let yamlContent = """
                lookup_fields:
                  - directory_address_id
                  - mailbox_number
                records:
                  - directory__address:
                      legal__entity:
                        name: Test Company \(uniqueId)
                        legal__entity_type:
                          name: Multi Member LLC
                          legal__jurisdiction:
                            name: \(uniqueJurisdictionName)
                      street: 123 Test Street
                      city: Test City
                      state: TS
                      country: USA
                      zip: "12345"
                      is_verified: true
                    mailbox_number: 100
                    is_active: true
                  - directory__address:
                      legal__entity:
                        name: Test Company \(uniqueId)
                        legal__entity_type:
                          name: Multi Member LLC
                          legal__jurisdiction:
                            name: \(uniqueJurisdictionName)
                      street: 123 Test Street
                      city: Test City
                      state: TS
                      country: USA
                      zip: "12345"
                      is_verified: true
                    mailbox_number: 200
                    is_active: false
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processMailboxRecords(
                seedData: seedData,
                database: app.db
            )

            let mailboxes = try await Mailbox.query(on: app.db)
                .filter(\.$directoryAddressId == address.id!)
                .all()

            #expect(mailboxes.count == 2)

            let mailbox100 = mailboxes.first { $0.mailboxNumber == 100 }
            #expect(mailbox100 != nil)
            #expect(mailbox100?.isActive == true)

            let mailbox200 = mailboxes.first { $0.mailboxNumber == 200 }
            #expect(mailbox200 != nil)
            #expect(mailbox200?.isActive == false)
        }
    }

    @Test("Seeds command should update existing Mailbox records")
    func seedsCommandUpdatesExistingMailboxRecords() async throws {
        try await withApp { app in

            // Create jurisdiction, entity type, entity, and address
            let uniqueId = UUID().uuidString.data(using: .utf8)!.base64EncodedString().prefix(8)
            let uniqueJurisdictionName = "Test State \(uniqueId)"
            let uniqueJurisdictionCode = "TS\(uniqueId)"
            let jurisdiction = LegalJurisdiction(name: uniqueJurisdictionName, code: uniqueJurisdictionCode)
            try await jurisdiction.create(on: app.db)

            let entityType = EntityType(
                legalJurisdictionID: jurisdiction.id!,
                name: "Multi Member LLC"
            )
            try await entityType.create(on: app.db)

            let entity = Entity(
                name: "Test Company \(uniqueId)",
                legalEntityTypeID: entityType.id!
            )
            try await entity.create(on: app.db)

            let address = Address(
                entityID: entity.id!,
                street: "123 Test Street",
                city: "Test City",
                state: "TS",
                zip: "12345",
                country: "USA",
                isVerified: true
            )
            try await address.create(on: app.db)

            // Create existing mailbox
            let existingMailbox = Mailbox(
                directoryAddressId: address.id!,
                mailboxNumber: 100,
                isActive: false
            )
            try await existingMailbox.create(on: app.db)

            // Seed with updated data
            let yamlContent = """
                lookup_fields:
                  - directory_address_id
                  - mailbox_number
                records:
                  - directory__address:
                      legal__entity:
                        name: Test Company \(uniqueId)
                        legal__entity_type:
                          name: Multi Member LLC
                          legal__jurisdiction:
                            name: \(uniqueJurisdictionName)
                      street: 123 Test Street
                      city: Test City
                      state: TS
                      country: USA
                      zip: "12345"
                      is_verified: true
                    mailbox_number: 100
                    is_active: true
                """

            let yamlData = yamlContent.data(using: .utf8)!
            let seedData = try SeedsCommand.parseYAML(from: yamlData)

            try await SeedsCommand.processMailboxRecords(
                seedData: seedData,
                database: app.db
            )

            let updatedMailbox = try await Mailbox.query(on: app.db)
                .filter(\.$directoryAddressId == address.id!)
                .filter(\.$mailboxNumber == 100)
                .first()

            #expect(updatedMailbox != nil)
            #expect(updatedMailbox?.id == existingMailbox.id)
            #expect(updatedMailbox?.isActive == true)
        }
    }

}

// MARK: - Test Utilities

// Helper function to create and properly shutdown Application
private func withApp<T: Sendable>(_ closure: @Sendable @escaping (Application) async throws -> T) async throws -> T {
    try await TestUtilities.withApp { app, db in
        try await closure(app)
    }
}
