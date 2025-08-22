# PR Steps

## Usage

```txt
/pr-steps
```

## Description

Implement the next step in the PullRequestXXXRoadmap.md file systematically, where XXX is the PR number.

## Steps

1. Read the Roadmaps/PullRequest$ARGUMENTSRoadmap.md file to identify the next uncompleted task (first `- [ ]` checkbox)
2. Mark the task as in progress by changing `- [ ]` to `- [x]` in the roadmap
3. Implement the fix for that specific task following Swift TDD and project standards
4. Run targeted tests for the specific component/test that was fixed using `swift test --filter [TestTargetName]`
5. If targeted tests pass, run the full test suite with `swift test --no-parallel` to ensure no regressions
6. Verify the task is fully complete and all tests pass with exit code 0
7. Update the roadmap status section with current progress and next steps
8. **Tag completed tasks with PR number** - Add commit SHA and PR number to completed tasks in roadmap
9. If this was a GitHub PR comment/check failure, resolve the relevant comment or check
10. Move to the next uncompleted task in the roadmap and repeat until all tasks are complete
11. Once all tasks are complete, commit changes and push to update the PR
12. **When PR is merged**, move the PullRequest$ARGUMENTSRoadmap.md file to CompletedRoadmaps/ directory
