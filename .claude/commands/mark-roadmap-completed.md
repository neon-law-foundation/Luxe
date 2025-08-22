# Mark Roadmap Completed

## Usage

```txt
/mark-roadmap-completed ROADMAP_NAME
```

## Steps

1. Move the roadmap file with timestamp:
   `mv Roadmaps/ROADMAP_NAME.md CompletedRoadmaps/YYYYMMDD-ROADMAP_NAME.md`
2. Use the current date in YYYYMMDD format (e.g., 20250801 for August 1, 2025)
3. Commit the move:
   `git add . && git commit -m "docs(roadmap): mark ROADMAP_NAME roadmap as completed"`
