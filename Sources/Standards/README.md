# Standards CLI

A Swift command-line tool for validating Sagebrush Standards compliance in markdown files.

## Overview

The Standards CLI validates that markdown files in the Sagebrush ecosystem contain proper YAML frontmatter with
required fields. It recursively searches directories for `.md` files (excluding `README.md` and `CLAUDE.md`) and
validates their structure according to Sagebrush Standards specifications.

## Features

- **Recursive Directory Scanning**: Automatically finds all relevant markdown files
- **YAML Frontmatter Validation**: Ensures proper syntax and required fields
- **Professional Output**: Colored, formatted output with summary statistics
- **CI/CD Ready**: Exit codes and no-color mode for automation
- **Verbose Mode**: Detailed logging for debugging and development

## Required YAML Frontmatter Fields

Every Sagebrush Standard must include these fields in its YAML frontmatter:

- `code`: Unique identifier for the standard (e.g., "CORP001", "IND001")
- `title`: Human-readable title describing the standard
- `respondant_type`: Target audience - "individual", "organization", or "both"

## Optional YAML Frontmatter Fields

Standards may also include:

- `version`: Standard version (e.g., "1.0.0")
- `effective_date`: When the standard takes effect (e.g., "2024-01-01")
- `tags`: Array of categorization tags (e.g., ["legal", "corporate"])

## Usage

### Basic Validation

Validate all standards in the current directory:

```bash
standards validate
```

### Validate Specific Directory

```bash
standards validate ~/sagebrush/standards
```

### Verbose Output

Show detailed output including all processed files:

```bash
standards validate ~/sagebrush/standards --verbose
```

### CI/CD Integration

Disable colored output for scripts and continuous integration:

```bash
standards validate ~/sagebrush/standards --no-color
```

## Example Valid Standard

```markdown
---
code: CORP001
title: "Corporate Formation Standard"
respondant_type: organization
version: "1.0.0"
effective_date: "2024-01-01"
tags: ["corporate", "formation", "legal"]
---

# Corporate Formation Standard

This standard outlines the requirements and procedures for corporate entity formation within the Sagebrush ecosystem.

## Overview

Corporate formation involves creating a legal corporate entity...
```

## Architecture

The Standards CLI is built with a modular architecture:

### Core Components

- **`Standards.swift`**: Main command-line interface using Swift ArgumentParser
- **`StandardsValidator.swift`**: Core validation logic and result aggregation
- **`YAMLValidator.swift`**: YAML frontmatter parsing and validation
- **`FileProcessor.swift`**: Directory traversal and file discovery
- **`OutputFormatter.swift`**: Professional output formatting with colors

### Validation Process

1. **File Discovery**: Recursively scan directory for `.md` files
2. **Content Reading**: Load file contents with proper error handling
3. **Frontmatter Detection**: Check for YAML delimiter presence (`---`)
4. **YAML Parsing**: Validate YAML syntax and structure
5. **Field Validation**: Ensure all required fields are present
6. **Result Aggregation**: Collect validation results and errors
7. **Formatted Output**: Display professional summary with statistics

## Exit Codes

- `0`: All standards are valid
- `1`: One or more standards failed validation

## Development

### Testing

The Standards CLI includes comprehensive test coverage:

```bash
swift test --filter StandardsTests
```

### Building

Build the CLI for development:

```bash
swift build --target Standards
```

### Running

Execute the built CLI:

```bash
.build/debug/Standards validate Examples/Standards/
```

## Integration

The Standards CLI integrates with the broader Sagebrush ecosystem:

- **Web Interface**: Standards are displayed via the Bazaar web application
- **Database Storage**: Validated standards are stored in the Sagebrush database
- **API Access**: Standards are accessible via REST API endpoints
- **Documentation**: Auto-generated documentation from validated standards

## Examples

See the `Examples/Standards/` directory for sample standards that demonstrate proper formatting and structure.

## Support

For questions about Standards CLI usage or Sagebrush Standards specification:

- Documentation: <https://sagebrush.services/standards/spec>
- Examples: <https://sagebrush.services/standards/examples>
- Contact: <standards@sagebrush.services>
