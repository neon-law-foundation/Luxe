# Create Roadmap

## Usage

```txt
/create-roadmap ROADMAP_NAME DESCRIPTION
```

Where `ROADMAP_NAME` is the name for the roadmap feature (e.g., `AuthRoadmap`, `PostgresRoadmap`).

Where `DESCRIPTION` is a brief description of the roadmap.

## Steps

Create a comprehensive GitHub issue with detailed implementation tasks and sample code. Follow these steps:

1. Ensure `Plan Mode` is enabled in Claude.
2. Analyze the current codebase and user requirements to identify all tasks that need completion
3. **Use the issue-creator agent** to create a GitHub issue with:
   - Title format: `[Roadmap] ROADMAP_NAME: DESCRIPTION`
   - Comprehensive task breakdown using `- [ ]` syntax for each task
   - **Sample code implementations** showing expected patterns
   - **Terse, technical syntax** for Swift developers
4. **ALWAYS include a status section** at the top with current phase, next steps,
   last updated date, and key decisions needed
5. **ALWAYS include explicit quality requirements** stating: "After completing
   each step, run `swift test --no-parallel` to ensure all tests pass with exit code 0. Review
   quality standards for adherence to project standards before marking any task complete."
6. **ALWAYS organize into phases** with Phase 1 being data layer (Palette migrations
   and Dali objects) if database changes are needed
7. Structure phases logically: Phase 0 (Research), Phase 1 (Data), Phase 2 (API/Backend), Phase 3 (Frontend),
   Phase 4+ (Features/Enhancements).
8. For the Research phase, include a task to create a file in the `Research/` folder with the name of the roadmap.
   Make this instruction explicit in the GitHub issue.
9. Organize tasks within phases into logical sections (e.g., Features, Bugs, Infrastructure, Documentation)
10. Write each task description in declarative active voice keeping lines under 120 characters
11. Include priority indicators for each task (High/Medium/Low) at the end of each checkbox item
12. **Include specific code samples** showing:
    - Package.swift dependency additions
    - Service implementations with proper Swift patterns
    - Test examples using Swift Testing framework
    - Migration patterns if database changes needed
13. **End each task description with**: "Run `swift test --no-parallel` and verify quality compliance before marking
    complete."
14. Ensure all task descriptions are specific, actionable, and follow the project's quality standards.
15. **Use terse, technical syntax** suitable for experienced Swift developers
16. Include commit SHA tracking in the issue template for implementation progress
