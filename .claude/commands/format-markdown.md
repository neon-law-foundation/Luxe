# Format Markdown

## Usage

```txt
/format-markdown
```

Format markdown files or those ending in `.md` with these steps.

1. Run `./scripts/validate-markdown.sh --fix`.
2. Fix any issues except for `MD013` line length issues.
3. Re-run `./scripts/validate-markdown.sh` to ensure all non-line length issues are fixed. Confirm with the developer if
   you are unsure how to fix an issue.
4. Note all of the `MD013` line length issues.
5. Now, fix line-length issues. Ensure that multi-line lists begin with the same indentation as the first non-list
   character. Ensure that every line is as close to 120 characters as possible without exceeding it.
6. Confirm that all markdown files are formatted correctly by running `./scripts/validate-markdown.sh`. **MANDATORY**
   this must exit 0.
