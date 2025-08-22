# Review PR

## Usage

```txt
/review-pr
```

Review a PR and automatically fix all failing tests, ensuring compatibility with both macOS and Linux platforms.

## CRITICAL: macOS/Linux Parity Rule

**ALWAYS consider macOS and Linux platform parity for every fix.** Tests must pass on both platforms. If a test
fundamentally cannot work on Linux (e.g., requires macOS-specific APIs), disable it for CI with appropriate guards:
- Use `#if !os(Linux)` for macOS-only code
- Check for `Environment.get("CI")` to skip tests in CI environment
- Document why the test is platform-specific

## Steps

1. View the current status of the PR with `gh pr view` to understand the PR context
2. **CRITICAL: Run `swift build` first to check for compilation errors** that may be caused by cross-platform issues
   (GitHub Actions runs on Linux, local development runs on macOS). Specifically look for:
   - macOS-only libraries or frameworks (like Foundation components that don't work on Linux)
   - Platform-specific file paths or system calls
   - Dependencies that aren't available on Linux Swift
   - Import statements that work on macOS but fail on Linux
3. Check the GitHub Actions logs to identify failing tests using `gh pr checks` and `gh run view <run-id> --log-failed`
4. **Pay special attention to platform compatibility**: Look for test failures that mention "No such module", "cannot
   find", or file path issues that suggest macOS vs Linux differences
5. **Fix compilation errors first**: Address any build errors, especially those related to platform compatibility
6. **Fix failing tests systematically**:
   - Analyze each test failure to understand the root cause
   - Implement fixes that work on both macOS and Linux
   - Consider using conditional compilation (#if os(macOS)) when platform-specific code is unavoidable
   - For tests that cannot be fixed for Linux, disable them in CI with appropriate environment checks
   - Ensure proper test environment setup (mocks, test data, configuration)
7. **Run tests after each fix**: Use `swift test --filter [TestName]` to verify individual fixes
8. **Run full test suite**: Execute `swift test --no-parallel` to ensure all tests pass with exit code 0
9. **Verify cross-platform compatibility**:
   - Ensure no macOS-specific APIs are used without Linux alternatives
   - Check that file paths use platform-agnostic approaches
   - Verify that all dependencies are available on both platforms
   - Confirm disabled tests are properly guarded for CI/Linux environments
10. **Clean up any existing roadmap files**: Delete any Roadmaps/PullRequestPR*Roadmap.md files after fixes are complete
11. **Commit and push changes**: Create a descriptive commit message detailing the fixes made
