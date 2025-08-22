# Lint SQL

## Usage

```txt
/lint-sql
```

After editing any SQL file, run `sqlfluff lint --dialect postgres .` to check formatting and
fix all issues. Follow these steps:

1. Run `sqlfluff lint --dialect postgres .` to identify formatting issues
2. Fix any issues reported by sqlfluff (lines must be 120 characters or less)
3. Re-run `sqlfluff lint --dialect postgres .` to ensure all issues are resolved
4. Only proceed with other steps after SQL linting passes successfully
