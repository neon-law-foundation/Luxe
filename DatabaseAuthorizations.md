# PostgreSQL Role-Based CRUD Permissions Analysis

This document shows the CRUD (Create, Read, Update, Delete) permissions for each role in the Luxe application.

| Role | Table | Create | Read | Update | Delete | Notes |
|------|-------|---------|------|---------|---------|-------|
| customer | auth.users | ❌ | ✅ | ❌ | ❌ | RLS: Own record only |
| customer | directory.people | ❌ | ✅ | ❌ | ❌ | Linked to user records |
| customer | mail.threads | ❌ | ✅ | ❌ | ❌ |  |
