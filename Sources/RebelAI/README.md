# RebelAI MCP Server

RebelAI is a Model Context Protocol (MCP) server that provides comprehensive legal tools and case search
functionality. It's built using the Swift MCP SDK and communicates via StdioTransport.

## Features

- **Lookup Matter** tool: Looks up matter information by ID

- **Lookup Case** tool: Looks up legal case information by name

- **Create Operating Agreement** tool: Creates LLC operating agreements with customizable parameters

- **Create Stock Issuance** tool: Creates stock issuance certificates

- **Email Motion** tool: Sends legal motions via Postmark API

- **Search Cases** tool: Searches legal cases using Docket Alarm API with natural language queries

- StdioTransport for reliable communication with MCP clients

- Built with Swift for performance and type safety

## Prerequisites

- Swift 6.1 or later

- macOS 15.0 or later

- Claude Desktop app

## Building

From the project root directory:

```bash
swift build --target RebelAI
```

## Running Locally

To test the MCP server locally:

```bash
swift run RebelAI
```

The server will start and listen for MCP messages on stdin/stdout.

## Testing

Run the test suite:

```bash
swift test --filter RebelAITests
```

## Adding to Claude Desktop

To use this MCP server with Claude Desktop, you need to configure it in your Claude Desktop settings. This
guide provides step-by-step instructions for both production and development setups.

### Prerequisites

- **Claude Desktop**: Download from [Claude.ai](https://claude.ai/download)

- **Swift 6.1+**: Required to build and run the MCP server

- **Postmark Account** (optional): For Email Motion tool functionality

### Setup Overview

There are two ways to set up the RebelAI MCP server:

1. **Production Setup**: Build a release binary for faster startup
2. **Development Setup**: Use `swift run` for easier development and debugging

### Option 1: Production Setup (Recommended)

#### 1. Build the Release Executable

```bash
cd ~/Luxe
swift build --target RebelAI --configuration release
```

#### 2. Find the Executable Path

```bash
realpath .build/release/RebelAI
```

This will output something like: `/Users/yourname/Luxe/.build/release/RebelAI`

#### 3. Configure Claude Desktop

1. **Open Claude Desktop**
2. **Go to Settings**: Click the gear icon or use ⌘+, (Cmd+Comma)
3. **Navigate to Developer Settings**: Look for "Developer" or "MCP Servers" section
4. **Edit MCP Configuration**: Click "Edit" or "Configure"
5. **Add the following configuration**:

```json
{
  "mcpServers": {
    "rebelai": {
      "command": "/full/path/to/your/project/.build/release/RebelAI",
      "args": []
    }
  }
}
```

**Replace `/full/path/to/your/project/` with your actual Luxe project path from step 2.**

### Option 2: Development Setup (Swift Run)

This setup is ideal for development as it automatically picks up code changes without rebuilding.

#### 1. Set Environment Variables (Optional)

If you want to use the Email Motion tool, set up Postmark:

```bash
# Add to your ~/.zshrc or ~/.bash_profile
export POSTMARK_API_TOKEN="your-postmark-server-token"
```

#### 2. Configure Claude Desktop for Development

```json
{
  "mcpServers": {
    "rebelai": {
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "~/Luxe",
        "RebelAI"
      ],
      "env": {
        "POSTMARK_API_TOKEN": "${POSTMARK_API_TOKEN}"
      }
    }
  }
}
```

### 3. Restart Claude Desktop

**Important**: You must completely restart Claude Desktop for MCP changes to take effect.

1. **Quit Claude Desktop**: Use ⌘+Q (Cmd+Q) or Quit from the menu
2. **Wait 5 seconds**: Ensure the application fully closes
3. **Restart Claude Desktop**: Open it again from Applications or Spotlight
4. **Wait for initialization**: The MCP server will start automatically

### 4. Verify Installation

#### Test MCP Server Connection

In Claude Desktop, start a new conversation and try:

```text
"What tools do you have available?"
```

You should see a response listing all RebelAI tools:

- `Lookup Matter` - Look up legal matter information

- `Lookup Case` - Look up case information by name

- `Create Operating Agreement` - Generate LLC operating agreements

- `Create Stock Issuance` - Create stock issuance certificates

- `Email Motion` - Send legal motions via email

- `Search Cases` - Search legal cases using Docket Alarm API

#### Test Search Cases Tool

Try searching for legal cases:

```text
"Search cases for contract disputes"
```

This should return real case results from the Docket Alarm database.

### 5. Troubleshooting Connection Issues

If the MCP server doesn't appear or tools aren't working:

#### Check Configuration File Location

The Claude Desktop configuration file should be at:

```bash
~/Library/Application Support/Claude/claude_desktop_config.json
```

#### Verify File Contents

```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Should show your MCP server configuration.

#### Test MCP Server Manually

Test that the server starts correctly:

```bash
cd ~/Luxe
swift run RebelAI
```

The server should start and wait for MCP messages. Press Ctrl+C to stop.

#### Check Claude Desktop Logs

1. Open Claude Desktop
2. Go to **Settings** → **Developer**
3. Look for error messages or logs related to MCP servers

#### Common Issues and Solutions

**Issue**: "Command not found" or "Permission denied"

```bash
# Fix permissions
chmod +x .build/release/RebelAI

# Verify the path exists
ls -la .build/release/RebelAI
```

**Issue**: "Swift command not found"

```bash
# Install Swift if needed
xcode-select --install

# Verify Swift installation
swift --version
```

**Issue**: "Build failed"

```bash
# Clean and rebuild
swift package clean
swift build --target RebelAI --configuration release
```

**Issue**: "MCP server not connecting"

1. Check that the JSON configuration is valid (no syntax errors)
2. Ensure the file path is absolute, not relative
3. Restart Claude Desktop completely
4. Check that environment variables are set if using email features

## Usage Examples

Once configured with Claude Desktop, you can interact with the MCP server:

### Example 1: List Tools

```text
User: What tools do you have available?
Claude: I have access to several legal tools including Lookup Matter, Lookup Case,
Create Operating Agreement, Create Stock Issuance, Email Motion, and Search Cases.
```

### Example 2: Search Legal Cases

```text
User: Search cases for contract disputes
Claude: I'll search for cases related to contract disputes using the Docket Alarm database.
[Uses Search Cases tool with inquiry: "contract disputes"]
Result: Search Results for: 'contract disputes'
Source: Docket Alarm API
Found 61194916 total cases (showing first 8):

1. Boggs Contracting, Inc., et al v. Bernard Freismuth, et al
   Court: U.S. Court of Appeals, Eleventh Circuit
   Docket: 22-10296
   Date Filed: Unknown Date

2. Mason Tenders District Council Welfare Fund v. Blade Contracting, Inc.
   Court: U.S. Court of Appeals, Second Circuit
   Docket: 25-1045 (Civil)
   Date Filed: 04/25/2025
...
```

### Example 3: Create Operating Agreement

```text
User: Create an operating agreement for Sagebrush Services LLC
Claude: I'll create an LLC operating agreement template.
[Uses Create Operating Agreement tool]
Result: Starting LLC Operating Agreement creation...
LLC Name: Sagebrush Services LLC
Management Structure: Member-managed
...
```

### Example 4: Look Up Matter

```text
User: Can you look up matter ID 12345?
Claude: I'll use the Lookup Matter tool to look up that matter ID.
[Uses Lookup Matter tool with matter_id: "12345"]
Result: [Matter information for Sagebrush Services]
```

### Example 5: Email Legal Motion

```text
User: Email a motion to dismiss for case #12345
Claude: I'll send the motion via email using the Postmark API.
[Uses Email Motion tool]
Result: Motion email sent successfully to admin@neonlaw.com
```

## Search Cases Tool (Docket Alarm Integration)

The `Search Cases` tool integrates with the Docket Alarm API to provide comprehensive legal case search functionality:

### Features

- **Natural Language Search**: Use plain English queries like "contract disputes" or "employment law violations"

- **Full Text Search**: Searches across case titles, descriptions, and metadata

- **Real-time Results**: Live API integration with Docket Alarm database

- **Detailed Case Information**: Returns court, case number, dates, and case details

### Usage Patterns

The tool is designed to understand natural language inputs where everything after "for" becomes the search inquiry:

- ✅ "Search cases for trademark infringement" → Inquiry: "trademark infringement"

- ✅ "Find cases about employment law" → Inquiry: "employment law"

- ✅ "Lookup cases for patent litigation" → Inquiry: "patent litigation"

- ✅ "Cases involving real estate disputes" → Inquiry: "real estate disputes"

### Real-World Examples

From actual API responses with millions of cases:

**Query**: "Nevada employment law casino worker workplace injury"
**Results**: Cases involving worker compensation, employment disputes, and workplace safety in Nevada casinos

**Query**: "contract disputes"
**Results**: 61+ million cases involving contractual disagreements across all courts

### API Integration

- **Endpoint**: `https://www.docketalarm.com/api/v1/search`

- **Authentication**: Basic Auth (hardcoded trial credentials)

- **Method**: GET with inquiry parameter mapped to API's `q` parameter

- **Response Format**: JSON with search_results array containing case details

- **Database Size**: 61+ million legal cases from courts nationwide

### Error Handling

The tool gracefully handles:

- Network timeouts

- Invalid API responses

- Empty search queries

- Authentication failures

- Rate limiting

## Configuration File Location

The Claude Desktop MCP configuration file is typically located at:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

## Troubleshooting

### MCP Server Not Appearing

1. **Check the executable path**: Ensure the path in your configuration is correct and the file exists
2. **Verify permissions**: Make sure the executable has proper permissions:

   ```bash
   chmod +x .build/release/RebelAI
   ```

3. **Check logs**: Look at Claude Desktop's developer console for any error messages
4. **Restart completely**: Quit Claude Desktop entirely and restart

### Tool Not Working

1. **Rebuild the project**:

   ```bash
   swift build --target RebelAI --configuration release
   ```

2. **Test locally**: Run `swift run RebelAI` to ensure the server starts without errors
3. **Check configuration**: Verify the JSON configuration is valid

### Development Mode

For development, you can use the debug build and `swift run`:

```json
{
  "mcpServers": {
    "rebelai-dev": {
      "command": "swift",
      "args": [
        "run",
        "--package-path",
        "~/Luxe",
        "RebelAI"
      ],
      "env": {
        "SWIFT_LOG_LEVEL": "debug",
        "POSTMARK_API_TOKEN": "${POSTMARK_API_TOKEN}"
      }
    }
  }
}
```

This allows you to make changes and test without rebuilding the release version.

## Architecture

- **Entrypoint**: Main MCP server setup and configuration

- **StdioTransport**: Handles communication with Claude Desktop

- **Tool Registration**: Registers the `Lookup Matter` tool with proper JSON schema

- **Error Handling**: Provides appropriate error responses for invalid tool calls

## Next Steps

This is a basic implementation that returns "bananas" for any lookup. To extend this server:

1. Connect to a real database or API
2. Add more tools for different legal operations
3. Implement proper authentication and authorization
4. Add logging and monitoring capabilities

## Support

For issues related to:

- **MCP Protocol**: Check the [MCP documentation](https://modelcontextprotocol.io/)

- **Swift MCP SDK**: Check the [Swift SDK repository](https://github.com/modelcontextprotocol/swift-sdk)

- **Claude Desktop**: Check Claude's official documentation
