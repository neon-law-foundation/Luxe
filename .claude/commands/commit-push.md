# Commit and Push

## Usage

```txt
/commit-push
```

## Description

Commit and push the current changes to the remote repository. This command ensures ALL tests pass and markdown 
formatting is correct before committing.

## Steps

1. Check that we are not on the main branch.
2. **MANDATORY**: Run markdown formatting validation using `./scripts/validate-markdown.sh --fix` and then
   `./scripts/validate-markdown.sh` to ensure it exits with code 0.
3. **MANDATORY**: Run `CI=true swift test --no-parallel` to ensure ALL tests pass with exit code 0. If any tests
   fail, DO NOT proceed with commit.
4. Run `git add .` to stage all changes.
5. Create a descriptive commit message following conventional commit format.
6. Push the changes to the remote repository.
