# Next Roadmap Step

## Usage

```txt
/next-roadmap-step ROADMAP_NAME
```

Where `ROADMAP_NAME` is the name of the roadmap file in the Roadmaps/ directory (e.g., `AuthRoadmap.md`,
`PostgresRoadmap.md`).

## Steps

Implement the next uncompleted step in the Roadmaps/ROADMAP_NAME.md file. Follow these steps:

1. **IMPORTANT: Check current branch** - If not already on a branch named after the
   roadmap (not main), create one:
   - Run `git branch` to check current branch
   - If on main or not on roadmap-named branch, create with
     `git checkout -b roadmap/xxxxx-name`
2. Read the Roadmaps/ROADMAP_NAME.md file to understand the current status and identify
   the next uncompleted step
3. Mark the next step as in progress by changing `- [ ]` to `- [x]` if it's a simple step,
   or break it into subtasks if complex
4. Implement the task following all quality guidelines including Swift TDD, testing
   requirements, and coding standards
5. If any Research was performed, add a brief description of the findings beneath the task in the roadmap. Be mindful to
   indent the research under the first non-bullet character.
6. **If any SQL files were edited, run `sqlfluff lint --dialect postgres .` and fix
   all issues before proceeding**
7. **MANDATORY: Run the full test suite with `swift test --no-parallel` and ensure ALL tests pass
   with exit code 0 before marking any task complete**
8. **CRITICAL: If tests fail or hang, fix all issues before proceeding to next step**
9. Mark the task as completed by ensuring the checkbox shows `- [x]` in the roadmap
10. Update the status section with the current phase, next steps, and last updated date. Always add what you changed to
    the next line, do not add copy to the current line of the task. Never update the roadmap if there are empty check
    lists.
11. **MANDATORY: Run `swift test --no-parallel` again to ensure all tests pass with exit code 0 after roadmap updates**
12. **IMPORTANT: Create a commit following Conventional Commits format for the completed roadmap step**
13. **IMPORTANT: Each roadmap step must have its own commit after tests pass**
14. **IMPORTANT: Update the roadmap task with the first 12 characters of the commit SHA in the form of (SHA)**
