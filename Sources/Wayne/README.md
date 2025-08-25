# Wayne

Wayne is a command-line tool that generates standalone Xcode projects for macOS and iOS targets from your
Swift Package Manager monorepo. This allows you to open and build individual targets in Xcode without the
complexity of managing the entire monorepo.

## Why Wayne?

When working with large Swift Package Manager monorepos, opening the entire project in Xcode can be slow
and complex. Wayne solves this by:

- **Isolated Development**: Work on individual targets without distractions from the entire codebase

- **Faster Xcode Performance**: Smaller projects load faster and consume less memory

- **Better Focus**: Concentrate on specific features or applications

- **Simplified Debugging**: Debug individual targets without interference from other components

## Features

- **Automatic Target Detection**: Scans your Package.swift to identify all executable macOS/iOS targets

- **Dependency Resolution**: Automatically includes all target dependencies in the generated project

- **Source File Linking**: Links to original source files so changes are reflected in both places

- **Downloads Integration**: Generated projects are placed in your Downloads folder for easy access

- **Swift Package Integration**: Uses local package references to maintain dependency relationships

## Installation

Wayne is part of the Luxe monorepo. No additional installation is required.

## Usage

### Generate Project for a Target

```bash
swift run Wayne Concierge
```

This will:

1. Analyze the `Concierge` target from Package.swift
2. Generate a standalone Swift Package project
3. Place it in `~/Downloads/ConciergeProject/`
4. Create a Package.swift that references the original source files
5. Display the path and open command

The generated project can be opened directly in Xcode:

```bash
open ~/Downloads/ConciergeProject/Package.swift
```

### List Available Targets

```bash
swift run Wayne --list
```

This displays all available macOS/iOS executable targets with their dependencies and source file counts.

### Specify Output Directory

```bash
swift run Wayne Concierge --output-directory /path/to/output
```

### Get Help

```bash
swift run Wayne --help
```

## Supported Targets

Wayne works with any executable target in your Package.swift that's designed for macOS or iOS. Common examples include:

- **Concierge**: macOS SwiftUI application for ticket management

- **RebelAI**: MCP server for legal AI assistance

- **Vegas**: Infrastructure management CLI

- **Brochure**: Static website deployment tool

## How It Works

1. **Package Analysis**: Wayne parses your Package.swift file to identify executable targets
2. **Dependency Resolution**: Extracts all dependencies for the target
3. **Source Discovery**: Scans the file system for source files in the target directory
4. **Project Generation**: Creates a standalone Swift Package project including:
   - New `Package.swift` with references to original source files
   - Proper dependency declarations for external packages
   - Local target definitions that point to the original source directories
   - Clean project structure that opens directly in Xcode

## Generated Project Structure

```text
TargetNameProject/
└── Package.swift               # Swift Package Manager project file
```

The Package.swift file contains:

- References to your original source files (no copying)

- All necessary dependencies from the main Luxe package

- Clean target definitions for Xcode integration

## Environment Variables

- `WAYNE_AUTO_OPEN=true`: Automatically open generated projects in Xcode

## Troubleshooting

### Target Not Found

If Wayne can't find your target:

1. Ensure the target is defined in Package.swift
2. Verify it's an `.executableTarget` (not `.target` or `.testTarget`)
3. Check that the target name matches exactly

### Build Errors in Generated Project

If the generated Xcode project has build errors:

1. Ensure all dependencies are properly defined in Package.swift
2. Check that source files exist in the expected location
3. Verify that the target builds successfully with `swift build`

### Permission Errors

If Wayne can't write to the output directory:

1. Check that the output directory exists and is writable
2. Try specifying a different output directory with `--output-directory`

## Contributing

Wayne follows the Luxe project's Swift with Test Driven Development guidelines:

1. Create tests in `Tests/WayneTests/` that describe the functionality
2. Run tests with `swift test --filter WayneTests`
3. Implement functionality to make tests pass
4. Ensure all tests pass with `swift test --no-parallel`

## Implementation Details

Wayne is built with:

- **Swift ArgumentParser**: For command-line interface

- **Foundation**: For file system operations and string processing

- **Regular Expressions**: For parsing Package.swift content

- **Xcode Project Format**: Generates valid `.pbxproj` files

The core components are:

- `Wayne.swift`: Main CLI interface

- `PackageParser.swift`: Parses Package.swift files

- `XcodeProjectGenerator.swift`: Creates Xcode project files

- `TargetInfo.swift`: Data model for target information

## License

Wayne is part of the Luxe monorepo and follows the same licensing terms.
