# Prod Login

## Usage

```txt
/prod-login
```

Navigate to <www.sagebrush.services> and log in with the following steps:

1. Use the playwright MCP server to navigate to <www.sagebrush.services>
2. Click the "Log in" button
3. On the Cognito page, enter username: `admin@neonlaw.com`
4. Enter password: noqvEf-povsu3-temjog
5. Press Sign In
6. Note: This hardcoded password is acceptable as the application is still in
   development
7. Query production database: Use `swift run Vegas elephants -i` for interactive
   PostgreSQL session
