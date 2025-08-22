#!/bin/bash

set -e

echo "🔧 Visualizing PostgreSQL Database Structure and Permissions"
echo "============================================================"
echo ""

# Set up Swift environment if using Swiftly
if [[ "$(id -un)" == 'root' ]]; then
  [ -f /root/.local/share/swiftly/env.sh ] && . /root/.local/share/swiftly/env.sh
else
  [ -f "${HOME}/.local/share/swiftly/env.sh" ] && . "${HOME}/.local/share/swiftly/env.sh"
fi

# Set XDG config directory to avoid path expansion issues
export XDG_CONFIG_HOME="${HOME}/.config"
mkdir -p "${XDG_CONFIG_HOME}"

echo "📊 Running Palette migrate to ensure database is current..."
swift run Palette migrate
echo ""

# ============================================================================
# Part 1: Generate Entity Relationship Diagram (ERD)
# ============================================================================

echo "📈 Generating Entity Relationship Diagram (ERD)"
echo "==============================================="
echo ""

CONNECTION_URL=postgres://postgres@127.0.0.1:5432/luxe
docker exec $(docker ps -q --filter "name=postgres") pg_dump -U postgres -d luxe --schema-only > schema.sql
SCHEMA_FILE="schema.sql"
OUTPUT_FILE="schema.svg"

# Step 2: Generate ERD using Graphviz
INPUT_FILE=$SCHEMA_FILE
OUTPUT_FILE="schema.dot"

# initialize the .dot file
echo "digraph G {" > $OUTPUT_FILE
echo "    rankdir=LR;" >> $OUTPUT_FILE
echo "    node [shape=record];" >> $OUTPUT_FILE

# Extract tables and their columns
echo "Parsing tables..."
gawk '
/CREATE TABLE/ {
  gsub("\\(", "", $3);
  table_name = $3;
  # Replace dots with double underscores in table names
  gsub("\\.", "__", table_name);
  printf("    %s [label=\"{%s|", table_name, table_name);
  inside_table = 1;
  next;
}

/);/ && inside_table {
  printf("}\"];\n");
  inside_table = 0;
  next;
}

inside_table {
  gsub(",", "");
  split($0, column_parts, " ");
  column_name = column_parts[1];
  column_type = column_parts[2];
  # Remove quotes from column names
  gsub("\"", "", column_name);
  printf("%s: %s\\l", column_name, column_type);
}
' $INPUT_FILE >> $OUTPUT_FILE

# Extract foreign keys and relationships
echo "Parsing foreign keys..."
gawk '
/ALTER TABLE/ {
    current_line = $0; next
}
/FOREIGN KEY/ {
    full_line = current_line " " $0;
    match(full_line, /ALTER TABLE ONLY ([^ ]+)/, table_match);
    match(full_line, /FOREIGN KEY \(([^)]+)\)/, column_match);
    match(full_line, /REFERENCES ([^.]+\.([^ ]+))\(([^)]+)\)/, ref_match);
    ref_table = ref_match[1];
    table = table_match[1];
    # Replace dots with double underscores in both table names
    gsub("\\.", "__", ref_table);
    gsub("\\.", "__", table);
    column = column_match[1];
    ref_column = ref_match[2];
    printf("    %s -> %s [label=\"%s\"];\n", table, ref_table, column);
}
' $INPUT_FILE >> $OUTPUT_FILE

# Close the .dot file
echo "}" >> $OUTPUT_FILE

echo "Generated $OUTPUT_FILE"

# Remove "public." from the schema.dot file
sed -i '' 's/public\.//g' schema.dot

# Replace "only" with only without the quotes in the schema.dot file
sed -i '' 's/"only"/only/g' schema.dot

# Generate the ERD using Graphviz
dot -Tpng schema.dot -o schema.png

echo "✅ ERD generated successfully as schema.png"
echo ""

# ============================================================================
# Part 2: Analyze PostgreSQL Role-Based CRUD Permissions
# ============================================================================

echo "🔍 Analyzing PostgreSQL Role-Based CRUD Permissions"
echo "=================================================="
echo ""

# Define the roles to test
ROLES=("customer" "staff" "admin")

# Define test tables to check permissions on
TABLES=("auth.users" "directory.people" "mail.threads" "mail.messages" "accounting.vendors" "accounting.invoices" "equity.transactions" "equity.cap_table" "estates.vehicles" "estates.real_estate" "standards.entities" "standards.entity_types" "legal.jurisdictions" "matters.cases" "matters.assignments" "documents.files" "documents.document_mappings")

# Define functions to check permissions on (excluding built-in citext and trigger functions)
FUNCTIONS=("admin.create_person_and_user" "service.generate_ticket_number")

# Create output file
OUTPUT_FILE="DatabaseAuthorizations.md"
echo "# PostgreSQL Role-Based CRUD Permissions Analysis" > $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "This document shows the CRUD (Create, Read, Update, Delete) permissions for each role in the Luxe application." >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Create a temporary SQL file for testing permissions
TEMP_SQL_FILE=$(mktemp)

echo "| Role | Table | Create | Read | Update | Delete | Notes |" >> $OUTPUT_FILE
echo "|------|-------|---------|------|---------|---------|-------|" >> $OUTPUT_FILE

for role in "${ROLES[@]}"; do
    echo "🔐 Testing permissions for role: $role"

    for table in "${TABLES[@]}"; do
        echo -n "  Testing $table... "

        # Initialize permission flags
        CREATE_PERM="❌"
        READ_PERM="❌"
        UPDATE_PERM="❌"
        DELETE_PERM="❌"
        NOTES=""

        # Test READ permission
        cat > $TEMP_SQL_FILE << EOF
SET ROLE $role;
SELECT COUNT(*) FROM $table LIMIT 1;
RESET ROLE;
EOF

        if docker exec $(docker ps -q --filter "name=postgres") psql -U postgres -d luxe -f - < $TEMP_SQL_FILE > /dev/null 2>&1; then
            READ_PERM="✅"
        fi

        # Test INSERT permission (using a safe test that won't actually insert)
        cat > $TEMP_SQL_FILE << EOF
SET ROLE $role;
SELECT has_table_privilege('$role', '$table', 'INSERT');
RESET ROLE;
EOF

        RESULT=$(docker exec $(docker ps -q --filter "name=postgres") psql -U postgres -d luxe -f - < $TEMP_SQL_FILE 2>/dev/null | grep -E "^[[:space:]]*[tf]" | tr -d '[:space:]' || echo "f")
        if [ "$RESULT" = "t" ]; then
            CREATE_PERM="✅"
        fi

        # Test UPDATE permission
        cat > $TEMP_SQL_FILE << EOF
SET ROLE $role;
SELECT has_table_privilege('$role', '$table', 'UPDATE');
RESET ROLE;
EOF

        RESULT=$(docker exec $(docker ps -q --filter "name=postgres") psql -U postgres -d luxe -f - < $TEMP_SQL_FILE 2>/dev/null | grep -E "^[[:space:]]*[tf]" | tr -d '[:space:]' || echo "f")
        if [ "$RESULT" = "t" ]; then
            UPDATE_PERM="✅"
        fi

        # Test DELETE permission
        cat > $TEMP_SQL_FILE << EOF
SET ROLE $role;
SELECT has_table_privilege('$role', '$table', 'DELETE');
RESET ROLE;
EOF

        RESULT=$(docker exec $(docker ps -q --filter "name=postgres") psql -U postgres -d luxe -f - < $TEMP_SQL_FILE 2>/dev/null | grep -E "^[[:space:]]*[tf]" | tr -d '[:space:]' || echo "f")
        if [ "$RESULT" = "t" ]; then
            DELETE_PERM="✅"
        fi

        # Add special notes for certain tables
        case $table in
            "auth.users")
                if [ "$role" = "customer" ]; then
                    NOTES="RLS: Own record only"
                elif [ "$role" = "staff" ]; then
                    NOTES="RLS: Can view/edit users"
                else
                    NOTES="RLS: Full access"
                fi
                ;;
            "directory.people")
                NOTES="Linked to user records"
                ;;
            "legal.jurisdictions")
                NOTES="Reference data"
                ;;
            "standards.entity_types")
                NOTES="Reference data"
                ;;
        esac

        # Write to markdown table
        echo "| $role | $table | $CREATE_PERM | $READ_PERM | $UPDATE_PERM | $DELETE_PERM | $NOTES |" >> $OUTPUT_FILE

        echo "done"
    done
    echo ""
done

echo ""
echo "🔧 Analyzing Function Permissions"
echo "=================================="
echo ""

# Add function permissions table header
echo "" >> $OUTPUT_FILE
echo "## Function Permissions" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "| Role | Function | Execute | Notes |" >> $OUTPUT_FILE
echo "|------|----------|---------|-------|" >> $OUTPUT_FILE

for role in "${ROLES[@]}"; do
    echo "🔐 Testing function permissions for role: $role"

    for function in "${FUNCTIONS[@]}"; do
        echo -n "  Testing $function... "

        # Initialize permission flag
        EXECUTE_PERM="❌"
        NOTES=""

        # Test EXECUTE permission
        cat > $TEMP_SQL_FILE << EOF
SET ROLE $role;
SELECT has_function_privilege('$role', '$function', 'EXECUTE');
RESET ROLE;
EOF

        RESULT=$(docker exec $(docker ps -q --filter "name=postgres") psql -U postgres -d luxe -f - < $TEMP_SQL_FILE 2>/dev/null | grep -E "^[[:space:]]*[tf]" | tr -d '[:space:]' || echo "f")
        if [ "$RESULT" = "t" ]; then
            EXECUTE_PERM="✅"
        fi

        # Add special notes for certain functions
        case $function in
            "admin.create_person_and_user")
                NOTES="Administrative function for user creation"
                ;;
            "service.generate_ticket_number")
                NOTES="Service function for ticket numbering"
                ;;
        esac

        # Write to markdown table
        echo "| $role | $function | $EXECUTE_PERM | $NOTES |" >> $OUTPUT_FILE

        echo "done"
    done
    echo ""
done

# Add role hierarchy explanation
cat >> $OUTPUT_FILE << EOF

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

- When a user logs in, their role is determined from the \`auth.users.role\` column
- The \`PostgresRoleMiddleware\` executes \`SET ROLE\` to switch to the appropriate PostgreSQL role
- All database operations during the request are performed with that role's permissions
- The role is reset at the end of each request

This ensures that database-level security policies are enforced automatically without requiring application-level permission checks.

## Function Permissions

PostgreSQL functions have EXECUTE permissions that control which roles can invoke them:

- Functions in the \`admin\` schema are typically restricted to administrative roles
- Functions in the \`service\` schema may be available to multiple roles for operational tasks
- EXECUTE permissions are tested using \`has_function_privilege()\` function
- Functions can implement their own access control logic in addition to role-based permissions

## Security Notes

- Role names are validated enum values (customer, staff, admin) preventing SQL injection
- Database connections use the configured connection user but assume roles for operations
- RLS policies provide defense in depth beyond application-level authorization
- All role switches are scoped to individual requests and automatically cleaned up

EOF

# Clean up
rm -f $TEMP_SQL_FILE

echo "✅ PostgreSQL visualization complete!"
echo ""
echo "📊 Generated outputs:"
echo "  • schema.sql: Database schema dump"
echo "  • schema.dot: Graphviz diagram definition"
echo "  • schema.png: Entity Relationship Diagram"
echo "  • $OUTPUT_FILE: Role permissions analysis"
echo ""
echo "📈 Summary of analysis:"
echo "  • Analyzed $(echo "${ROLES[@]}" | wc -w) roles: ${ROLES[*]}"
echo "  • Tested $(echo "${TABLES[@]}" | wc -w) tables across all schemas"
echo "  • Tested $(echo "${FUNCTIONS[@]}" | wc -w) custom functions"
echo "  • Generated ERD with table relationships"
echo ""
echo "🔍 To view the outputs:"
echo "  open schema.png           # View ERD"
echo "  cat $OUTPUT_FILE         # View permissions analysis"
echo ""
echo "📈 To regenerate after schema changes:"
echo "  ./scripts/visualize-postgres.sh"