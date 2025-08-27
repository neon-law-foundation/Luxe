# Roulette: Random Code Refactoring Tool - Implementation Research

## Overview

This document analyzes the current codebase patterns and implementation strategies to
inform the design of Roulette, a random code refactoring tool designed to combat
agentic coding effects through targeted quality improvements.

## Current Codebase Analysis

### Scale and Scope

- **Total Swift Files**: 439+ files across multiple targets
- **Primary Targets**: 13 executable targets, 13 test targets
- **Architecture**: Monorepo with full-stack Swift implementation
- **Domain**: Legal services platform with web, CLI, and iOS components

### Implementation Patterns Found

#### 1. CLI Tool Architecture Patterns

From analyzing existing CLI tools (`Wayne`, `Standards`, `Vegas`, `Brochure`,
`Palette`):

**Pattern Analysis Results**:

**Wayne** (Simple command with arguments):

```swift
@main
struct Wayne: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate standalone Xcode projects for macOS/iOS targets from Swift Package Manager",
        discussion: "Detailed multiline description..."
    )
    
    @Argument(help: "The name of the target to generate an Xcode project for")
    var targetName: String?
    
    @Flag(name: .long, help: "List all available macOS/iOS targets")
    var list: Bool = false
    
    @Option(name: .long, help: "Output directory for the generated project")
    var outputDirectory: String?
}
```

**Standards** (Subcommand structure with validation):

```swift
@main
struct Standards: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate Sagebrush Standards compliance in markdown files",
        version: "1.0.0",
        subcommands: [Validate.self]
    )
}

extension Standards {
    struct Validate: ParsableCommand {
        @Argument(help: "Path to directory containing standards files")
        var path: String = "."
        
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false
        
        func run() throws {
            var logger = Logger(label: "standards.validate")
            logger.logLevel = verbose ? .debug : .info
        }
    }
}
```

**Vegas** (Async commands with AWS integration):

```swift
@main
struct Vegas: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "Vegas",
        abstract: "AWS infrastructure management tool",
        subcommands: [Infrastructure.self, Deploy.self, Versions.self, ...]
    )
}
```

**Brochure** (Complex async with extensive configuration):

```swift
@main
struct BrochureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "Brochure",
        abstract: "High-performance CLI tool for deploying static websites to AWS S3 with CloudFront optimization",
        discussion: """
            Extensive documentation with:
            • Feature descriptions with bullet points
            • Usage examples with code blocks
            • Supported options and configurations
            """,
        subcommands: [UploadCommand.self, UploadAllCommand.self, ...]
    )
}
```

**Key Architectural Insights**:

1. **Configuration Patterns**:
   - Simple tools: Direct `ParsableCommand` with inline arguments/flags
   - Complex tools: `AsyncParsableCommand` with subcommands
   - All include comprehensive `discussion` sections with examples
   - Version information in configuration when applicable

2. **Argument Patterns**:
   - `@Argument` for required positional parameters (often optional with
     defaults)
   - `@Option` for named parameters with values
   - `@Flag` for boolean switches (`.shortAndLong` common)
   - Default values provided for optional parameters

3. **Error Handling**:
   - Custom `ExitCode.failure` for validation errors
   - Graceful error messages with helpful context
   - List available options when invalid choices provided

4. **Logging Integration**:
   - `Logger(label: "tool.command")` pattern
   - Conditional log levels based on verbose flags
   - Structured metadata logging with `.string()`, `.stringConvertible()`

5. **Output Patterns**:
   - Emoji indicators for status (✅, ❌, 📱, 📁)
   - Formatted output with clear sections
   - Color support with `isatty()` detection for terminals

#### 2. File Discovery Patterns

**Git Integration** (from various scripts and tools):
- Standard use of `git ls-files` for file discovery
- Common exclusion patterns for generated/build files
- Process-based git command execution with proper error handling

**File Processing** (from `Standards`, `Brochure`):

```swift
// Pattern: FileTraverser for directory scanning
actor FileTraverser {
    func traverse(path: String, fileExtensions: [String]) throws -> [String]
}

// Pattern: Glob matching for file selection
func findFiles(matching pattern: String) -> [String]
```

#### 3. Code Analysis Patterns

**Complexity Metrics** (inferred from test patterns and validation):
- Line counting via `String.components(separatedBy: .newlines)`
- Pattern matching with regular expressions for Swift constructs
- Function/type counting through AST-like string parsing

**Quality Assessment** (from existing validation tools):

```swift
// Pattern: Metric collection
struct CodeMetrics {
    let lineCount: Int
    let functionCount: Int
    let typeCount: Int
    let complexity: Int
}

// Pattern: Suggestion generation
struct QualitySuggestion {
    let type: SuggestionType
    let severity: Severity
    let description: String
}
```

## Target Integration Points

### 1. ArgumentParser Integration

**Existing Pattern** (from `Wayne`, `Standards`, `Vegas`):

```swift
.executableTarget(
    name: "Roulette",
    dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log")
    ]
)
```

### 2. Testing Strategy

**Swift Testing Pattern** (consistent across all targets):

```swift
import Testing

@Suite("Roulette Tests")
struct RouletteTests {
    @Test("Should analyze Swift files")
    func testAnalysis() async throws {
        // Test implementation
    }
}
```

### 3. Error Handling Strategy

**Standard Error Pattern**:

```swift
enum RouletteError: Error, LocalizedError {
    case gitCommandFailed(String)
    case analysisError(String)
    
    var errorDescription: String? {
        // Localized descriptions
    }
}
```

## Swift File Complexity Patterns

### Statistical Analysis of 441 Swift Files

**File Size Distribution**:
- **Small (1-100 lines)**: 126 files (28.6%) - Simple utilities, protocols,
  basic models
- **Medium (101-300 lines)**: 208 files (47.2%) - Standard service classes,
  components
- **Large (301-600 lines)**: 87 files (19.7%) - Complex services, major
  components
- **Very Large (600+ lines)**: 20 files (4.5%) - Monolithic implementations
  needing refactoring

**Top Complexity Outliers** (lines of code):
1. `Sources/Bazaar/App.swift` - 2,693 lines (main application configuration)
2. `Sources/Vegas/VegasCommands.swift` - 1,660 lines (AWS infrastructure
   commands)
3. `Sources/Palette/Commands/SeedsCommand.swift` - 1,306 lines (database
   seeding)
4. `Sources/Brochure/Security/SecurityScanner.swift` - 1,147 lines (security
   validation)
5. `Sources/Brochure/Commands/BootstrapCommand.swift` - 1,086 lines (project
   initialization)

### Complexity Patterns Analysis

#### High Complexity Files (600+ lines, 20 files)

**Characteristics**:
- Monolithic implementations combining multiple concerns
- Heavy use of complex control flow (`if`, `guard`, `switch`, nested conditions)
- Multiple service integrations in single file
- Extensive configuration and initialization logic
- High function density (20+ functions per file)

**Examples**:
- `App.swift`: Vapor application setup, middleware configuration, routing
- Command files: Multiple subcommands with complex argument parsing
- Security scanners: Multi-stage validation with branching logic

#### Medium Complexity Files (101-300 lines, 208 files)

**Characteristics**:
- Focused single responsibility (service classes, models, components)
- Moderate function count (5-15 functions)
- Clean separation of concerns
- Standard patterns: Fluent models, service layers, CLI commands

**Examples**:

```swift
// Typical medium complexity: User model (Dali/User.swift)
public final class User: Model, Content, Authenticatable {
    public static let schema = "users"
    
    @ID(key: .id) public var id: UUID?
    @Field(key: "username") public var username: String
    @Field(key: "role") public var role: String
    
    // 5-8 functions for CRUD, validation, relationships
}
```

#### Low Complexity Files (1-100 lines, 126 files)

**Characteristics**:
- Single purpose utilities and protocols
- Minimal control flow complexity
- Simple data structures and enums
- Extension files with focused functionality

**Examples**:
- Protocol definitions: 10-30 lines
- Enum types with computed properties
- Simple entrypoint files: 5-10 lines
- Utility extensions: focused helper methods

### Function and Type Density Analysis

**Function Patterns**:
- **Low density**: 0-5 functions per file (utility files, simple models)
- **Medium density**: 6-15 functions per file (service classes, controllers)
- **High density**: 16+ functions per file (complex services, command
  processors)

**Type Patterns**:
- **Single type**: 65% of files (focused responsibility)
- **Multiple related types**: 30% of files (enums + implementations, related
  structs)
- **Complex hierarchies**: 5% of files (extensive type families)

### Complexity Indicators for Roulette Analysis

**Critical Refactoring Signals** (High Priority):
1. **Files >600 lines** - Split into focused modules
2. **High cyclomatic complexity** - Nested conditionals >5 levels deep
3. **Multiple responsibilities** - Services handling >3 distinct concerns
4. **Long parameter lists** - Functions with >5 parameters

**Medium Priority Signals**:
1. **Files 300-600 lines** - Consider splitting if multiple concerns
2. **High function density** - >15 functions might indicate complexity
3. **Missing documentation** - Public APIs without DocC comments
4. **Naming inconsistencies** - Non-descriptive variable/function names

**Low Priority Suggestions**:
1. **Files 100-300 lines** - Generally well-scoped, minor optimizations
2. **Simple optimizations** - Reduce redundant code, extract constants
3. **Style consistency** - Align with project formatting standards

### Refactoring Opportunity Categories

**Extract Service Pattern** (20 files identified):
- Large files combining business logic, data access, and presentation
- Recommendation: Split into service layer, model layer, presentation layer

**Extract Function Pattern** (87 files identified):
- Long functions (>50 lines) with multiple responsibilities
- Complex conditional logic that can be extracted into named functions

**Split Type Pattern** (15 files identified):
- Classes/structs handling multiple unrelated responsibilities
- Recommendation: Create focused types following single responsibility
  principle

**Configuration Object Pattern** (45 files identified):
- Functions with long parameter lists
- Recommendation: Group related parameters into configuration structs

## Git Integration Research

### Current Git Usage Patterns

**Process Execution Pattern** (from `BootstrapCommand.swift`):

```swift
private func initializeGit(at path: URL, logger: Logger) async throws {
    let process = Process()
    process.currentDirectoryURL = path
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    
    // Initialize repository
    process.arguments = ["init"]
    try process.run()
    process.waitUntilExit()
    
    guard process.terminationStatus == 0 else {
        throw BootstrapError.gitInitFailed("Failed to initialize repository")
    }
    
    // Add all files
    process.arguments = ["add", "."]
    try process.run()
    process.waitUntilExit()
    
    guard process.terminationStatus == 0 else {
        throw BootstrapError.gitInitFailed("Failed to add files")
    }
}
```

**File Discovery Implementation Strategy**:

```swift
actor GitFileDiscovery {
    private let logger: Logger
    
    func discoverSwiftFiles(excludeTests: Bool = true) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-files", "*.swift"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        logger.info("Executing git ls-files command")
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw RouletteError.gitCommandFailed("git ls-files *.swift")
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return parseAndFilterFiles(output, excludeTests: excludeTests)
    }
}
```

**Exclusion Patterns Identified**:
From `validate-markdown.sh` and build system analysis:
- `.build/` directory (Swift Package Manager build artifacts)
- `node_modules/` (Node.js dependencies)
- `vendor/` (Third-party vendor code)
- `DerivedData/` (Xcode build artifacts)
- `*.generated.swift` (code generation outputs)
- `*Tests.swift` files (when excluding tests)
- `/Tests/` directories (test suites)

**Error Handling Patterns**:
1. **Process termination validation**: Check `process.terminationStatus == 0`
2. **Custom error types**: Domain-specific errors with descriptive messages
3. **Logging integration**: Structured logging with metadata
4. **Resource cleanup**: Proper pipe and process disposal

**File Filtering Implementation**:

```swift
private func parseAndFilterFiles(_ gitOutput: String, excludeTests: Bool) -> [String] {
    let allFiles = gitOutput.components(separatedBy: .newlines)
        .filter { !$0.isEmpty }
        .filter { $0.hasSuffix(".swift") }
    
    let filteredFiles = excludeTests ?
        allFiles.filter { !isTestFile($0) && !isGeneratedFile($0) } :
        allFiles.filter { !isGeneratedFile($0) }
    
    logger.info("Discovered Swift files", metadata: [
        "totalFiles": .stringConvertible(allFiles.count),
        "filteredFiles": .stringConvertible(filteredFiles.count)
    ])
    
    return filteredFiles
}

private func isTestFile(_ path: String) -> Bool {
    path.contains("/Tests/") ||
    path.hasSuffix("Tests.swift") ||
    path.hasSuffix("Test.swift")
}

private func isGeneratedFile(_ path: String) -> Bool {
    path.contains(".build/") ||
    path.contains("DerivedData/") ||
    path.contains("/Generated/") ||
    path.hasSuffix(".generated.swift") ||
    path.contains("node_modules/") ||
    path.contains("vendor/")
}
```

**Advanced Git Commands for Roulette**:

```bash
# Recently modified Swift files (for weighted selection)
git log --name-only --since="1 month ago" --pretty=format: -- "*.swift" | sort | uniq

# Files by modification frequency (hot spots)
git log --name-only --pretty=format: -- "*.swift" | grep -v "^$" | sort | uniq -c | sort -rn

# File age analysis
git log --name-only --format="%H %ai" --follow -- "*.swift"

# Complex files that changed recently (refactoring candidates)
git log --stat --since="1 week ago" -- "*.swift" | grep -E "^\s+.*\|.*\+.*-" | sort -k3 -rn
```

## Recommended Architecture

### Core Components

1. **FileSelector**: Random file selection with filtering
2. **CodeAnalyzer**: Complexity metrics and suggestion generation
3. **GitIntegration**: File discovery and metadata
4. **OutputFormatter**: Structured result presentation
5. **ConfigurationManager**: User preferences and exclusion rules

### Service Layer Pattern

Following established patterns from `Dali` services:

```swift
protocol RouletteServiceProtocol {
    func analyzeRandomFiles(count: Int, excludeTests: Bool)
        async throws -> [AnalysisResult]
}

actor RouletteService: RouletteServiceProtocol {
    private let fileSelector: FileSelector
    private let codeAnalyzer: CodeAnalyzer
    private let logger: Logger
    
    // Implementation
}
```

### Configuration Strategy

Based on existing configuration patterns:

```swift
struct RouletteConfiguration: Codable {
    let excludePatterns: [String]
    let complexityThresholds: ComplexityThresholds
    let outputFormat: OutputFormat
    
    static let `default` = RouletteConfiguration(
        excludePatterns: ["*Tests.swift", ".build/", "Generated/"],
        complexityThresholds: ComplexityThresholds.standard,
        outputFormat: .console
    )
}
```

## Implementation Priorities

### Phase 1: Core Infrastructure

1. **Git integration** for file discovery (HIGH)
2. **Basic CLI structure** with ArgumentParser (HIGH)
3. **File selection algorithm** with randomization (HIGH)
4. **Error handling framework** (MEDIUM)

### Phase 2: Analysis Engine

1. **Basic complexity metrics** (lines, functions, types) (HIGH)
2. **Pattern recognition** for Swift constructs (MEDIUM)
3. **Suggestion generation** based on thresholds (MEDIUM)
4. **Output formatting** with structured display (MEDIUM)

### Phase 3: Advanced Features

1. **Weighted selection** based on file age/complexity (LOW)
2. **Configuration file support** (LOW)
3. **CI/CD integration hooks** (LOW)
4. **Historical tracking** (LOW)

## Quality Requirements

### Testing Strategy

- Comprehensive Swift Testing coverage (>90%)
- Mock implementations for git operations
- Integration tests with real repository scenarios
- Cross-platform compatibility (macOS/Linux)

### Performance Targets

- Handle 1000+ files in <30 seconds
- Memory usage <100MB for large codebases
- Responsive CLI experience

### Security Considerations

- Input validation for all git commands
- Path traversal prevention
- No code execution of analyzed content
- Secure random number generation

## Next Steps

1. **Implement basic CLI structure** following established patterns
2. **Create git integration service** with proper error handling
3. **Develop file selection algorithm** with cryptographic randomness
4. **Build analysis engine** with complexity metrics
5. **Add comprehensive test coverage** using Swift Testing

## References

- Existing CLI patterns: `Sources/Wayne/`, `Sources/Standards/`,
  `Sources/Vegas/`
- Service layer examples: `Sources/Dali/`
- Testing patterns: `Tests/` directory structure
- Error handling: Consistent across all targets
- Configuration patterns: `Sources/Brochure/Configuration/`

