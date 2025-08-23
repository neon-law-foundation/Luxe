# Create PR

## Usage

```txt
/create-pr
```

## Steps

Create a pull request using specialized agents to ensure code quality and proper workflow. Follow these steps:

1. **Code Review with test-driven-developer** - Use the test-driven-developer agent to review the current code changes:
   - Analyze all modifications for quality and adherence to Swift best practices
   - Verify TDD compliance and test coverage
   - Ensure all tests pass with `swift test --no-parallel` (exit code 0 mandatory)
   - Fix any issues found before proceeding

2. **Format Compliance with swift-formatter and markdown-formatter** - Use the swift-formatter and markdown-formatter
   agents to enforce formatting:
   - Run SQL migration linting: `sqlfluff lint --dialect postgres .`
   - Auto-fix SQL issues if needed: `sqlfluff fix --dialect postgres .`
   - Run Swift format compliance: `swift format lint --strict --recursive --parallel --no-color-diagnostics .`
   - Auto-format if needed: `swift format format --in-place --recursive --parallel .`
   - Run markdown validation: `./scripts/validate-markdown.sh --fix` then `./scripts/validate-markdown.sh`
   - **CRITICAL**: SQL linting, Swift format, and Markdown validation MUST ALL exit with code 0
   - Fix ALL issues before proceeding

3. **Final Test Verification with test-driven-developer** - Use the test-driven-developer agent to verify all tests
   still pass after formatting:
   - Run comprehensive test suite: `swift test --no-parallel`
   - Ensure ALL tests pass with exit code 0
   - Verify no regressions were introduced during formatting
   - Fix any test failures before proceeding to branch management

4. **Branch Management with git-branch-manager** - Use the git-branch-manager agent for branch operations:
   - Check current branch with `git branch --show-current`
   - If on main branch, create feature branch: `git checkout -b feature/descriptive-name`
   - Sync with remote: `git fetch origin` and `git rebase origin/main`
   - Resolve any conflicts if they arise
   - Never create PR from main branch

5. **Commit Creation with commiter** - Use the commiter agent to create conventional commit:
   - Stage all changes: `git add .`
   - Verify build succeeds: `swift build`
   - Run final test verification: `swift test --no-parallel` (must exit code 0)
   - Create conventional commit: `git commit -m "<type>[scope]: <description>"`
   - Push branch: `git push origin $(git branch --show-current)`

6. **PR Creation with pull-request-manager** - Use the pull-request-manager agent to create pull request:
   - Create PR using `gh pr create` with descriptive title and comprehensive summary
   - Link to relevant roadmaps/issues in PR description
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
┌─────────────────────┐    ┌──────────────┐    ┌─────────────────────┐    ┌───────────────────┐
│ test-driven-       │───▶│ Formatters   │───▶│ test-driven-       │───▶│ git-branch-      │
│ developer          │    │              │    │ developer          │    │ manager          │
│ Code Review        │    │ Format Check │    │ Test Verify        │    │ Branch Mgmt      │
└─────────────────────┘    └──────────────┘    └─────────────────────┘    └───────────────────┘
                                                                    │
                                                                    ▼
┌─────────────┐    ┌──────────────────────┐    ┌─────────────┐
│issue-updater│◀───│ pull-request-manager │◀───│  commiter   │
│ Roadmap Tag │    │ PR Creation          │    │ Commits     │
└─────────────┘    └──────────────────────┘    └─────────────┘
```

## Quality Gates

Each agent enforces specific quality requirements:

- **test-driven-developer**: All tests pass, code quality verified
- **swift-formatter & markdown-formatter**: SQL migrations linted, Swift format compliant, markdown validated
  (all exit code 0 mandatory)
- **git-branch-manager**: Clean branch state, conflicts resolved, synced with main
- **commiter**: Conventional commits, tests passing, quality gates met
- **pull-request-manager**: Comprehensive PR description, roadmap links, all checks pass
- **issue-updater**: Roadmap issues updated, progress tracked, commits linked

## Error Handling

If any agent fails:
1. **test-driven-developer fails**: Fix code issues, re-run tests
2. **Formatters fail**: Fix ALL formatting issues (SQL, Swift, markdown) until all validations exit 0, re-validate
3. **commiter fails**: Check git status, resolve conflicts

Never proceed to next step if current agent reports failure.

## Success Criteria

PR creation is complete when:
- ✅ All code reviewed and tests passing
- ✅ All formatting validated and compliant (SQL, Swift, markdown)
- ✅ Final test verification passed (no regressions)
- ✅ Feature branch created (not main)
- ✅ Conventional commit created
- ✅ PR created with proper description
- ✅ Roadmaps tagged with PR number
- ✅ All CI checks will pass
