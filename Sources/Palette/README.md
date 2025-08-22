# Palette

Palette is a database migration and seeding tool for the Luxe monorepo. It provides command-line utilities
to manage PostgreSQL database schemas and seed data.

## Commands

### `palette migrate`

Runs pending database migrations in order.

```bash
swift run Palette migrate
```

This command:

- Connects to the PostgreSQL database

- Creates a `migrations` table if it doesn't exist

- Identifies and applies pending migrations from `Sources/Palette/Migrations/`

- Tracks completed migrations to avoid re-running them

### `palette new [MigrationName]`

Creates a new timestamped migration file.

```bash
swift run Palette new CreateUsersTable
```

This command:

- Creates a new SQL file in `Sources/Palette/Migrations/`

- Uses timestamp prefix for ordering: `YYYYMMDDHHMM_migration_name.sql`

- Provides a template for creating idempotent migrations

### `palette seeds`

Processes seed data from YAML files in order.

```bash
swift run Palette seeds
```

This command:

- Reads YAML seed files from `Sources/Palette/Seeds/`

- Processes files in the order: Legal__Jurisdictions, Directory__People, Legal__Credentials, Standards__Questions

- Creates or updates records using lookup fields to find existing data

- Supports LegalJurisdiction, Person, Credential, and Question models

## Seed Files

### Legal__Jurisdictions.yaml

Seeds legal jurisdictions (states, countries) that can be used throughout the system.

```yaml
lookup_fields:
  - name
records:
  - name: Nevada
    code: NV
  - name: California
    code: CA
```

- **Lookup fields**: `name` - finds existing records by jurisdiction name

- **Creates**: LegalJurisdiction records in the `legal.jurisdictions` table

- **Fields**: `name` (display name), `code` (unique identifier)

### Standards__Questions.yaml

Seeds standard questions used in Sagebrush forms and workflows.

```yaml
lookup_fields:
  - code
records:
  - code: personal_name
    prompt: What is your name?
    help_text: Please include your first, middle, and last name.
    question_type: string
```

- **Lookup fields**: `code` - finds existing records by question code

- **Creates**: Question records in the `standards.questions` table

- **Fields**: `code` (unique identifier), `prompt` (question text), `help_text` (guidance), `question_type` (input type)

### Directory__People.yaml

Seeds people who can hold professional credentials.

```yaml
lookup_fields:
  - email
records:
  - name: Nick Shook
    email: nick@neonlaw.com
```

- **Lookup fields**: `email` - finds existing records by email address

- **Creates**: Person records in the `directory.people` table

- **Fields**: `name` (full name), `email` (unique email address)

### Legal__Credentials.yaml

Seeds professional licenses and credentials for people in jurisdictions.

```yaml
lookup_fields:
  - license_number
records:
  - person__email: nick@neonlaw.com
    jurisdiction__name: Nevada
    license_number: "12345"
  - person__email: nick@neonlaw.com
    jurisdiction__name: California
    license_number: "67890"
```

- **Lookup fields**: `license_number` - finds existing records by license number

- **Creates**: Credential records in the `legal.credentials` table

- **Fields**: `person__email` (foreign key to person), `jurisdiction__name` (foreign key to jurisdiction),
  `license_number` (license number)

- **Dependencies**: Requires both Person and LegalJurisdiction records to exist first

## Question Types

The following question types are supported:

- `string` - Single line text input

- `text` - Multi-line text input

- `date` - Date picker

- `datetime` - Date and time picker

- `number` - Numeric input

- `yes_no` - Yes/No toggle

- `radio` - Radio button selection

- `select` - Dropdown selection

- `multi_select` - Multiple selection dropdown

- `secret` - Password or sensitive input

- `signature` - E-signature collection

- `notarization` - Notarization requirement

- `phone` - Phone number with OTP verification

- `email` - Email with OTP verification

- `ssn` - Social Security Number

- `ein` - Employer ID Number

- `file` - File upload

- `person` - Person selection from directory

- `address` - Address input with validation

- `issuance` - Stock issuance reference

- `org` - Organization selection

- `document` - Document reference

- `registered_agent` - Registered agent selection

## Database Configuration

Palette connects to PostgreSQL using these environment variables or defaults:

- **Host**: `localhost`

- **Port**: `5432`

- **Username**: `postgres`

- **Password**: None (trust authentication)

- **Database**: `luxe`

- **SSL**: Disabled for local development

## Usage in Docker

The Bazaar docker image automatically runs migrations and seeds on startup:

```bash
./Palette migrate
./Palette seeds
./Bazaar
```

This ensures the database is always up-to-date before starting the application.

## Development Workflow

1. **Create migration**: `swift run Palette new AddNewTable`
2. **Edit the generated SQL file** with your schema changes
3. **Test locally**: `swift run Palette migrate`
4. **Add seed data**: Edit existing YAML files or create new ones
5. **Test seeds**: `swift run Palette seeds`
6. **Commit changes**: Both migration and seed files should be committed

## Database Schema Organization

Palette uses schema-based organization:

- `auth` - Authentication and user management

- `directory` - People, entities, and relationships

- `legal` - Legal jurisdictions and entity types

- `mail` - Email and communication

- `documents` - Document storage and management

- `standards` - Questions and form templates

- `matters` - Legal matters and cases

- `accounting` - Financial records

- `equity` - Stock and equity management

- `estates` - Estate planning

## Row-Level Security

All tables use row-level security with three roles:

- `customer` - Default role for paid users

- `staff` - Employee role requiring supervision

- `admin` - Full access for lawyers and owners

## Migration Best Practices

1. **Idempotent**: Use `IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, etc.
2. **Atomic**: Group related changes in single migrations
3. **Backward compatible**: Avoid breaking changes when possible
4. **Comments**: Document purpose and constraints with SQL comments
5. **Timestamps**: Include `created_at` and `updated_at` on new tables
6. **UUIDs**: Use UUID primary keys for all new tables

## Testing

Run the test suite to verify migrations and seeding:

```bash
swift test --filter PaletteTests
```

Tests cover:

- YAML parsing and validation

- Database record creation and updates

- Lookup field matching

- Error handling and edge cases
