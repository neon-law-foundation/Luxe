# MiseEnPlace

MiseEnPlace is a Swift CLI tool for creating standardized private GitHub repositories for legal matter work
at Neon Law.
The name comes from the French culinary term meaning "everything in its place," reflecting the tool's
purpose of setting up
repositories with proper structure, documentation standards, and configuration for attorney-client work.

## Purpose

MiseEnPlace automates the creation of private GitHub repositories that include comprehensive legal
documentation standards,
contract style guides, and professional development guidelines. Each repository serves as a complete
workspace for legal
matter documentation, contracts, employee handbooks, and related materials.

## Repository Creation Process

### Prerequisites

- Valid GitHub personal access token with repository creation permissions

- Access to the `neon-law` GitHub organization

- Swift Package Manager and build environment

### Usage

```bash
swift run MiseEnPlace <matter-project-codename>
```

### Matter Project Code Name Guidelines

Repository names should align with DALI project codenames following the established pattern:

**Format**: `{PURPOSE}-{CLASSIFICATION}-{IDENTIFIER}`

**Examples**:

- `PROJECT-ALPHA-CLIENT` - Alpha classification client project

- `MATTER-DISCLOSURE-2024` - Disclosure matter for 2024

- `PROJECT-BETA-EMPLOYMENT` - Beta classification employment law project

- `CONTRACT-GAMMA-ACQUISITION` - Gamma classification acquisition contract work

**Pattern Rules**:

- Use uppercase letters and hyphens as separators

- Include descriptive purpose (PROJECT, MATTER, CONTRACT)

- Add classification codes (ALPHA, BETA, GAMMA, DELTA) for project types

- Include functional descriptors (DISCLOSURE, EMPLOYMENT, ACQUISITION)

- Add year or unique identifiers for temporal organization

### What Gets Created

Each new repository includes:

#### Core Configuration

- **Private repository** in `neon-law` organization

- **Branch protection** on main branch requiring pull request reviews

- **Code ownership** rules with automatic reviewer assignment

- **CI/CD workflows** for continuous integration and deployment

#### Documentation Standards

- **Contract style guide** (`contract_style_guide.md`) - Comprehensive writing and formatting standards

- **Project guidelines** (`CLAUDE.md`) - Development instructions and coding standards

- **Generated README** with matter-specific documentation structure

- **Git configuration** (`.gitignore`) optimized for Swift and legal document workflows

#### Repository Structure

```text
/
├── .github/
│   ├── CODEOWNERS          # Automatic code review assignments
│   └── workflows/
│       ├── ci.yaml         # Continuous integration pipeline
│       └── cd.yaml         # Continuous deployment pipeline
├── contracts/              # Legal agreements and contract templates
├── handbooks/              # Employee handbook materials and policy documents
├── documentation/          # Supporting legal documentation and research materials
├── templates/              # Reusable contract and document templates
├── contract_style_guide.md # Legal writing and formatting standards
├── CLAUDE.md              # Project development guidelines
├── README.md              # Repository documentation with matter-specific details
└── .gitignore            # Git ignore patterns for legal workflows
```

## Documentation Standards Integration

All created repositories enforce the contract style guide standards:

### Writing Requirements

- **120-character line limit** with optimal space utilization

- **Active voice** with legal precision and clarity

- **Inclusive language** professional terminology for all people

- **Harvard outline style** with hierarchical headings and consistent numbering

### Content Guidelines

- **Transparency and accessibility** with complete policy openness

- **Comprehensive coverage** addressing full lifecycle support

- **Employee-first policies** with generous benefits and work-life balance

- **Professional development** with structured advancement frameworks

### Legal Formatting

- **Precise terminology** with defined technical terms

- **Consistent formatting** maintaining professional legal standards

- **Logical section numbering** with accurate cross-references

- **Professional documentation** demonstrating legal writing excellence

## Security and Governance

### Repository Security

- All repositories created as **private** for attorney-client privilege protection

- **Issues and Projects disabled** by default to maintain confidentiality

- **Branch protection** enforced requiring code review before merging changes

- **Code ownership** automatically assigned to `@aire-neon` and `@shicholas`

### Access Control

- Repository access follows organizational security policies

- Code review requirements ensure quality control and compliance

- Private repository status maintains client confidentiality requirements

## Error Handling

MiseEnPlace includes comprehensive error handling for common scenarios:

- **Repository name validation** ensuring compliance with naming standards

- **GitHub API failures** with informative error messages and retry suggestions

- **File copying errors** with graceful handling of missing template files

- **Branch protection failures** with warnings but continued repository creation

## Integration with DALI System

MiseEnPlace integrates with the DALI project management system:

- **Project codenames** align with DALI `matters.projects` table structure

- **Naming conventions** follow established patterns for matter organization

- **Repository structure** supports legal workflow management and notation assignments

- **Documentation standards** ensure consistency across all matter projects

## Examples

### Creating a Client Matter Repository

```bash
swift run MiseEnPlace PROJECT-ALPHA-SMITHCORP
```

### Creating a Contract Templates Repository

```bash
swift run MiseEnPlace CONTRACT-BETA-EMPLOYMENT
```

### Creating a Disclosure Matter Repository

```bash
swift run MiseEnPlace MATTER-DISCLOSURE-2024Q1
```

## Development

MiseEnPlace follows test-driven development with comprehensive test coverage for all components:

- **Repository creation** with proper configuration validation

- **Template file copying** with error handling for missing files

- **GitHub API integration** with mock implementations for testing

- **Command-line parsing** with validation of repository name requirements

## Related Documentation

- **Contract Style Guide** - Comprehensive legal writing standards

- **CLAUDE.md** - Project development guidelines and coding standards

- **DALI Documentation** - Project management and matter organization system
