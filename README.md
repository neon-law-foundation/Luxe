# Luxe

A monorepo for [the trifecta](./TRIFECTA.md) of organizations - Neon Law, Neon Law Foundation, and Sagebrush Services.
Another small business, Hoshi Hoshi, creators of Destined Travel, an astrocartography travel website, is included herein
because it has the same engineering team that develops applications using Swift Server.

Luxe is a play on lux, Latin for light, and luxurious, an homage to our founding city of Las Vegas, Nevada.

## Getting Started

Luxe is built by developers who are comfortable with macOS, Swift, containers, and git.

### Quick Setup (Recommended)

1. Install the latest macOS and Xcode
2. Install Docker Desktop
3. Run the unified setup script:

   ```bash
   ./scripts/setup-development-environment.sh
   ```

This script will automatically:

- Install Homebrew and all required dependencies
- Set up git hooks (if configured)
- Start Docker services (PostgreSQL, Dex, LocalStack)
- Configure Dex with static users and luxe-client
- Run database migrations
- Verify your installation

### Testing Your Setup

After setup, test authentication by:

1. Starting a web target: `swift run Bazaar`
2. Navigate to: <http://localhost:8080/app/me>
3. Login with: `admin@neonlaw.com / Vegas702!` from the redirected Dex login page.

## Claude Code Development

We encourage developing this repository using **Claude Code**. This project follows a strict
**roadmap-driven development** approach with Test-Driven Development (TDD) and quality-first principles.

### Development Philosophy

```text
🗺️  Roadmap-Driven Development
├── 📋 All work starts with roadmaps (never code directly)
├── 🧪 Test-Driven Development with Swift Testing
├── 🎯 Quality gates at every step (swift test)
└── 🤖 Claude Code automation for consistent execution
```

**Always reference CLAUDE.md** - it contains comprehensive guidelines, shortcuts, and quality standards. The more you
*explore CLAUDE.md, the more productive you'll become with this codebase.

### Claude Code Agents

The project includes specialized AI agents (`.claude/agents/`) that automate development workflows:

- **blog-post-writer** - Professional blog content specialist creating factual, warm, and trustworthy blog posts
- **commiter** - Conventional commit specialist ensuring quality gates before commits
- **designer** - CSS and front-end styling specialist for beautiful, minimalist designs
- **documenter** - Markdown documentation specialist creating comprehensive project documentation
- **git-branch-manager** - Branch and merge specialist handling git operations and conflict resolution
- **issue-creator** - Creates GitHub issues with detailed roadmaps and Swift code samples for task planning
- **issue-updater** - Roadmap tracking specialist updating issues with commits, PRs, and progress
- **markdown-formatter** - Enforces markdown formatting compliance before commits and PRs
- **pull-request-manager** - Pull request specialist creating comprehensive PRs linked to roadmaps
- **roadmap-implementer** - Orchestrates complete roadmap implementation by delegating to other agents
- **swift-documenter** - Writes comprehensive DocC documentation for all public Swift APIs
- **swift-formatter** - Enforces Swift formatting compliance before commits and PRs
- **test-driven-developer** - TDD specialist implementing tasks until all tests pass with exit code 0

## Targets

- **TBD Ace** macOS app for Neon Law attorneys
- **Bazaar** Unified web application and HTTP API served at <https://www.sagebrush.services>
- **Bouncer** Authentication and Authorization logic used across the services
- **Brochure** Static website deployment CLI tool for uploading sites to S3/CloudFront. Creates and manages:
  - <www.hoshihoshi.app> - Astrology and birth chart service
  - <www.neonlaw.com> - Neon Law primary website
  - <www.neonlaw.org> - Neon Law Foundation nonprofit website
  - <www.tarotswift.me> - Tarot reading service
- **TBD Concierge** macOS app for `support@{neonlaw.com,neonlaw.org,sagebrush.services}`. Works with PaperPusher.
- **Dali** Data Access Layer (DAL) for Postgres tables, S3 buckets, and vendor data
- **Destined** A vibrational travel agency <https://www.destined.travel>
- **TBD FoodCart** OpenAPI Client for the Bazaar API
- **MiseEnPlace** Create a private GitHub repository for a `matters.project` for attorney-client work
- **NLFWeb** <https://www.neonlaw.org> a 501(c)(3) nonprofit organization
- **TBD NeonLaw** Apple app for Neon Law customers
- **Palette** Postgres migration CLI
- **TBD PaperPusher** Email logic for `support@{neonlaw.com,neonlaw.org,sagebrush.services}`
- **RebelAI** MCP for safe vibe lawyering with Sagebrush Standards
- **TBD Sagebrush** Apple app for Sagebrush Services customers.
- **Standards** CLI for managing standards for Neon Law, Neon Law Foundation, and Sagebrush Services.
- **TestUtiltiies** Test helpers for Swift Server targets.
- **TouchMenu** Common UI components shared across web targets
- **Vegas** AWS infrastructure-as-code
- **Wayne** Turn local Apple targets into standalone XCode projects

## Managed Support

If you work for a law firm interested in deploying a custom version of Luxe to your own AWS account to service your
clients with AI, please contact Sagebrush Services at [support@sagebrush.services](mailto:support@sagebrush.services).

## License

The repository herein is licensed under the [Apache 2 license](./LICENSE). The corpus of this repository is copyright
from the Neon Law Foundation. Copyrights and trademarks are owned by Neon Law Foundation, Neon Law, and Sagebrush
Services.  Nothing here is legal advice. You are not permitted to use trademarks without written permission.
