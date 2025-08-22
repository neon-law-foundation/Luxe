# Create Roadmap

## Usage

```txt
/create-roadmap ROADMAP_NAME DESCRIPTION
```

Where `ROADMAP_NAME` is the name for the new roadmap file (e.g., `AuthRoadmap`, `PostgresRoadmap`). The `.md` extension
will be added automatically.

Where `DESCRIPTION` is a brief description of the roadmap.

## Steps

Create a detailed list of uncompleted checkmarks for tracking progress. Follow these steps:

1. Ensure `Plan Mode` is enabled in Claude.
2. Analyze the current codebase and user requirements to identify all tasks that need completion
3. Create a markdown file with uncompleted checkboxes using `- [ ]` syntax for each task
4. **ALWAYS include a status section** at the top with current phase, next steps,
   last updated date, and key decisions needed
5. **ALWAYS include explicit quality requirements** at the top stating: "After completing
   each step, run `swift test --no-parallel` to ensure all tests pass with exit code 0. Review
   quality standards for adherence to project standards before marking any task complete."
6. **ALWAYS organize into phases** with Phase 1 being data layer (Palette migrations
   and Dali objects) if database changes are needed
7. Structure phases logically: Phase 0 (Research), Phase 1 (Data), Phase 2 (API/Backend), Phase 3 (Frontend),
   Phase 4+ (Features/Enhancements).
8. For the Research phase, add a file to the `Research/` folder with the name of the roadmap. Make this instruction
   explicit in the roadmap file. After writing markdown files, run the `/format-markdown` Claude command to ensure the
   markdown is formatted correctly.
9. Organize tasks within phases into logical sections (e.g., Features, Bugs, Infrastructure, Documentation)
10. Write each task description in declarative active voice keeping lines under 120 characters
11. Include priority indicators for each task (High/Medium/Low) at the end of each checkbox item
12. **End each task description with**: "Run `swift test --no-parallel` and verify quality compliance before marking
   complete."
13. Ensure all task descriptions are specific, actionable, and follow the project's quality standards.
14. Review the roadmap for completeness, ensuring no critical tasks are missing.
15. Place the roadmap file in the `Roadmaps/` folder with PascalCase naming convention (e.g.,
   `Roadmaps/FeatureRoadmap.md`).
16. Run the `/format-markdown` Claude command to ensure the markdown is formatted correctly.
