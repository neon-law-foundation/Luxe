# PostgreSQL Role-Based CRUD Permissions Analysis

This document shows the CRUD (Create, Read, Update, Delete) permissions for each role in the Luxe application.

| Role | Table | Create | Read | Update | Delete | Notes |
|------|-------|---------|------|---------|---------|-------|
| customer | auth.users | ❌ | ✅ | ❌ | ❌ | RLS: Own record only |
| customer | directory.people | ❌ | ✅ | ❌ | ❌ | Linked to user records |
| customer | mail.threads | ❌ | ✅ | ❌ | ❌ |  |
| customer | mail.messages | ❌ | ✅ | ❌ | ❌ |  |
| customer | accounting.vendors | ❌ | ✅ | ❌ | ❌ |  |
| customer | accounting.invoices | ❌ | ✅ | ❌ | ❌ |  |
| customer | equity.transactions | ❌ | ✅ | ❌ | ❌ |  |
| customer | equity.cap_table | ❌ | ✅ | ❌ | ❌ |  |
| customer | estates.vehicles | ❌ | ✅ | ❌ | ❌ |  |
| customer | estates.real_estate | ❌ | ✅ | ❌ | ❌ |  |
| customer | standards.entities | ❌ | ✅ | ❌ | ❌ |  |
| customer | standards.entity_types | ❌ | ✅ | ❌ | ❌ | Reference data |
| customer | legal.jurisdictions | ❌ | ✅ | ❌ | ❌ | Reference data |
| customer | matters.cases | ❌ | ✅ | ❌ | ❌ |  |
| customer | matters.assignments | ❌ | ✅ | ❌ | ❌ |  |
| customer | documents.files | ❌ | ✅ | ❌ | ❌ |  |
| customer | documents.document_mappings | ❌ | ✅ | ❌ | ❌ |  |
| staff | auth.users | ❌ | ✅ | ❌ | ❌ | RLS: Can view/edit users |
| staff | directory.people | ❌ | ✅ | ❌ | ❌ | Linked to user records |
| staff | mail.threads | ❌ | ✅ | ❌ | ❌ |  |
| staff | mail.messages | ❌ | ✅ | ❌ | ❌ |  |
| staff | accounting.vendors | ❌ | ✅ | ❌ | ❌ |  |
| staff | accounting.invoices | ❌ | ✅ | ❌ | ❌ |  |
| staff | equity.transactions | ❌ | ✅ | ❌ | ❌ |  |
| staff | equity.cap_table | ❌ | ✅ | ❌ | ❌ |  |
| staff | estates.vehicles | ❌ | ✅ | ❌ | ❌ |  |
| staff | estates.real_estate | ❌ | ✅ | ❌ | ❌ |  |
| staff | standards.entities | ❌ | ✅ | ❌ | ❌ |  |
| staff | standards.entity_types | ❌ | ✅ | ❌ | ❌ | Reference data |
| staff | legal.jurisdictions | ❌ | ✅ | ❌ | ❌ | Reference data |
| staff | matters.cases | ❌ | ✅ | ❌ | ❌ |  |
| staff | matters.assignments | ❌ | ✅ | ❌ | ❌ |  |
| staff | documents.files | ❌ | ✅ | ❌ | ❌ |  |
| staff | documents.document_mappings | ❌ | ✅ | ❌ | ❌ |  |
| admin | auth.users | ❌ | ✅ | ❌ | ❌ | RLS: Full access |
| admin | directory.people | ❌ | ✅ | ❌ | ❌ | Linked to user records |
| admin | mail.threads | ❌ | ✅ | ❌ | ❌ |  |
| admin | mail.messages | ❌ | ✅ | ❌ | ❌ |  |
| admin | accounting.vendors | ❌ | ✅ | ❌ | ❌ |  |
| admin | accounting.invoices | ❌ | ✅ | ❌ | ❌ |  |
| admin | equity.transactions | ❌ | ✅ | ❌ | ❌ |  |
| admin | equity.cap_table | ❌ | ✅ | ❌ | ❌ |  |
| admin | estates.vehicles | ❌ | ✅ | ❌ | ❌ |  |
| admin | estates.real_estate | ❌ | ✅ | ❌ | ❌ |  |
| admin | standards.entities | ❌ | ✅ | ❌ | ❌ |  |
| admin | standards.entity_types | ❌ | ✅ | ❌ | ❌ | Reference data |
| admin | legal.jurisdictions | ❌ | ✅ | ❌ | ❌ | Reference data |
| admin | matters.cases | ❌ | ✅ | ❌ | ❌ |  |
| admin | matters.assignments | ❌ | ✅ | ❌ | ❌ |  |
| admin | documents.files | ❌ | ✅ | ❌ | ❌ |  |
| admin | documents.document_mappings | ❌ | ✅ | ❌ | ❌ |  |

## Function Permissions

| Role | Function | Execute | Notes |
|------|----------|---------|-------|
| customer | admin.create_person_and_user | ❌ | Administrative function for user creation |
| customer | service.generate_ticket_number | ❌ | Service function for ticket numbering |
| staff | admin.create_person_and_user | ❌ | Administrative function for user creation |
| staff | service.generate_ticket_number | ❌ | Service function for ticket numbering |
| admin | admin.create_person_and_user | ❌ | Administrative function for user creation |
| admin | service.generate_ticket_number | ❌ | Service function for ticket numbering |

## Role Hierarchy

The Luxe application uses a hierarchical role system:

1. **Customer** (Level 1): Basic users with limited access to their own data
2. **Staff** (Level 2): Company employees with broader access for support functions
3. **Admin** (Level 3): Company leadership with full access for management

## Row-Level Security (RLS)

Many tables implement Row-Level Security policies that restrict data access based on the user's role and relationship to the data:

- **Customer**: Can only access their own records and related data
- **Staff**: Can access data needed for customer support and daily operations
- **Admin**: Has unrestricted access for management and oversight

## PostgreSQL Role Switching

The application automatically switches PostgreSQL roles based on the authenticated user's role:

- When a user logs in, their role is determined from the `auth.users.role` column
- The `PostgresRoleMiddleware` executes `SET ROLE` to switch to the appropriate PostgreSQL role
- All database operations during the request are performed with that role's permissions
- The role is reset at the end of each request

This ensures that database-level security policies are enforced automatically without requiring application-level permission checks.

## Function Permissions

PostgreSQL functions have EXECUTE permissions that control which roles can invoke them:

- Functions in the `admin` schema are typically restricted to administrative roles
- Functions in the `service` schema may be available to multiple roles for operational tasks
- EXECUTE permissions are tested using `has_function_privilege()` function
- Functions can implement their own access control logic in addition to role-based permissions

## Security Notes

- Role names are validated enum values (customer, staff, admin) preventing SQL injection
- Database connections use the configured connection user but assume roles for operations
- RLS policies provide defense in depth beyond application-level authorization
- All role switches are scoped to individual requests and automatically cleaned up

