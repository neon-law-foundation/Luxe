# Next Roadmap Phase

## Usage

```txt
/next-roadmap-phase ROADMAP_NAME
```

Where `ROADMAP_NAME` is the name of the roadmap file in the Roadmaps/ directory (e.g., `AuthRoadmap.md`,
`PostgresRoadmap.md`).

## Steps

Implement the next uncompleted phase in the Roadmaps/ROADMAP_NAME.md file. Follow these steps:

1. **IMPORTANT: Check current branch** - If not already on a branch named after the
   roadmap (not main), create one:
   - Run `git branch` to check current branch
   - If on main or not on roadmap-named branch, create with
     `git checkout -b roadmap/xxxxx-name`
2. Read the Roadmaps/ROADMAP_NAME.md file to understand the current status and identify
   the next uncompleted step
3. Mark the next step as in progress by changing `- [ ]` to `- [x]` if it's a simple phase,
   or break it into subtasks if complex
4. Implement the task following all quality guidelines including Swift TDD, testing
   requirements, and coding standards
5. **If any SQL files were edited, run `sqlfluff lint --dialect postgres .` and fix
   all issues before proceeding**
6. **MANDATORY: After each step Run the full test suite with `swift test --no-parallel` and ensure ALL tests pass
   with exit code 0 before marking any task complete**
7. **CRITICAL: If tests fail or hang, fix all issues before proceeding to next step**
8. Update the status section with the current phase, next steps, and last updated date
9. **MANDATORY: Run `swift test --no-parallel` again to ensure all tests pass with exit code 0 after roadmap updates**
10. **IMPORTANT: Create a commit following Conventional Commits format for the completed roadmap step**
11. **IMPORTANT: Each roadmap step must have its own commit after tests pass**
12. **IMPORTANT: Update the roadmap task with the first 12 characters of the commit SHA**
13. Continue with completed the next task until you have completed the entire phase.
