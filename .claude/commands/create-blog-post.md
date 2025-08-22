# Create Blog Post

## Usage

```txt
/create-blog-post [Summary]
```

## Description

Create a new blog post in Markdown with proper frontmatter. Follow these steps:

1. Create a new markdown file in `Sources/Bazaar/Markdown/` with a descriptive filename (e.g.,
   `new-feature-announcement.md`). **MANDATORY** always use lower kebab case.
2. Add YAML frontmatter with title, slug, description, and created_at
   (use current timestamp in ISO8601 format).
3. Write the blog post content in Markdown with a clear title and engaging content. Write persuasive and warm.
4. Include a "Created at" timestamp at the bottom in the format "*Created at: Month Day, Year*".
5. The blog post will automatically appear on the blog index page sorted by creation date (most recent first).
6. Ensure the slug in frontmatter matches the intended URL path for the blog post.
7. Run ./scripts/format-markdown.sh to format the markdown file and fix any changes.
