# Create PR

## Usage

```txt
/create-pr
```

## Steps

Create a pull request using specialized agents to ensure code quality and proper workflow. Follow these steps:

0. **Pre-Check: Detect Swift File Changes** - Check if there are Swift code changes to review:
   - Check for changed Swift files in `Sources/` or `Tests/` folders:
     `git diff --name-only origin/main -- Sources/ Tests/ | grep '\.swift$'`
   - **NOTE**: If no Swift files have changed, Swift-specific steps will be skipped
   - The workflow will proceed with all changes regardless of file type
   - Swift testing and formatting steps are conditionally applied based on changes detected

1. **Code Review with developer** - Use the developer agent to review the current code changes:
   - Analyze all modifications for quality and adherence to best practices
   - **IF Swift files changed**: Verify TDD compliance and test coverage
   - **IF Swift files changed**: Ensure all tests pass with `swift test --no-parallel` (exit code 0 mandatory)
   - **IF no Swift files**: Skip Swift-specific testing, focus on general code quality
   - Fix any issues found before proceeding

2. **Format Compliance with swift-formatter and markdown-formatter** - Use the swift-formatter and markdown-formatter
   agents to enforce formatting:
   - Run SQL migration linting: `sqlfluff lint --dialect postgres .`
   - Auto-fix SQL issues if needed: `sqlfluff fix --dialect postgres .`
   - **IF Swift files changed**: Run Swift format compliance:
     `swift format lint --strict --recursive --parallel --no-color-diagnostics .`
   - **IF Swift files changed**: Auto-format if needed: `swift format format --in-place --recursive --parallel .`
   - Run markdown validation: `./scripts/validate-markdown.sh --fix` then `./scripts/validate-markdown.sh`
   - **CRITICAL**: All applicable linting (SQL, Swift if changed, markdown) MUST exit with code 0
   - Fix ALL issues before proceeding

3. **Final Test Verification with developer** - Use the developer agent to verify all tests
   still pass after formatting:
   - **IF Swift files changed**: Run comprehensive test suite: `swift test --no-parallel`
   - **IF Swift files changed**: Ensure ALL tests pass with exit code 0
   - **IF Swift files changed**: Verify no regressions were introduced during formatting
   - **IF no Swift files**: Skip Swift testing, proceed to branch management
   - Fix any test failures before proceeding to branch management

4. **Branch Management with git-branch-manager** - Use the git-branch-manager agent for branch operations:
   - Check current branch with `git branch --show-current`
   - If on main branch, create feature branch: `git checkout -b feature/descriptive-name`
   - Sync with remote: `git fetch origin` and `git rebase origin/main`
   - Resolve any conflicts if they arise
   - Never create PR from main branch

5. **Commit Creation with commiter** - Use the commiter agent to create conventional commit:
   - Stage all changes: `git add .`
   - **IF Swift files changed**: Verify build succeeds: `swift build`
   - **IF Swift files changed**: Run final test verification: `swift test --no-parallel` (must exit code 0)
   - **IF no Swift files**: Skip Swift build/test verification
   - Create conventional commit: `git commit -m "<type>[scope]: <description>"`
   - Push branch: `git push origin $(git branch --show-current)`

6. **PR Creation with pull-request-manager** - Use the pull-request-manager agent to create pull request:
   - Create PR using `gh pr create` with descriptive title and comprehensive summary
   - Link to relevant roadmaps GitHub issues in PR description
   - Add appropriate labels and reviewers
   - Include testing verification and quality gates status
   - Get PR number and URL

7. **Roadmap Integration with issue-updater** - Use the issue-updater agent for roadmap updates:
   - Tag relevant GitHub issues with PR number
   - Update issue status sections with progress
   - Add commit SHAs to completed tasks
   - Post progress reports on roadmap issues

8. **Final Verification** - Ensure PR is ready:
   - Open PR in browser: `open https://github.com/neon-law/Luxe/pull/XXXX`
   - Verify all CI checks will pass
   - Confirm roadmap linking is complete

## Agent Workflow Summary

```text
┌─────────────────────┐    ┌─────────────────────┐    ┌──────────────┐    ┌─────────────────────┐    ┌───────────────────┐
│ Pre-Check:         │───▶│ developer           │───▶│ Formatters   │───▶│ developer          │───▶│ git-branch-      │
│ Detect Changes     │    │ developer           │    │              │    │ developer          │    │ manager          │
│ (All File Types)   │    │ Code Review         │    │ Format Check │    │ Test Verify        │    │ Branch Mgmt      │
└─────────────────────┘    └─────────────────────┘    └──────────────┘    └─────────────────────┘    └───────────────────┘
                                                                                                    │
                                                                                                    ▼
┌─────────────┐    ┌──────────────────────┐    ┌─────────────┐
│issue-updater│◀───│ pull-request-manager │◀───│  commiter   │
│ Roadmap Tag │    │ PR Creation          │    │ Commits     │
└─────────────┘    └──────────────────────┘    └─────────────┘
```

## Quality Gates

Each agent enforces specific quality requirements:

- **pre-check**: Detect any file changes from origin/main, note if Swift files are included
- **developer**: Code quality verified; Swift tests pass if Swift files changed
- **swift-formatter & markdown-formatter**: SQL migrations linted, Swift format compliant (if changed), markdown validated
  (all applicable linting exit code 0 mandatory)
- **git-branch-manager**: Clean branch state, conflicts resolved, synced with main
- **commiter**: Conventional commits, applicable quality gates met (Swift tests if changed)
- **pull-request-manager**: Comprehensive PR description, roadmap links, all checks pass
- **issue-updater**: Roadmap issues updated, progress tracked, commits linked

## Error Handling

If any agent fails:
0. **pre-check**: No longer blocks workflow - proceeds with any detected changes
1. **developer fails**: Fix code issues, re-run applicable tests
2. **Formatters fail**: Fix ALL applicable formatting issues until all validations exit 0, re-validate
3. **commiter fails**: Check git status, resolve conflicts

Never proceed to next step if current agent reports failure.

## Success Criteria

PR creation is complete when:
- ✅ Any file changes detected from origin/main
- ✅ All code reviewed and applicable tests passing
- ✅ All applicable formatting validated and compliant (SQL, Swift if changed, markdown)
- ✅ Final verification passed (Swift tests if changed, no regressions)
- ✅ Feature branch created (not main)
- ✅ Conventional commit created
- ✅ PR created with proper description
- ✅ Roadmaps tagged with PR number
- ✅ All CI checks will pass
