# Reset Main

## Usage

```txt
/reset-main
```

Reset local repository to clean main branch state and clean up merged PR roadmaps.
Follow these steps:

1. Switch to main branch: `git checkout main`
2. Pull latest changes: `git pull origin main`
3. Prune remote references: `git fetch origin --prune`
4. Delete all local branches except main: `git branch | grep -v 'main' | xargs git branch -D`
5. Check GitHub repo for closed/merged PRs using `gh pr list --state closed --limit 50`
