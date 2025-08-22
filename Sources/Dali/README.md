# Dali - Data Models Target

Dali is the core data modeling target for the Luxe project, providing Fluent
models and database interactions for
the application.

## Overview

This target contains all the data models, their relationships, and validation logic
for the Luxe legal platform.
It uses Vapor's Fluent ORM for database operations and includes comprehensive JSON
schema validation for structured
data fields.

## Models

### Core Models

- **AssignedNotation**: Tracks assigned notations to entities with their completion
  state and answers

- **Notation**: A collection of documents, questionnaires, and workflows

- **Question**: Individual questions used in notations

- **NotationQuestion**: Pivot table linking notations to questions

- **Entity**: Organizations or legal entities

- **EntityType**: Types of legal entities (LLC, Corporation, etc.)

- **Person**: Individual people in the system

- **User**: User accounts linked to people

- **LegalJurisdiction**: Legal jurisdictions (states, countries, etc.)

- **Letter**: Mail/correspondence tracking

- **Mailbox**: Mailbox management

- **Blob**: File/document storage references

### Model Relationships

```text
User ←→ Person ←→ Entity ←→ EntityType
                      ↓
               AssignedNotation ←→ Notation ←→ NotationQuestion ←→ Question
                                     ↓
                               LegalJurisdiction
```

## JSON Schema Validation

### Automatic Validation

All models with JSON fields include automatic schema validation through Fluent lifecycle hooks:

- **AssignedNotation.changeLanguage**: Validates changelog format with required
  action/timestamp/user_id fields

- **Notation.flow**: Validates question map schema with required BEGIN object

- **Notation.alignment**: Validates question map schema for staff review
  workflows

- **Notation.documentMappings**: Validates PDF coordinate mapping schema

### Supported Schemas

#### Changelog Schema (AssignedNotation.changeLanguage)

```json
{
  "changes": [
    {
      "action": "created|updated|reviewed|approved|rejected|deleted",
      "timestamp": "ISO 8601 string",
      "user_id": "UUID string",
      "notes": "optional string"
    }
  ]
}
```

#### Question Map Schema (flow/alignment)

```json
{
  "BEGIN": {
    "_property": "word|END|ERROR"
  }
}
```

#### Document Mappings Schema

```json
{
  "field_name": {
    "page": 1,
    "upper_right": [x, y],
    "lower_right": [x, y],
    "upper_left": [x, y],
    "lower_left": [x, y]
  }
}
```

### Validation Hooks

Models automatically validate their JSON schemas before create/update
operations:

```swift
// Automatic validation on save/update
notation.flow = Notation.FlowData(rawValue: validFlowJSON)
try await notation.save(on: app.db) // Validates flow schema

// Manual validation
let result = try changeLanguage.validateAgainstSchema()
if !result.isValid {
    print("Validation errors: \(result.errors)")
}
```

## Usage

### Database Configuration

```swift
import Dali

// Configure database in your app
try Dali.configure(app)
```

### Model Operations

```swift
// Create a notation with validation
let notation = Notation(
    uid: "unique-id",
    title: "Example Notation",
    flow: Notation.FlowData(rawValue: validFlowJSON),
    code: "example_notation",
    alignment: Notation.AlignmentData(rawValue: validAlignmentJSON)
)

// Schema validation happens automatically
try await notation.save(on: req.db)
```

### Error Handling

Schema validation errors are thrown as `Abort` errors with descriptive
messages:

```swift
do {
    try await notation.save(on: req.db)
} catch let abort as Abort {
    // Handle validation error
    print("Validation failed: \(abort.reason)")
}
```

## Dependencies

- **Fluent**: ORM and database abstraction

- **FluentPostgresDriver**: PostgreSQL database driver

- **Vapor**: Web framework and HTTP utilities

- **JSONSchema**: JSON schema validation library

## Testing

The Dali target includes comprehensive tests for all models and validation
logic:

```bash
swift test --filter DaliTests
```

## Schema Evolution

When updating JSON schemas:

1. Update the validation logic in the model's `validateAgainstSchema()`
   method
2. Add corresponding tests for the new schema requirements
3. Consider backward compatibility for existing data
4. Update this README with the new schema documentation

## Notes

- All JSON validation currently uses manual implementation for
  compatibility

- Future versions may utilize the full swift-json-schema library features

- Model lifecycle hooks ensure data integrity at the database level

- All timestamps use PostgreSQL's automatic created_at/updated_at
  triggers
