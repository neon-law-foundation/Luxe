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

1. **Analyze GitHub Actions failures first**: Use `gh pr checks` and `gh run view <run-id> --log-failed` to identify the
   root cause
   - Look specifically for:
     - `connectionRequestTimeout` errors (database connection pool issues)
     - Memory allocation failures
     - Platform-specific compilation errors
     - Test timeout issues
     - Resource exhaustion problems
2. **CRITICAL: Run `swift build` locally** to check for compilation errors that may be caused by cross-platform issues
   (GitHub Actions runs on Linux, local development runs on macOS). Specifically look for:
   - macOS-only libraries or frameworks (like Foundation components that don't work on Linux)
   - Platform-specific file paths or system calls
   - Dependencies that aren't available on Linux Swift
   - Import statements that work on macOS but fail on Linux
3. **Database Connection Pool Analysis**: If seeing `connectionRequestTimeout` errors:
   - Check for database connection leaks in test code
   - Verify proper connection cleanup in test teardown methods
   - Consider database connection pool configuration (max connections, timeout settings)
   - Look for tests that don't properly close database resources
4. **Memory and Resource Management**: For memory-related failures:
   - Use Swift test flags to limit memory usage: `--jobs 1`, `--no-parallel`
   - Consider environment variables: `SWIFT_MAX_MEMORY_MB`, `MALLOC_CONF`
   - Remove custom memory profiling scripts that may interfere with standard Swift testing
   - Run tests with fewer parallel processes to reduce memory pressure
5. **Fix root causes systematically**:
   - **Database connection timeouts**: Fix connection pool configuration and test cleanup
   - **Platform compatibility**: Use conditional compilation (#if os(macOS)) when needed
   - **Memory issues**: Optimize test execution order and resource cleanup
   - **Resource leaks**: Ensure proper cleanup in test teardown methods
6. **Test execution strategy**:
   - Run tests with `swift test --no-parallel` to prevent resource conflicts
   - Use `swift test --filter [TestName]` for targeted testing after fixes
   - Avoid custom test execution scripts that may interfere with Swift's memory management
7. **Verify fixes**:
   - Run full test suite locally: `swift test --no-parallel`
   - Ensure proper resource cleanup between tests
   - Verify cross-platform compatibility for any platform-specific fixes
8. **Clean up and commit**:
   - Remove any problematic custom test scripts
   - Clean up any existing roadmap files: Delete Roadmaps/PullRequestPR*Roadmap.md files
   - Commit changes with descriptive message detailing the root cause and fix
