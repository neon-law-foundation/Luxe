# Create Commit

## Usage

```txt
/create-commit
```

Create a commit and push to the current branch with the following steps:

1. Review all changes with `git status` and `git diff`
2. Stage all changes with `git add .`
3. Run `swift test --no-parallel` to ensure all tests pass. Do not proceed if tests fail. That means that
   `swift test --no-parallel` must have an exit code of 0. If tests fail, go back to plan mode and have
   a dialogue with the developer. Note: `swift test --no-parallel` can take up to 10 minutes to complete,
   so be patient and wait for it to finish.
4. Create a commit message following Conventional Commits format (e.g., `feat:`, `fix:`, `docs:`, etc.)
5. Commit the changes with `git commit -m "<type>[scope]: <description>"`
6. **IMPORTANT: Check PR tagging** - If this commit is going to an existing PR and completes
   roadmap tasks, update relevant roadmaps with PR number and commit SHA before pushing
7. Push to the current branch with `git push`
