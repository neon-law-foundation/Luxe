--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (Debian 17.5-1.pgdg120+1)
-- Dumped by pg_dump version 17.5 (Debian 17.5-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: accounting; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA accounting;


ALTER SCHEMA accounting OWNER TO postgres;

--
-- Name: admin; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA admin;


ALTER SCHEMA admin OWNER TO postgres;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA auth;


ALTER SCHEMA auth OWNER TO postgres;

--
-- Name: directory; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA directory;


ALTER SCHEMA directory OWNER TO postgres;

--
-- Name: documents; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA documents;


ALTER SCHEMA documents OWNER TO postgres;

--
-- Name: equity; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA equity;


ALTER SCHEMA equity OWNER TO postgres;

--
-- Name: estates; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA estates;


ALTER SCHEMA estates OWNER TO postgres;

--
-- Name: ethereal; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ethereal;


ALTER SCHEMA ethereal OWNER TO postgres;

--
-- Name: SCHEMA ethereal; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA ethereal IS 'Schema for astrocartography, birth charts, and astrological data';


--
-- Name: legal; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA legal;


ALTER SCHEMA legal OWNER TO postgres;

--
-- Name: mail; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA mail;


ALTER SCHEMA mail OWNER TO postgres;

--
-- Name: marketing; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA marketing;


ALTER SCHEMA marketing OWNER TO postgres;

--
-- Name: SCHEMA marketing; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA marketing IS 'Schema for newsletter management and marketing communications';


--
-- Name: matters; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA matters;


ALTER SCHEMA matters OWNER TO postgres;

--
-- Name: SCHEMA matters; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA matters IS 'Schema for legal matters including projects, assigned notations, and disclosures';


--
-- Name: service; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA service;


ALTER SCHEMA service OWNER TO postgres;

--
-- Name: SCHEMA service; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA service IS 'Schema for customer service ticket management and support';


--
-- Name: standards; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA standards;


ALTER SCHEMA standards OWNER TO postgres;

--
-- Name: SCHEMA standards; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA standards IS 'Standards schema with USAGE permissions for all roles';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_stat_statements IS 'Track execution statistics of SQL statements';


--
-- Name: person_entity_role_type; Type: TYPE; Schema: auth; Owner: postgres
--

CREATE TYPE auth.person_entity_role_type AS ENUM (
    'owner',
    'admin',
    'staff'
);


ALTER TYPE auth.person_entity_role_type OWNER TO postgres;

--
-- Name: TYPE person_entity_role_type; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON TYPE auth.person_entity_role_type IS 'Role types for person-entity relationships: owner (full control), admin (management access), staff (limited access)';


--
-- Name: user_role; Type: TYPE; Schema: auth; Owner: postgres
--

CREATE TYPE auth.user_role AS ENUM (
    'customer',
    'staff',
    'admin'
);


ALTER TYPE auth.user_role OWNER TO postgres;

--
-- Name: jurisdiction_type; Type: TYPE; Schema: legal; Owner: postgres
--

CREATE TYPE legal.jurisdiction_type AS ENUM (
    'city',
    'county',
    'state',
    'country'
);


ALTER TYPE legal.jurisdiction_type OWNER TO postgres;

--
-- Name: TYPE jurisdiction_type; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON TYPE legal.jurisdiction_type IS 'Type of legal jurisdiction: city, county, state, or country';


--
-- Name: aggregate_statement_stats_hourly(); Type: FUNCTION; Schema: admin; Owner: postgres
--

CREATE FUNCTION admin.aggregate_statement_stats_hourly() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    rows_inserted INTEGER := 0;
    current_hour TIMESTAMP;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    -- Calculate the current hour boundary (truncate to hour)
    current_hour := date_trunc('hour', NOW() - INTERVAL '1 hour');
    start_time := current_hour;
    end_time := current_hour + INTERVAL '1 hour';
    
    -- Delete existing aggregations for this hour to avoid duplicates
    DELETE FROM statement_stats_hourly 
    WHERE hour = current_hour;
    
    -- Insert aggregated hourly data from statement_stats
    INSERT INTO statement_stats_hourly (
        id,
        hour,
        query_id,
        query_text,
        total_calls,
        avg_exec_time,
        total_rows,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid() AS id,
        current_hour AS hour,
        query_id,
        query_text,
        SUM(calls) AS total_calls,
        AVG(mean_exec_time) AS avg_exec_time,
        SUM(rows) AS total_rows,
        NOW() AS created_at,
        NOW() AS updated_at
    FROM statement_stats
    WHERE snapshot_at >= start_time
    AND snapshot_at < end_time
    AND query_id IS NOT NULL
    GROUP BY query_id, query_text
    HAVING SUM(calls) > 0;
    
    GET DIAGNOSTICS rows_inserted = ROW_COUNT;
    
    -- Log the aggregation operation
    RAISE NOTICE 'Aggregated % hourly statistics for hour %', rows_inserted, current_hour;
    
    RETURN rows_inserted;
END;
$$;


ALTER FUNCTION admin.aggregate_statement_stats_hourly() OWNER TO postgres;

--
-- Name: FUNCTION aggregate_statement_stats_hourly(); Type: COMMENT; Schema: admin; Owner: postgres
--

COMMENT ON FUNCTION admin.aggregate_statement_stats_hourly() IS 'Aggregates statement_stats data into hourly summaries in statement_stats_hourly table';


--
-- Name: capture_statement_stats(); Type: FUNCTION; Schema: admin; Owner: postgres
--

CREATE FUNCTION admin.capture_statement_stats() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    rows_inserted INTEGER := 0;
    current_snapshot TIMESTAMP := NOW();
BEGIN
    -- Insert current pg_stat_statements data into statement_stats table
    -- Only capture statements that have been executed since last snapshot
    INSERT INTO statement_stats (
        id,
        query_id,
        query_text,
        calls,
        total_exec_time,
        mean_exec_time,
        rows,
        shared_blks_hit,
        shared_blks_read,
        temp_blks_read,
        temp_blks_written,
        snapshot_at,
        created_at,
        updated_at
    )
    SELECT
        gen_random_uuid() AS id,
        s.queryid AS query_id,
        s.query AS query_text,
        s.calls,
        s.total_exec_time,
        s.mean_exec_time,
        s.rows,
        s.shared_blks_hit,
        s.shared_blks_read,
        s.temp_blks_read,
        s.temp_blks_written,
        current_snapshot AS snapshot_at,
        current_snapshot AS created_at,
        current_snapshot AS updated_at
    FROM pg_stat_statements s
    WHERE s.calls > 0
    AND s.queryid IS NOT NULL
    AND s.query IS NOT NULL
    -- Avoid capturing statements that are too short or administrative
    AND LENGTH(s.query) > 10
    AND s.query NOT LIKE 'SET %'
    AND s.query NOT LIKE 'SHOW %'
    AND s.query NOT LIKE 'BEGIN%'
    AND s.query NOT LIKE 'COMMIT%'
    AND s.query NOT LIKE 'ROLLBACK%';

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    -- Log the snapshot operation
    RAISE NOTICE 'Captured % statement statistics at %', rows_inserted, current_snapshot;

    RETURN rows_inserted;
END;
$$;


ALTER FUNCTION admin.capture_statement_stats() OWNER TO postgres;

--
-- Name: FUNCTION capture_statement_stats(); Type: COMMENT; Schema: admin; Owner: postgres
--

COMMENT ON FUNCTION admin.capture_statement_stats() IS 'Captures current pg_stat_statements data into statement_stats table for historical analysis';


--
-- Name: create_person_and_user(character varying, public.citext, character varying, auth.user_role); Type: FUNCTION; Schema: admin; Owner: postgres
--

CREATE FUNCTION admin.create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role DEFAULT 'customer'::auth.user_role) RETURNS TABLE(person_id uuid, user_id uuid, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    v_person_id uuid;
    v_user_id uuid;
    v_created_at timestamp with time zone;
BEGIN
    -- Check if the current user has admin role
    -- current_setting with true parameter returns empty string if not set
    IF COALESCE(NULLIF(current_setting('app.current_user_role', true), ''), 'none') != 'admin' THEN
        RAISE EXCEPTION 'Access denied: Only admin users can create new users and people';
    END IF;
    
    -- Validate input parameters
    IF p_name IS NULL OR LENGTH(TRIM(p_name)) = 0 THEN
        RAISE EXCEPTION 'Name cannot be empty';
    END IF;
    
    IF p_email IS NULL OR LENGTH(TRIM(p_email)) = 0 THEN
        RAISE EXCEPTION 'Email cannot be empty';
    END IF;
    
    IF p_username IS NULL OR LENGTH(TRIM(p_username)) = 0 THEN
        RAISE EXCEPTION 'Username cannot be empty';
    END IF;
    
    -- Check for email format validation
    IF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format';
    END IF;
    
    -- Check if person with this email already exists
    IF EXISTS (SELECT 1 FROM directory.people WHERE email = p_email) THEN
        RAISE EXCEPTION 'Person with email % already exists', p_email;
    END IF;
    
    -- Check if user with this username already exists
    IF EXISTS (SELECT 1 FROM auth.users WHERE username = p_username) THEN
        RAISE EXCEPTION 'User with username % already exists', p_username;
    END IF;
    
    -- Get current timestamp for consistency
    v_created_at := CURRENT_TIMESTAMP;
    
    -- Start transaction (function is already in a transaction)
    
    -- Create person record
    INSERT INTO directory.people (name, email, created_at, updated_at)
    VALUES (TRIM(p_name), LOWER(TRIM(p_email)), v_created_at, v_created_at)
    RETURNING id INTO v_person_id;
    
    -- Create user record with reference to person
    INSERT INTO auth.users (username, person_id, role, created_at, updated_at)
    VALUES (LOWER(TRIM(p_username)), v_person_id, p_role, v_created_at, v_created_at)
    RETURNING id INTO v_user_id;
    
    -- Return the created IDs and timestamp
    RETURN QUERY SELECT v_person_id, v_user_id, v_created_at;
END;
$_$;


ALTER FUNCTION admin.create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role) OWNER TO postgres;

--
-- Name: FUNCTION create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role); Type: COMMENT; Schema: admin; Owner: postgres
--

COMMENT ON FUNCTION admin.create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role) IS 'Creates a person and user record atomically. Only accessible to admin users. Links person and user via email/username matching.';


--
-- Name: extract_table_usage_stats(); Type: FUNCTION; Schema: admin; Owner: postgres
--

CREATE FUNCTION admin.extract_table_usage_stats() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
DECLARE
    rows_processed INTEGER := 0;
    current_snapshot TIMESTAMP := NOW();
    query_record RECORD;
    table_pattern TEXT;
    matched_table TEXT;
    matched_schema TEXT;
BEGIN
    -- Clear existing stats for this snapshot to avoid duplicates
    DELETE FROM table_usage_stats 
    WHERE snapshot_at = date_trunc('hour', current_snapshot);
    
    -- Process each unique query from recent statement stats
    FOR query_record IN 
        SELECT DISTINCT query_text 
        FROM statement_stats 
        WHERE snapshot_at >= current_snapshot - INTERVAL '1 hour'
        AND query_text IS NOT NULL
        AND LENGTH(query_text) > 10
    LOOP
        -- Extract table references using regex patterns
        -- Pattern for schema.table format
        FOR matched_schema, matched_table IN
            SELECT 
                (regexp_matches(query_record.query_text, '(?:FROM|JOIN|UPDATE|INSERT INTO|DELETE FROM)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\.\s*([a-zA-Z_][a-zA-Z0-9_]*)', 'gi'))[1] AS schema_name,
                (regexp_matches(query_record.query_text, '(?:FROM|JOIN|UPDATE|INSERT INTO|DELETE FROM)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\.\s*([a-zA-Z_][a-zA-Z0-9_]*)', 'gi'))[2] AS table_name
        LOOP
            -- Update or insert table usage stats
            INSERT INTO table_usage_stats (
                id,
                table_name,
                schema_name,
                select_count,
                insert_count,
                update_count,
                delete_count,
                snapshot_at,
                created_at,
                updated_at
            )
            VALUES (
                gen_random_uuid(),
                matched_table,
                matched_schema,
                CASE WHEN query_record.query_text ~* '^\s*SELECT' THEN 1 ELSE 0 END,
                CASE WHEN query_record.query_text ~* '^\s*INSERT' THEN 1 ELSE 0 END,
                CASE WHEN query_record.query_text ~* '^\s*UPDATE' THEN 1 ELSE 0 END,
                CASE WHEN query_record.query_text ~* '^\s*DELETE' THEN 1 ELSE 0 END,
                date_trunc('hour', current_snapshot),
                current_snapshot,
                current_snapshot
            )
            ON CONFLICT (schema_name, table_name, snapshot_at) DO UPDATE
            SET 
                select_count = table_usage_stats.select_count + EXCLUDED.select_count,
                insert_count = table_usage_stats.insert_count + EXCLUDED.insert_count,
                update_count = table_usage_stats.update_count + EXCLUDED.update_count,
                delete_count = table_usage_stats.delete_count + EXCLUDED.delete_count,
                updated_at = current_snapshot;
        END LOOP;
        
        -- Pattern for table without schema (assumes public schema)
        FOR matched_table IN
            SELECT DISTINCT
                (regexp_matches(query_record.query_text, '(?:FROM|JOIN|UPDATE|INSERT INTO|DELETE FROM)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:WHERE|SET|VALUES|ORDER|GROUP|LIMIT|;|$)', 'gi'))[1] AS table_name
        LOOP
            -- Skip if this looks like a schema name (followed by a dot)
            IF query_record.query_text !~* (matched_table || '\s*\.') THEN
                -- Update or insert table usage stats for public schema
                INSERT INTO table_usage_stats (
                    id,
                    table_name,
                    schema_name,
                    select_count,
                    insert_count,
                    update_count,
                    delete_count,
                    snapshot_at,
                    created_at,
                    updated_at
                )
                VALUES (
                    gen_random_uuid(),
                    matched_table,
                    'public',
                    CASE WHEN query_record.query_text ~* '^\s*SELECT' THEN 1 ELSE 0 END,
                    CASE WHEN query_record.query_text ~* '^\s*INSERT' THEN 1 ELSE 0 END,
                    CASE WHEN query_record.query_text ~* '^\s*UPDATE' THEN 1 ELSE 0 END,
                    CASE WHEN query_record.query_text ~* '^\s*DELETE' THEN 1 ELSE 0 END,
                    date_trunc('hour', current_snapshot),
                    current_snapshot,
                    current_snapshot
                )
                ON CONFLICT (schema_name, table_name, snapshot_at) DO UPDATE
                SET 
                    select_count = table_usage_stats.select_count + EXCLUDED.select_count,
                    insert_count = table_usage_stats.insert_count + EXCLUDED.insert_count,
                    update_count = table_usage_stats.update_count + EXCLUDED.update_count,
                    delete_count = table_usage_stats.delete_count + EXCLUDED.delete_count,
                    updated_at = current_snapshot;
            END IF;
        END LOOP;
        
        rows_processed := rows_processed + 1;
    END LOOP;
    
    -- Log the extraction operation
    RAISE NOTICE 'Processed % queries and extracted table usage statistics at %', rows_processed, current_snapshot;
    
    RETURN rows_processed;
END;
$_$;


ALTER FUNCTION admin.extract_table_usage_stats() OWNER TO postgres;

--
-- Name: FUNCTION extract_table_usage_stats(); Type: COMMENT; Schema: admin; Owner: postgres
--

COMMENT ON FUNCTION admin.extract_table_usage_stats() IS 'Parses queries from statement_stats and extracts table usage patterns into table_usage_stats';


--
-- Name: update_birth_data_updated_at(); Type: FUNCTION; Schema: ethereal; Owner: postgres
--

CREATE FUNCTION ethereal.update_birth_data_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        NEW.updated_at = current_timestamp;
        RETURN NEW;
    END;
    $$;


ALTER FUNCTION ethereal.update_birth_data_updated_at() OWNER TO postgres;

--
-- Name: update_birth_date_times_updated_at(); Type: FUNCTION; Schema: ethereal; Owner: postgres
--

CREATE FUNCTION ethereal.update_birth_date_times_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        NEW.updated_at = current_timestamp;
        RETURN NEW;
    END;
    $$;


ALTER FUNCTION ethereal.update_birth_date_times_updated_at() OWNER TO postgres;

--
-- Name: update_birth_locations_updated_at(); Type: FUNCTION; Schema: ethereal; Owner: postgres
--

CREATE FUNCTION ethereal.update_birth_locations_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        NEW.updated_at = current_timestamp;
        RETURN NEW;
    END;
    $$;


ALTER FUNCTION ethereal.update_birth_locations_updated_at() OWNER TO postgres;

--
-- Name: prevent_system_admin_deletion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prevent_system_admin_deletion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            -- For auth.users table, check username
            IF TG_TABLE_NAME = 'users' AND TG_TABLE_SCHEMA = 'auth' THEN
                IF OLD.username = 'admin@neonlaw.com' THEN
                    RAISE EXCEPTION 'Cannot delete system administrator account: admin@neonlaw.com'
                        USING ERRCODE = 'P0001',
                              HINT = 'This user account is protected from deletion for system security.';
                END IF;
            END IF;

            -- For directory.people table, check email
            IF TG_TABLE_NAME = 'people' AND TG_TABLE_SCHEMA = 'directory' THEN
                IF OLD.email = 'admin@neonlaw.com' THEN
                    RAISE EXCEPTION 'Cannot delete system administrator person record: admin@neonlaw.com'
                        USING ERRCODE = 'P0001',
                              HINT = 'This person record is protected from deletion for system security.';
                END IF;
            END IF;

            RETURN OLD;
        END;
        $$;


ALTER FUNCTION public.prevent_system_admin_deletion() OWNER TO postgres;

--
-- Name: FUNCTION prevent_system_admin_deletion(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.prevent_system_admin_deletion() IS 'Prevents deletion of system administrator (admin@neonlaw.com) from auth.users and directory.people';


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: generate_ticket_number(); Type: FUNCTION; Schema: service; Owner: postgres
--

CREATE FUNCTION service.generate_ticket_number() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN 'TKT-' || LPAD(nextval('service.ticket_number_seq')::TEXT, 6, '0');
END;
$$;


ALTER FUNCTION service.generate_ticket_number() OWNER TO postgres;

--
-- Name: set_ticket_number(); Type: FUNCTION; Schema: service; Owner: postgres
--

CREATE FUNCTION service.set_ticket_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.ticket_number IS NULL THEN
        NEW.ticket_number := service.generate_ticket_number();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION service.set_ticket_number() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: invoices; Type: TABLE; Schema: accounting; Owner: postgres
--

CREATE TABLE accounting.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vendor_id uuid NOT NULL,
    invoiced_from character varying(50) NOT NULL,
    invoiced_amount bigint NOT NULL,
    sent_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_invoices_amount_positive CHECK ((invoiced_amount > 0)),
    CONSTRAINT chk_invoices_invoiced_from CHECK (((invoiced_from)::text = ANY ((ARRAY['neon_law'::character varying, 'neon_law_foundation'::character varying, 'sagebrush_services'::character varying])::text[])))
);


ALTER TABLE accounting.invoices OWNER TO postgres;

--
-- Name: TABLE invoices; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON TABLE accounting.invoices IS 'Stores invoice information with vendor references and invoicing entity details';


--
-- Name: COLUMN invoices.id; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.id IS 'Unique identifier for the invoice';


--
-- Name: COLUMN invoices.vendor_id; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.vendor_id IS 'Foreign key reference to accounting.vendors';


--
-- Name: COLUMN invoices.invoiced_from; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.invoiced_from IS 'Entity that issued the invoice (neon_law, neon_law_foundation, or sagebrush_services)';


--
-- Name: COLUMN invoices.invoiced_amount; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.invoiced_amount IS 'Invoice amount in cents (to avoid decimal precision issues)';


--
-- Name: COLUMN invoices.sent_at; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.sent_at IS 'Timestamp when the invoice was sent';


--
-- Name: COLUMN invoices.created_at; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.created_at IS 'Timestamp when the invoice record was created';


--
-- Name: COLUMN invoices.updated_at; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.invoices.updated_at IS 'Timestamp when the invoice record was last updated';


--
-- Name: vendors; Type: TABLE; Schema: accounting; Owner: postgres
--

CREATE TABLE accounting.vendors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    entity_id uuid,
    person_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_vendors_exactly_one_reference CHECK ((((entity_id IS NOT NULL) AND (person_id IS NULL)) OR ((entity_id IS NULL) AND (person_id IS NOT NULL))))
);


ALTER TABLE accounting.vendors OWNER TO postgres;

--
-- Name: TABLE vendors; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON TABLE accounting.vendors IS 'Stores vendor information with optional references to entities or people';


--
-- Name: COLUMN vendors.id; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.vendors.id IS 'Unique identifier for the vendor';


--
-- Name: COLUMN vendors.name; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.vendors.name IS 'Name of the vendor';


--
-- Name: COLUMN vendors.entity_id; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.vendors.entity_id IS 'Optional foreign key reference to directory.entities';


--
-- Name: COLUMN vendors.person_id; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.vendors.person_id IS 'Optional foreign key reference to directory.people';


--
-- Name: COLUMN vendors.created_at; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.vendors.created_at IS 'Timestamp when the vendor was created';


--
-- Name: COLUMN vendors.updated_at; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON COLUMN accounting.vendors.updated_at IS 'Timestamp when the vendor was last updated';


--
-- Name: CONSTRAINT chk_vendors_exactly_one_reference ON vendors; Type: COMMENT; Schema: accounting; Owner: postgres
--

COMMENT ON CONSTRAINT chk_vendors_exactly_one_reference ON accounting.vendors IS 'Ensures exactly one of entity_id or person_id is set, enforcing mutual exclusion';


--
-- Name: person_entity_roles; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.person_entity_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid NOT NULL,
    entity_id uuid NOT NULL,
    role auth.person_entity_role_type NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE auth.person_entity_roles OWNER TO postgres;

--
-- Name: TABLE person_entity_roles; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON TABLE auth.person_entity_roles IS 'Defines role-based relationships between people and legal entities for authorization purposes';


--
-- Name: COLUMN person_entity_roles.id; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.person_entity_roles.id IS 'Unique identifier for the person-entity role relationship';


--
-- Name: COLUMN person_entity_roles.person_id; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.person_entity_roles.person_id IS 'Reference to the person in the directory.people table';


--
-- Name: COLUMN person_entity_roles.entity_id; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.person_entity_roles.entity_id IS 'Reference to the entity in the directory.entities table';


--
-- Name: COLUMN person_entity_roles.role; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.person_entity_roles.role IS 'Role type: owner (full control), admin (management), or staff (limited access)';


--
-- Name: COLUMN person_entity_roles.created_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.person_entity_roles.created_at IS 'Timestamp when the role relationship was created';


--
-- Name: COLUMN person_entity_roles.updated_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.person_entity_roles.updated_at IS 'Timestamp when the role relationship was last updated';


--
-- Name: service_account_tokens; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.service_account_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    token_hash text NOT NULL,
    service_type text NOT NULL,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone,
    CONSTRAINT service_account_tokens_service_type_check CHECK ((service_type = ANY (ARRAY['slack_bot'::text, 'ci_cd'::text, 'monitoring'::text])))
);


ALTER TABLE auth.service_account_tokens OWNER TO postgres;

--
-- Name: TABLE service_account_tokens; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON TABLE auth.service_account_tokens IS 'Authentication tokens for service accounts and bots';


--
-- Name: COLUMN service_account_tokens.id; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.id IS 'Unique identifier for the service account token';


--
-- Name: COLUMN service_account_tokens.name; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.name IS 'Human-readable name for the service account';


--
-- Name: COLUMN service_account_tokens.token_hash; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.token_hash IS 'SHA256 hash of the service account token';


--
-- Name: COLUMN service_account_tokens.service_type; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.service_type IS 'Type of service using this token';


--
-- Name: COLUMN service_account_tokens.expires_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.expires_at IS 'Optional expiration timestamp for the token';


--
-- Name: COLUMN service_account_tokens.is_active; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.is_active IS 'Whether the token is currently active';


--
-- Name: COLUMN service_account_tokens.created_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.created_at IS 'Timestamp when token was created';


--
-- Name: COLUMN service_account_tokens.last_used_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.service_account_tokens.last_used_at IS 'Timestamp when token was last used for authentication';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: postgres
--

CREATE TABLE auth.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    role auth.user_role DEFAULT 'staff'::auth.user_role NOT NULL,
    username public.citext NOT NULL,
    person_id uuid,
    sub character varying(255),
    subscribed_newsletters jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT check_user_role CHECK ((role = ANY (ARRAY['customer'::auth.user_role, 'staff'::auth.user_role, 'admin'::auth.user_role]))),
    CONSTRAINT subscribed_newsletters_valid_structure CHECK ((jsonb_typeof(subscribed_newsletters) = 'object'::text))
);


ALTER TABLE auth.users OWNER TO postgres;

--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON TABLE auth.users IS 'Authentication users table | Protected: admin@neonlaw.com cannot be deleted | Constraint: username must reference directory.people.email';


--
-- Name: COLUMN users.id; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.id IS 'Unique identifier for the user (UUIDv4)';


--
-- Name: COLUMN users.created_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.created_at IS 'Timestamp when the user account was created';


--
-- Name: COLUMN users.updated_at; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.updated_at IS 'Timestamp when the user account was last updated';


--
-- Name: COLUMN users.role; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.role IS 'User role determining access level and permissions. Hierarchy: customer < staff < admin.';


--
-- Name: COLUMN users.username; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.username IS 'Username for authentication (email format). Uses CITEXT type for case-insensitive comparisons. Must correspond to a valid directory.people.email record.';


--
-- Name: COLUMN users.person_id; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.person_id IS 'Reference to the person record in directory.people';


--
-- Name: COLUMN users.sub; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.sub IS 'Cognito subject ID for mapping external identity providers';


--
-- Name: COLUMN users.subscribed_newsletters; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON COLUMN auth.users.subscribed_newsletters IS 'JSON object containing newsletter subscription preferences (e.g., {"sci_tech": true})';


--
-- Name: addresses; Type: TABLE; Schema: directory; Owner: postgres
--

CREATE TABLE directory.addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_id uuid,
    street text NOT NULL,
    city text NOT NULL,
    state text,
    zip text,
    country text NOT NULL,
    is_verified boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    person_id uuid,
    CONSTRAINT chk_addresses_entity_or_person_exclusive CHECK ((((entity_id IS NOT NULL) AND (person_id IS NULL)) OR ((entity_id IS NULL) AND (person_id IS NOT NULL))))
);


ALTER TABLE directory.addresses OWNER TO postgres;

--
-- Name: TABLE addresses; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON TABLE directory.addresses IS 'Addresses for entities and people in the directory';


--
-- Name: COLUMN addresses.id; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.id IS 'Unique identifier for the address';


--
-- Name: COLUMN addresses.entity_id; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.entity_id IS 'Foreign key to directory.entities (XOR with person_id)';


--
-- Name: COLUMN addresses.street; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.street IS 'Street address';


--
-- Name: COLUMN addresses.city; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.city IS 'City name';


--
-- Name: COLUMN addresses.state; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.state IS 'State or province';


--
-- Name: COLUMN addresses.zip; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.zip IS 'ZIP or postal code';


--
-- Name: COLUMN addresses.country; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.country IS 'Country name';


--
-- Name: COLUMN addresses.is_verified; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.is_verified IS 'Whether the address has been verified';


--
-- Name: COLUMN addresses.created_at; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.created_at IS 'Timestamp when the address was created';


--
-- Name: COLUMN addresses.updated_at; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.updated_at IS 'Timestamp when the address was last updated';


--
-- Name: COLUMN addresses.person_id; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.addresses.person_id IS 'Foreign key to directory.people (XOR with entity_id)';


--
-- Name: entities; Type: TABLE; Schema: directory; Owner: postgres
--

CREATE TABLE directory.entities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    legal_entity_type_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE directory.entities OWNER TO postgres;

--
-- Name: TABLE entities; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON TABLE directory.entities IS 'Stores entity information with unique names per entity type';


--
-- Name: COLUMN entities.id; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.entities.id IS 'Unique identifier for the entity';


--
-- Name: COLUMN entities.name; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.entities.name IS 'Name of the entity';


--
-- Name: COLUMN entities.legal_entity_type_id; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.entities.legal_entity_type_id IS 'Foreign key reference to the legal entity type';


--
-- Name: COLUMN entities.created_at; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.entities.created_at IS 'Timestamp when the entity was created';


--
-- Name: COLUMN entities.updated_at; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.entities.updated_at IS 'Timestamp when the entity was last updated';


--
-- Name: people; Type: TABLE; Schema: directory; Owner: postgres
--

CREATE TABLE directory.people (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    email public.citext NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE directory.people OWNER TO postgres;

--
-- Name: TABLE people; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON TABLE directory.people IS 'Directory of people with their basic contact information | Protected: admin@neonlaw.com cannot be deleted';


--
-- Name: COLUMN people.id; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.people.id IS 'Unique identifier for the person (UUIDv4)';


--
-- Name: COLUMN people.name; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.people.name IS 'Full name of the person';


--
-- Name: COLUMN people.email; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.people.email IS 'Email address of the person (case insensitive)';


--
-- Name: COLUMN people.created_at; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.people.created_at IS 'Timestamp when the person record was created';


--
-- Name: COLUMN people.updated_at; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON COLUMN directory.people.updated_at IS 'Timestamp when the person record was last updated';


--
-- Name: blobs; Type: TABLE; Schema: documents; Owner: postgres
--

CREATE TABLE documents.blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    object_storage_url text NOT NULL,
    referenced_by text NOT NULL,
    referenced_by_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT documents_blobs_referenced_by_check CHECK ((referenced_by = ANY (ARRAY['letters'::text, 'share_issuances'::text, 'answers'::text])))
);


ALTER TABLE documents.blobs OWNER TO postgres;

--
-- Name: TABLE blobs; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON TABLE documents.blobs IS 'Stores file references in S3. Uses polymorphism: referenced_by discriminates, referenced_by_id has UUID';


--
-- Name: COLUMN blobs.id; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON COLUMN documents.blobs.id IS 'Unique identifier for the blob reference';


--
-- Name: COLUMN blobs.object_storage_url; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON COLUMN documents.blobs.object_storage_url IS 'URL or URI to the file in AWS S3';


--
-- Name: COLUMN blobs.referenced_by; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON COLUMN documents.blobs.referenced_by IS 'Type of entity referencing this blob (polymorphic discriminator). Values: letters, share_issuances, answers';


--
-- Name: COLUMN blobs.referenced_by_id; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON COLUMN documents.blobs.referenced_by_id IS 'UUID of the entity referencing this blob';


--
-- Name: COLUMN blobs.created_at; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON COLUMN documents.blobs.created_at IS 'Timestamp when the blob reference was created';


--
-- Name: COLUMN blobs.updated_at; Type: COMMENT; Schema: documents; Owner: postgres
--

COMMENT ON COLUMN documents.blobs.updated_at IS 'Timestamp when the blob reference was last updated';


--
-- Name: share_classes; Type: TABLE; Schema: equity; Owner: postgres
--

CREATE TABLE equity.share_classes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    entity_id uuid NOT NULL,
    priority integer NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE equity.share_classes OWNER TO postgres;

--
-- Name: TABLE share_classes; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON TABLE equity.share_classes IS 'Stores share class information including name, priority, and entity reference';


--
-- Name: COLUMN share_classes.id; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.id IS 'Unique identifier for the share class';


--
-- Name: COLUMN share_classes.name; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.name IS 'Name of the share class';


--
-- Name: COLUMN share_classes.entity_id; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.entity_id IS 'Foreign key reference to the directory entity';


--
-- Name: COLUMN share_classes.priority; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.priority IS 'Priority level of the share class';


--
-- Name: COLUMN share_classes.description; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.description IS 'Description of the share class';


--
-- Name: COLUMN share_classes.created_at; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.created_at IS 'Timestamp when the share class was created';


--
-- Name: COLUMN share_classes.updated_at; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_classes.updated_at IS 'Timestamp when the share class was last updated';


--
-- Name: share_issuances; Type: TABLE; Schema: equity; Owner: postgres
--

CREATE TABLE equity.share_issuances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    share_class_id uuid NOT NULL,
    holder_id uuid NOT NULL,
    document_id uuid,
    fair_market_value_per_share numeric(20,4),
    amount_paid_per_share numeric(20,4),
    amount_paid_for_shares numeric(20,4),
    amount_to_include_in_gross_income numeric(20,4),
    restrictions text,
    taxable_year character varying(4),
    calendar_year character varying(4),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE equity.share_issuances OWNER TO postgres;

--
-- Name: TABLE share_issuances; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON TABLE equity.share_issuances IS 'Stores share issuance information including financial details and holder references';


--
-- Name: COLUMN share_issuances.id; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.id IS 'Unique identifier for the share issuance';


--
-- Name: COLUMN share_issuances.share_class_id; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.share_class_id IS 'Foreign key reference to the share class';


--
-- Name: COLUMN share_issuances.holder_id; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.holder_id IS 'Foreign key reference to the entity holding the shares';


--
-- Name: COLUMN share_issuances.document_id; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.document_id IS 'Optional foreign key reference to supporting document';


--
-- Name: COLUMN share_issuances.fair_market_value_per_share; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.fair_market_value_per_share IS 'Fair market value per share at time of issuance';


--
-- Name: COLUMN share_issuances.amount_paid_per_share; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.amount_paid_per_share IS 'Amount paid per share by the holder';


--
-- Name: COLUMN share_issuances.amount_paid_for_shares; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.amount_paid_for_shares IS 'Total amount paid for all shares';


--
-- Name: COLUMN share_issuances.amount_to_include_in_gross_income; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.amount_to_include_in_gross_income IS 'Amount to include in gross income for tax purposes';


--
-- Name: COLUMN share_issuances.restrictions; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.restrictions IS 'Any restrictions on the share issuance';


--
-- Name: COLUMN share_issuances.taxable_year; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.taxable_year IS 'Tax year for the issuance (YYYY format)';


--
-- Name: COLUMN share_issuances.calendar_year; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.calendar_year IS 'Calendar year for the issuance (YYYY format)';


--
-- Name: COLUMN share_issuances.created_at; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.created_at IS 'Timestamp when the share issuance was created';


--
-- Name: COLUMN share_issuances.updated_at; Type: COMMENT; Schema: equity; Owner: postgres
--

COMMENT ON COLUMN equity.share_issuances.updated_at IS 'Timestamp when the share issuance was last updated';


--
-- Name: birth_data; Type: TABLE; Schema: ethereal; Owner: postgres
--

CREATE TABLE ethereal.birth_data (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    location_id uuid NOT NULL,
    date_time_id uuid NOT NULL,
    notes text,
    is_verified boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE ethereal.birth_data OWNER TO postgres;

--
-- Name: TABLE birth_data; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON TABLE ethereal.birth_data IS 'Main table linking users to their birth information';


--
-- Name: COLUMN birth_data.notes; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_data.notes IS 'Optional notes about birth circumstances';


--
-- Name: COLUMN birth_data.is_verified; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_data.is_verified IS 'Whether the birth data has been verified by the user';


--
-- Name: birth_date_times; Type: TABLE; Schema: ethereal; Owner: postgres
--

CREATE TABLE ethereal.birth_date_times (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    birth_date date NOT NULL,
    birth_time time without time zone NOT NULL,
    hour smallint NOT NULL,
    minute smallint NOT NULL,
    second smallint NOT NULL,
    timezone character varying(100) NOT NULL,
    is_daylight_saving boolean DEFAULT false NOT NULL,
    utc_offset integer NOT NULL,
    utc_timestamp timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_birth_date_times_hour CHECK (((hour >= 0) AND (hour <= 23))),
    CONSTRAINT chk_birth_date_times_minute CHECK (((minute >= 0) AND (minute <= 59))),
    CONSTRAINT chk_birth_date_times_second CHECK (((second >= 0) AND (second <= 59))),
    CONSTRAINT chk_birth_date_times_utc_offset CHECK (((utc_offset >= '-12'::integer) AND (utc_offset <= 14)))
);


ALTER TABLE ethereal.birth_date_times OWNER TO postgres;

--
-- Name: TABLE birth_date_times; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON TABLE ethereal.birth_date_times IS 'Stores precise birth date and time information';


--
-- Name: COLUMN birth_date_times.birth_time; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_date_times.birth_time IS 'Local birth time';


--
-- Name: COLUMN birth_date_times.utc_offset; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_date_times.utc_offset IS 'UTC offset in hours at time of birth';


--
-- Name: COLUMN birth_date_times.utc_timestamp; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_date_times.utc_timestamp IS 'Birth time converted to UTC';


--
-- Name: birth_locations; Type: TABLE; Schema: ethereal; Owner: postgres
--

CREATE TABLE ethereal.birth_locations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    latitude numeric(10,6) NOT NULL,
    longitude numeric(10,6) NOT NULL,
    city character varying(255) NOT NULL,
    state character varying(255),
    country character varying(255) NOT NULL,
    timezone character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_birth_locations_latitude CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
    CONSTRAINT chk_birth_locations_longitude CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric)))
);


ALTER TABLE ethereal.birth_locations OWNER TO postgres;

--
-- Name: TABLE birth_locations; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON TABLE ethereal.birth_locations IS 'Stores geographic locations for birth data';


--
-- Name: COLUMN birth_locations.latitude; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_locations.latitude IS 'Latitude in decimal degrees (-90 to 90)';


--
-- Name: COLUMN birth_locations.longitude; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_locations.longitude IS 'Longitude in decimal degrees (-180 to 180)';


--
-- Name: COLUMN birth_locations.timezone; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON COLUMN ethereal.birth_locations.timezone IS 'IANA timezone identifier (e.g., America/Los_Angeles)';


--
-- Name: credentials; Type: TABLE; Schema: legal; Owner: postgres
--

CREATE TABLE legal.credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid NOT NULL,
    jurisdiction_id uuid NOT NULL,
    license_number character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE legal.credentials OWNER TO postgres;

--
-- Name: TABLE credentials; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON TABLE legal.credentials IS 'Professional licenses and credentials held by people in various jurisdictions';


--
-- Name: COLUMN credentials.id; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.credentials.id IS 'Unique identifier for the credential';


--
-- Name: COLUMN credentials.person_id; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.credentials.person_id IS 'Reference to the person who holds this credential';


--
-- Name: COLUMN credentials.jurisdiction_id; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.credentials.jurisdiction_id IS 'Reference to the jurisdiction where this credential is valid';


--
-- Name: COLUMN credentials.license_number; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.credentials.license_number IS 'The license or credential number';


--
-- Name: COLUMN credentials.created_at; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.credentials.created_at IS 'When this credential record was created';


--
-- Name: COLUMN credentials.updated_at; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.credentials.updated_at IS 'When this credential record was last updated';


--
-- Name: entity_types; Type: TABLE; Schema: legal; Owner: postgres
--

CREATE TABLE legal.entity_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    legal_jurisdiction_id uuid NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT entity_types_name_check CHECK (((name)::text = ANY ((ARRAY['LLC'::character varying, 'PLLC'::character varying, 'Non-Profit'::character varying, 'C-Corp'::character varying, 'Single Member LLC'::character varying, 'Multi Member LLC'::character varying, '501(c)(3) Non-Profit'::character varying, 'Family Trust'::character varying, 'Human'::character varying, 'Foreign Company'::character varying])::text[])))
);


ALTER TABLE legal.entity_types OWNER TO postgres;

--
-- Name: TABLE entity_types; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON TABLE legal.entity_types IS 'Types of legal entities within specific jurisdictions';


--
-- Name: COLUMN entity_types.id; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.entity_types.id IS 'Unique identifier for the entity type (UUIDv4)';


--
-- Name: COLUMN entity_types.legal_jurisdiction_id; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.entity_types.legal_jurisdiction_id IS 'Reference to the legal jurisdiction where this entity type is valid';


--
-- Name: COLUMN entity_types.name; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.entity_types.name IS 'Type of legal entity (LLC, PLLC, Non-Profit, C-Corp, Single Member LLC, Multi Member LLC, 501(c)(3) Non-Profit,
Family Trust, Human, Foreign Company)';


--
-- Name: COLUMN entity_types.created_at; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.entity_types.created_at IS 'Timestamp when the entity type record was created';


--
-- Name: COLUMN entity_types.updated_at; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.entity_types.updated_at IS 'Timestamp when the entity type record was last updated';


--
-- Name: jurisdictions; Type: TABLE; Schema: legal; Owner: postgres
--

CREATE TABLE legal.jurisdictions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    code public.citext NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    jurisdiction_type legal.jurisdiction_type DEFAULT 'state'::legal.jurisdiction_type NOT NULL
);


ALTER TABLE legal.jurisdictions OWNER TO postgres;

--
-- Name: TABLE jurisdictions; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON TABLE legal.jurisdictions IS 'Legal jurisdictions with their names and unique codes';


--
-- Name: COLUMN jurisdictions.id; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.jurisdictions.id IS 'Unique identifier for the jurisdiction (UUIDv4)';


--
-- Name: COLUMN jurisdictions.name; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.jurisdictions.name IS 'Full name of the jurisdiction';


--
-- Name: COLUMN jurisdictions.code; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.jurisdictions.code IS 'Unique code for the jurisdiction (case insensitive)';


--
-- Name: COLUMN jurisdictions.created_at; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.jurisdictions.created_at IS 'Timestamp when the jurisdiction record was created';


--
-- Name: COLUMN jurisdictions.updated_at; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.jurisdictions.updated_at IS 'Timestamp when the jurisdiction record was last updated';


--
-- Name: COLUMN jurisdictions.jurisdiction_type; Type: COMMENT; Schema: legal; Owner: postgres
--

COMMENT ON COLUMN legal.jurisdictions.jurisdiction_type IS 'Type of jurisdiction (city, county, state, country) with default value of state';


--
-- Name: letters; Type: TABLE; Schema: mail; Owner: postgres
--

CREATE TABLE mail.letters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    mailbox_id uuid NOT NULL,
    sender_address_id uuid,
    received_date date NOT NULL,
    postmark_date date,
    tracking_number text,
    carrier text,
    letter_type text,
    status text DEFAULT 'received'::text NOT NULL,
    scanned_at timestamp with time zone,
    scanned_by uuid,
    emailed_at timestamp with time zone,
    emailed_to text[],
    forwarded_at timestamp with time zone,
    forwarded_to_address text,
    forwarding_tracking_number text,
    shredded_at timestamp with time zone,
    returned_at timestamp with time zone,
    return_reason text,
    notes text,
    is_priority boolean DEFAULT false,
    requires_signature boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    scanned_document_id uuid,
    CONSTRAINT letters_status_check CHECK ((status = ANY (ARRAY['received'::text, 'scanned'::text, 'emailed'::text, 'forwarded'::text, 'shredded'::text, 'returned'::text])))
);


ALTER TABLE mail.letters OWNER TO postgres;

--
-- Name: TABLE letters; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON TABLE mail.letters IS 'Stores letters received at virtual mailboxes';


--
-- Name: COLUMN letters.id; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.id IS 'Unique identifier for the letter';


--
-- Name: COLUMN letters.mailbox_id; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.mailbox_id IS 'Foreign key reference to the mailbox that received the letter';


--
-- Name: COLUMN letters.sender_address_id; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.sender_address_id IS 'Foreign key reference to the sender address in directory.address table';


--
-- Name: COLUMN letters.received_date; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.received_date IS 'Date when the letter was physically received at the mailbox';


--
-- Name: COLUMN letters.postmark_date; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.postmark_date IS 'Date from the postal cancellation mark';


--
-- Name: COLUMN letters.tracking_number; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.tracking_number IS 'Tracking number for trackable mail pieces';


--
-- Name: COLUMN letters.carrier; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.carrier IS 'Delivery service that brought the mail (USPS, UPS, FedEx, etc.)';


--
-- Name: COLUMN letters.letter_type; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.letter_type IS 'Classification of mail (regular, certified, registered, priority, etc.)';


--
-- Name: COLUMN letters.status; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.status IS 'Current processing status of the letter';


--
-- Name: COLUMN letters.scanned_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.scanned_at IS 'Timestamp when the letter was scanned';


--
-- Name: COLUMN letters.scanned_by; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.scanned_by IS 'User who scanned the letter';


--
-- Name: COLUMN letters.emailed_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.emailed_at IS 'Timestamp when the scan was emailed to the customer';


--
-- Name: COLUMN letters.emailed_to; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.emailed_to IS 'Array of email addresses the scan was sent to';


--
-- Name: COLUMN letters.forwarded_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.forwarded_at IS 'Timestamp when the letter was physically forwarded';


--
-- Name: COLUMN letters.forwarded_to_address; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.forwarded_to_address IS 'Address where the letter was forwarded to';


--
-- Name: COLUMN letters.forwarding_tracking_number; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.forwarding_tracking_number IS 'Tracking number for the forwarded mail';


--
-- Name: COLUMN letters.shredded_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.shredded_at IS 'Timestamp when the letter was securely destroyed';


--
-- Name: COLUMN letters.returned_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.returned_at IS 'Timestamp when the letter was returned to sender';


--
-- Name: COLUMN letters.return_reason; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.return_reason IS 'Reason why the letter was returned';


--
-- Name: COLUMN letters.notes; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.notes IS 'Additional notes about the letter';


--
-- Name: COLUMN letters.is_priority; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.is_priority IS 'Flag indicating if the letter requires urgent handling';


--
-- Name: COLUMN letters.requires_signature; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.requires_signature IS 'Flag indicating if the letter requires signature confirmation';


--
-- Name: COLUMN letters.created_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.created_at IS 'Timestamp when the letter record was created';


--
-- Name: COLUMN letters.updated_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.updated_at IS 'Timestamp when the letter record was last updated';


--
-- Name: COLUMN letters.scanned_document_id; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.letters.scanned_document_id IS 'Foreign key reference to the scanned document in documents.blobs table';


--
-- Name: mailboxes; Type: TABLE; Schema: mail; Owner: postgres
--

CREATE TABLE mail.mailboxes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    directory_address_id uuid NOT NULL,
    mailbox_number integer NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE mail.mailboxes OWNER TO postgres;

--
-- Name: TABLE mailboxes; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON TABLE mail.mailboxes IS 'Stores mailbox information linked to physical addresses';


--
-- Name: COLUMN mailboxes.id; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.mailboxes.id IS 'Unique identifier for the mailbox';


--
-- Name: COLUMN mailboxes.directory_address_id; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.mailboxes.directory_address_id IS 'Foreign key reference to the directory.address table';


--
-- Name: COLUMN mailboxes.mailbox_number; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.mailboxes.mailbox_number IS 'The mailbox number at the given address';


--
-- Name: COLUMN mailboxes.is_active; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.mailboxes.is_active IS 'Whether the mailbox is currently active and can receive mail';


--
-- Name: COLUMN mailboxes.created_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.mailboxes.created_at IS 'Timestamp when the mailbox was created';


--
-- Name: COLUMN mailboxes.updated_at; Type: COMMENT; Schema: mail; Owner: postgres
--

COMMENT ON COLUMN mail.mailboxes.updated_at IS 'Timestamp when the mailbox was last updated';


--
-- Name: newsletter_analytics; Type: TABLE; Schema: marketing; Owner: postgres
--

CREATE TABLE marketing.newsletter_analytics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    newsletter_id uuid NOT NULL,
    user_id uuid,
    event_type text NOT NULL,
    event_data jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT newsletter_analytics_event_type_check CHECK ((event_type = ANY (ARRAY['sent'::text, 'opened'::text, 'clicked'::text, 'unsubscribed'::text])))
);


ALTER TABLE marketing.newsletter_analytics OWNER TO postgres;

--
-- Name: TABLE newsletter_analytics; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON TABLE marketing.newsletter_analytics IS 'Table for tracking newsletter engagement metrics and analytics';


--
-- Name: COLUMN newsletter_analytics.id; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.id IS 'Unique identifier for the analytics event';


--
-- Name: COLUMN newsletter_analytics.newsletter_id; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.newsletter_id IS 'Reference to the newsletter being tracked';


--
-- Name: COLUMN newsletter_analytics.user_id; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.user_id IS 'Reference to the user (null for anonymous events)';


--
-- Name: COLUMN newsletter_analytics.event_type; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.event_type IS 'Type of event: sent, opened, clicked, unsubscribed';


--
-- Name: COLUMN newsletter_analytics.event_data; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.event_data IS 'Additional event metadata in JSON format';


--
-- Name: COLUMN newsletter_analytics.ip_address; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.ip_address IS 'IP address of the user for the event';


--
-- Name: COLUMN newsletter_analytics.user_agent; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.user_agent IS 'User agent string for web-based events';


--
-- Name: COLUMN newsletter_analytics.created_at; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_analytics.created_at IS 'Timestamp when the event occurred';


--
-- Name: newsletter_templates; Type: TABLE; Schema: marketing; Owner: postgres
--

CREATE TABLE marketing.newsletter_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    template_content text NOT NULL,
    category text DEFAULT 'general'::text,
    is_active boolean DEFAULT true,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT newsletter_templates_category_check CHECK ((category = ANY (ARRAY['general'::text, 'announcement'::text, 'update'::text, 'newsletter'::text]))),
    CONSTRAINT newsletter_templates_content_check CHECK ((char_length(template_content) > 10))
);


ALTER TABLE marketing.newsletter_templates OWNER TO postgres;

--
-- Name: TABLE newsletter_templates; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON TABLE marketing.newsletter_templates IS 'Reusable newsletter templates for consistent formatting';


--
-- Name: COLUMN newsletter_templates.id; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.id IS 'Unique identifier for the template';


--
-- Name: COLUMN newsletter_templates.name; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.name IS 'Template name for identification';


--
-- Name: COLUMN newsletter_templates.description; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.description IS 'Description of template purpose and usage';


--
-- Name: COLUMN newsletter_templates.template_content; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.template_content IS 'Markdown template with merge tag placeholders';


--
-- Name: COLUMN newsletter_templates.category; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.category IS 'Template category for organization';


--
-- Name: COLUMN newsletter_templates.is_active; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.is_active IS 'Whether template is available for use';


--
-- Name: COLUMN newsletter_templates.created_by; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.created_by IS 'Admin user who created the template';


--
-- Name: COLUMN newsletter_templates.created_at; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.created_at IS 'Timestamp when template was created';


--
-- Name: COLUMN newsletter_templates.updated_at; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletter_templates.updated_at IS 'Timestamp when template was last updated';


--
-- Name: newsletters; Type: TABLE; Schema: marketing; Owner: postgres
--

CREATE TABLE marketing.newsletters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    subject_line text NOT NULL,
    markdown_content text NOT NULL,
    sent_at timestamp with time zone,
    recipient_count integer DEFAULT 0,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT newsletters_name_check CHECK ((name = ANY (ARRAY['nv-sci-tech'::text, 'sagebrush'::text, 'neon-law'::text]))),
    CONSTRAINT newsletters_recipient_count_check CHECK ((recipient_count >= 0)),
    CONSTRAINT newsletters_subject_line_length CHECK (((char_length(subject_line) > 0) AND (char_length(subject_line) <= 200)))
);


ALTER TABLE marketing.newsletters OWNER TO postgres;

--
-- Name: TABLE newsletters; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON TABLE marketing.newsletters IS 'Table storing newsletter content and metadata';


--
-- Name: COLUMN newsletters.id; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.id IS 'Unique identifier for the newsletter';


--
-- Name: COLUMN newsletters.name; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.name IS 'Newsletter type/name (nv-sci-tech, sagebrush, neon-law)';


--
-- Name: COLUMN newsletters.subject_line; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.subject_line IS 'Email subject line for the newsletter';


--
-- Name: COLUMN newsletters.markdown_content; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.markdown_content IS 'Newsletter content in markdown format (immutable after send)';


--
-- Name: COLUMN newsletters.sent_at; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.sent_at IS 'Timestamp when the newsletter was sent (null if draft)';


--
-- Name: COLUMN newsletters.recipient_count; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.recipient_count IS 'Number of recipients the newsletter was sent to';


--
-- Name: COLUMN newsletters.created_by; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.created_by IS 'Admin user who created the newsletter';


--
-- Name: COLUMN newsletters.created_at; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.created_at IS 'Timestamp when the newsletter was created';


--
-- Name: COLUMN newsletters.updated_at; Type: COMMENT; Schema: marketing; Owner: postgres
--

COMMENT ON COLUMN marketing.newsletters.updated_at IS 'Timestamp when the newsletter was last updated';


--
-- Name: answers; Type: TABLE; Schema: matters; Owner: postgres
--

CREATE TABLE matters.answers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid,
    answerer_id uuid NOT NULL,
    question_id uuid NOT NULL,
    entity_id uuid NOT NULL,
    assigned_notation_id uuid,
    response jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE matters.answers OWNER TO postgres;

--
-- Name: TABLE answers; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON TABLE matters.answers IS 'Individual answers to questions provided by users, linked to entities and optionally assigned notations';


--
-- Name: COLUMN answers.id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.id IS 'Unique identifier for the answer record';


--
-- Name: COLUMN answers.blob_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.blob_id IS 'Optional foreign key reference to a document blob associated with this answer';


--
-- Name: COLUMN answers.answerer_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.answerer_id IS 'Foreign key reference to the person who provided this answer';


--
-- Name: COLUMN answers.question_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.question_id IS 'Foreign key reference to the question being answered';


--
-- Name: COLUMN answers.entity_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.entity_id IS 'Foreign key reference to the entity this answer relates to';


--
-- Name: COLUMN answers.assigned_notation_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.assigned_notation_id IS 'Optional foreign key reference to the assigned notation this answer belongs to';


--
-- Name: COLUMN answers.response; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.response IS 'JSON object containing the structured answer data';


--
-- Name: COLUMN answers.created_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.created_at IS 'Timestamp when the answer was created';


--
-- Name: COLUMN answers.updated_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.answers.updated_at IS 'Timestamp when the answer was last updated';


--
-- Name: assigned_notations; Type: TABLE; Schema: matters; Owner: postgres
--

CREATE TABLE matters.assigned_notations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_id uuid NOT NULL,
    state character varying(50) NOT NULL,
    change_language jsonb DEFAULT '{}'::jsonb NOT NULL,
    due_at timestamp with time zone,
    person_id uuid,
    answers jsonb DEFAULT '{}'::jsonb NOT NULL,
    notation_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    project_id uuid,
    CONSTRAINT assigned_notations_state_check CHECK (((state)::text = ANY ((ARRAY['awaiting_flow'::character varying, 'awaiting_review'::character varying, 'awaiting_alignment'::character varying, 'complete'::character varying, 'complete_with_error'::character varying])::text[])))
);


ALTER TABLE matters.assigned_notations OWNER TO postgres;

--
-- Name: TABLE assigned_notations; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON TABLE matters.assigned_notations IS 'Tracks assigned notations to entities with their completion state and answers';


--
-- Name: COLUMN assigned_notations.id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.id IS 'Unique identifier for the assigned notation';


--
-- Name: COLUMN assigned_notations.entity_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.entity_id IS 'Foreign key reference to the entity this notation is assigned to';


--
-- Name: COLUMN assigned_notations.state; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.state IS 'Current state of the notation: awaiting_flow, awaiting_review, awaiting_alignment, complete, complete_with_error';


--
-- Name: COLUMN assigned_notations.change_language; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.change_language IS 'JSON object containing any change language or modifications to the notation';


--
-- Name: COLUMN assigned_notations.due_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.due_at IS 'Optional timestamp indicating when this notation assignment is due';


--
-- Name: COLUMN assigned_notations.person_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.person_id IS 'Optional foreign key reference to the person assigned to complete this notation';


--
-- Name: COLUMN assigned_notations.answers; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.answers IS 'JSON object containing the answers provided for this notation';


--
-- Name: COLUMN assigned_notations.notation_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.notation_id IS 'Foreign key reference to the notation template being used';


--
-- Name: COLUMN assigned_notations.created_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.created_at IS 'Timestamp when the notation was assigned';


--
-- Name: COLUMN assigned_notations.updated_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.updated_at IS 'Timestamp when the assigned notation was last updated';


--
-- Name: COLUMN assigned_notations.project_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.assigned_notations.project_id IS 'Foreign key reference to the project this notation assignment belongs to. Set to NULL when project is deleted.';


--
-- Name: disclosures; Type: TABLE; Schema: matters; Owner: postgres
--

CREATE TABLE matters.disclosures (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credential_id uuid NOT NULL,
    project_id uuid NOT NULL,
    disclosed_at date NOT NULL,
    end_disclosed_at date,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_disclosures_date_order CHECK (((end_disclosed_at IS NULL) OR (disclosed_at <= end_disclosed_at)))
);


ALTER TABLE matters.disclosures OWNER TO postgres;

--
-- Name: TABLE disclosures; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON TABLE matters.disclosures IS 'Join table between legal credentials and projects tracking disclosure periods';


--
-- Name: COLUMN disclosures.id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.id IS 'Unique identifier for the disclosure record';


--
-- Name: COLUMN disclosures.credential_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.credential_id IS 'Foreign key reference to the legal credential being disclosed';


--
-- Name: COLUMN disclosures.project_id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.project_id IS 'Foreign key reference to the project where the disclosure applies';


--
-- Name: COLUMN disclosures.disclosed_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.disclosed_at IS 'Date when the disclosure period begins';


--
-- Name: COLUMN disclosures.end_disclosed_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.end_disclosed_at IS 'Date when the disclosure period ends (optional)';


--
-- Name: COLUMN disclosures.active; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.active IS 'Boolean flag indicating if the disclosure is currently active';


--
-- Name: COLUMN disclosures.created_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.created_at IS 'Timestamp when the disclosure record was created';


--
-- Name: COLUMN disclosures.updated_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.disclosures.updated_at IS 'Timestamp when the disclosure record was last updated';


--
-- Name: projects; Type: TABLE; Schema: matters; Owner: postgres
--

CREATE TABLE matters.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codename public.citext NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE matters.projects OWNER TO postgres;

--
-- Name: TABLE projects; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON TABLE matters.projects IS 'Projects that group assigned notations together';


--
-- Name: COLUMN projects.id; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.projects.id IS 'Unique identifier for the project';


--
-- Name: COLUMN projects.codename; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.projects.codename IS 'Case-insensitive unique codename for the project using CITEXT type';


--
-- Name: COLUMN projects.created_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.projects.created_at IS 'Timestamp when the project was created';


--
-- Name: COLUMN projects.updated_at; Type: COMMENT; Schema: matters; Owner: postgres
--

COMMENT ON COLUMN matters.projects.updated_at IS 'Timestamp when the project was last updated';


--
-- Name: relationship_logs; Type: TABLE; Schema: matters; Owner: postgres
--

CREATE TABLE matters.relationship_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    credential_id uuid NOT NULL,
    body text NOT NULL,
    relationships jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE matters.relationship_logs OWNER TO postgres;

--
-- Name: lawyer_inquiries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lawyer_inquiries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_name character varying(255) NOT NULL,
    contact_name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    nevada_bar_member character varying(20),
    current_software character varying(255),
    use_cases text,
    inquiry_status character varying(50) DEFAULT 'new'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lawyer_inquiries_inquiry_status_check CHECK (((inquiry_status)::text = ANY ((ARRAY['new'::character varying, 'contacted'::character varying, 'qualified'::character varying, 'converted'::character varying, 'declined'::character varying])::text[]))),
    CONSTRAINT lawyer_inquiries_nevada_bar_member_check CHECK (((nevada_bar_member)::text = ANY ((ARRAY['yes'::character varying, 'no'::character varying, 'considering'::character varying])::text[])))
);


ALTER TABLE public.lawyer_inquiries OWNER TO postgres;

--
-- Name: TABLE lawyer_inquiries; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.lawyer_inquiries IS 'Stores inquiries from lawyers interested in the AI platform';


--
-- Name: COLUMN lawyer_inquiries.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.id IS 'Unique identifier for the inquiry';


--
-- Name: COLUMN lawyer_inquiries.firm_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.firm_name IS 'Name of the law firm making the inquiry';


--
-- Name: COLUMN lawyer_inquiries.contact_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.contact_name IS 'Name of the person submitting the inquiry';


--
-- Name: COLUMN lawyer_inquiries.email; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.email IS 'Contact email address';


--
-- Name: COLUMN lawyer_inquiries.nevada_bar_member; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.nevada_bar_member IS 'Nevada Bar membership status: yes, no, or considering';


--
-- Name: COLUMN lawyer_inquiries.current_software; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.current_software IS 'Current case management software they use';


--
-- Name: COLUMN lawyer_inquiries.use_cases; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.use_cases IS 'AI use cases they are interested in';


--
-- Name: COLUMN lawyer_inquiries.inquiry_status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.inquiry_status IS 'Current status of the inquiry: new, contacted, qualified, converted, declined';


--
-- Name: COLUMN lawyer_inquiries.notes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.notes IS 'Internal notes about the inquiry';


--
-- Name: COLUMN lawyer_inquiries.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.created_at IS 'When the inquiry was submitted';


--
-- Name: COLUMN lawyer_inquiries.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.lawyer_inquiries.updated_at IS 'When the inquiry was last updated';


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.migrations (
    migration_name text NOT NULL,
    migrated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.migrations OWNER TO postgres;

--
-- Name: statement_stats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.statement_stats (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    query_id bigint NOT NULL,
    query_text text NOT NULL,
    calls bigint DEFAULT 0 NOT NULL,
    total_exec_time double precision DEFAULT 0.0 NOT NULL,
    mean_exec_time double precision DEFAULT 0.0 NOT NULL,
    rows bigint DEFAULT 0 NOT NULL,
    shared_blks_hit bigint DEFAULT 0 NOT NULL,
    shared_blks_read bigint DEFAULT 0 NOT NULL,
    temp_blks_read bigint DEFAULT 0 NOT NULL,
    temp_blks_written bigint DEFAULT 0 NOT NULL,
    snapshot_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.statement_stats OWNER TO postgres;

--
-- Name: TABLE statement_stats; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.statement_stats IS 'Historical snapshots of pg_stat_statements query execution statistics';


--
-- Name: COLUMN statement_stats.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.id IS 'Unique identifier for each statement statistics record';


--
-- Name: COLUMN statement_stats.query_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.query_id IS 'Internal hash code computed from the statement normalized text';


--
-- Name: COLUMN statement_stats.query_text; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.query_text IS 'Text of the representative statement (normalized)';


--
-- Name: COLUMN statement_stats.calls; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.calls IS 'Number of times the statement was executed';


--
-- Name: COLUMN statement_stats.total_exec_time; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.total_exec_time IS 'Total time spent executing this statement in milliseconds';


--
-- Name: COLUMN statement_stats.mean_exec_time; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.mean_exec_time IS 'Mean time spent executing this statement in milliseconds';


--
-- Name: COLUMN statement_stats.rows; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.rows IS 'Total number of rows retrieved or affected by the statement';


--
-- Name: COLUMN statement_stats.shared_blks_hit; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.shared_blks_hit IS 'Total number of shared block cache hits by the statement';


--
-- Name: COLUMN statement_stats.shared_blks_read; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.shared_blks_read IS 'Total number of shared blocks read by the statement';


--
-- Name: COLUMN statement_stats.temp_blks_read; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.temp_blks_read IS 'Total number of temp blocks read by the statement';


--
-- Name: COLUMN statement_stats.temp_blks_written; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.temp_blks_written IS 'Total number of temp blocks written by the statement';


--
-- Name: COLUMN statement_stats.snapshot_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.snapshot_at IS 'Timestamp when this statistics snapshot was taken';


--
-- Name: COLUMN statement_stats.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.created_at IS 'Timestamp when this record was created';


--
-- Name: COLUMN statement_stats.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats.updated_at IS 'Timestamp when this record was last updated';


--
-- Name: statement_stats_hourly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.statement_stats_hourly (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    hour timestamp with time zone NOT NULL,
    query_id bigint NOT NULL,
    query_text text NOT NULL,
    total_calls bigint DEFAULT 0 NOT NULL,
    avg_exec_time double precision DEFAULT 0.0 NOT NULL,
    total_rows bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.statement_stats_hourly OWNER TO postgres;

--
-- Name: TABLE statement_stats_hourly; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.statement_stats_hourly IS 'Hourly aggregated PostgreSQL query execution statistics for time-series analysis';


--
-- Name: COLUMN statement_stats_hourly.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.id IS 'Unique identifier for each hourly statistics record';


--
-- Name: COLUMN statement_stats_hourly.hour; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.hour IS 'Hour timestamp (truncated to hour boundary) for this aggregation';


--
-- Name: COLUMN statement_stats_hourly.query_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.query_id IS 'Internal hash code computed from the statement normalized text';


--
-- Name: COLUMN statement_stats_hourly.query_text; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.query_text IS 'Text of the representative statement (normalized)';


--
-- Name: COLUMN statement_stats_hourly.total_calls; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.total_calls IS 'Total number of times the statement was executed in this hour';


--
-- Name: COLUMN statement_stats_hourly.avg_exec_time; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.avg_exec_time IS 'Average execution time for this statement in this hour (milliseconds)';


--
-- Name: COLUMN statement_stats_hourly.total_rows; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.total_rows IS 'Total number of rows retrieved or affected by the statement in this hour';


--
-- Name: COLUMN statement_stats_hourly.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.created_at IS 'Timestamp when this record was created';


--
-- Name: COLUMN statement_stats_hourly.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.statement_stats_hourly.updated_at IS 'Timestamp when this record was last updated';


--
-- Name: table_usage_stats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.table_usage_stats (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_name text NOT NULL,
    schema_name text DEFAULT 'public'::text NOT NULL,
    select_count bigint DEFAULT 0 NOT NULL,
    insert_count bigint DEFAULT 0 NOT NULL,
    update_count bigint DEFAULT 0 NOT NULL,
    delete_count bigint DEFAULT 0 NOT NULL,
    snapshot_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.table_usage_stats OWNER TO postgres;

--
-- Name: TABLE table_usage_stats; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.table_usage_stats IS 'Table usage statistics tracking access patterns for database optimization';


--
-- Name: COLUMN table_usage_stats.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.id IS 'Unique identifier for each table usage statistics record';


--
-- Name: COLUMN table_usage_stats.table_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.table_name IS 'Name of the database table being tracked';


--
-- Name: COLUMN table_usage_stats.schema_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.schema_name IS 'Schema name containing the table (default: public)';


--
-- Name: COLUMN table_usage_stats.select_count; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.select_count IS 'Number of SELECT operations performed on this table';


--
-- Name: COLUMN table_usage_stats.insert_count; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.insert_count IS 'Number of INSERT operations performed on this table';


--
-- Name: COLUMN table_usage_stats.update_count; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.update_count IS 'Number of UPDATE operations performed on this table';


--
-- Name: COLUMN table_usage_stats.delete_count; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.delete_count IS 'Number of DELETE operations performed on this table';


--
-- Name: COLUMN table_usage_stats.snapshot_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.snapshot_at IS 'Timestamp when this usage snapshot was taken';


--
-- Name: COLUMN table_usage_stats.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.created_at IS 'Timestamp when this record was created';


--
-- Name: COLUMN table_usage_stats.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.table_usage_stats.updated_at IS 'Timestamp when this record was last updated';


--
-- Name: custom_fields; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.custom_fields (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    field_type character varying(50) NOT NULL,
    description text,
    required boolean DEFAULT false NOT NULL,
    options jsonb,
    "position" integer DEFAULT 0 NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT positive_position CHECK (("position" >= 0)),
    CONSTRAINT valid_field_type CHECK (((field_type)::text = ANY ((ARRAY['text'::character varying, 'textarea'::character varying, 'number'::character varying, 'date'::character varying, 'select'::character varying, 'multiselect'::character varying, 'checkbox'::character varying])::text[])))
);


ALTER TABLE service.custom_fields OWNER TO postgres;

--
-- Name: TABLE custom_fields; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.custom_fields IS 'Custom field definitions for tickets, allowing dynamic form creation';


--
-- Name: COLUMN custom_fields.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.id IS 'Unique identifier for the custom field';


--
-- Name: COLUMN custom_fields.name; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.name IS 'Display name of the custom field';


--
-- Name: COLUMN custom_fields.field_type; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.field_type IS 'Type of field: text, textarea, number, date, select, multiselect, checkbox';


--
-- Name: COLUMN custom_fields.description; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.description IS 'Optional description or help text for the field';


--
-- Name: COLUMN custom_fields.required; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.required IS 'Whether this field is required when filling out tickets';


--
-- Name: COLUMN custom_fields.options; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.options IS 'JSON array of options for select/multiselect fields';


--
-- Name: COLUMN custom_fields."position"; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields."position" IS 'Display order position of the field in forms';


--
-- Name: COLUMN custom_fields.created_by; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.created_by IS 'Reference to user in auth.users who created this custom field';


--
-- Name: COLUMN custom_fields.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.created_at IS 'Timestamp when the field was created';


--
-- Name: COLUMN custom_fields.updated_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.custom_fields.updated_at IS 'Timestamp when the field was last updated';


--
-- Name: ticket_assignments; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.ticket_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    assigned_to uuid,
    assigned_from uuid,
    assigned_by uuid,
    assignment_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE service.ticket_assignments OWNER TO postgres;

--
-- Name: TABLE ticket_assignments; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.ticket_assignments IS 'Assignment history for tickets, tracking ownership changes';


--
-- Name: COLUMN ticket_assignments.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.id IS 'Unique identifier for the assignment record';


--
-- Name: COLUMN ticket_assignments.ticket_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.ticket_id IS 'Reference to the ticket being assigned';


--
-- Name: COLUMN ticket_assignments.assigned_to; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.assigned_to IS 'Reference to user in auth.users the ticket was assigned to (NULL for unassignment)';


--
-- Name: COLUMN ticket_assignments.assigned_from; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.assigned_from IS 'Reference to user in auth.users the ticket was previously assigned to (NULL for initial assignment)';


--
-- Name: COLUMN ticket_assignments.assigned_by; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.assigned_by IS 'Reference to user in auth.users who performed the assignment action';


--
-- Name: COLUMN ticket_assignments.assignment_reason; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.assignment_reason IS 'Optional reason for the assignment change';


--
-- Name: COLUMN ticket_assignments.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_assignments.created_at IS 'Timestamp when the assignment was made';


--
-- Name: ticket_attachments; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.ticket_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid,
    conversation_id uuid,
    blob_id uuid NOT NULL,
    original_filename character varying(255) NOT NULL,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE service.ticket_attachments OWNER TO postgres;

--
-- Name: TABLE ticket_attachments; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.ticket_attachments IS 'File attachments for tickets, references documents.blobs for actual file storage';


--
-- Name: COLUMN ticket_attachments.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.id IS 'Unique identifier for the attachment';


--
-- Name: COLUMN ticket_attachments.ticket_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.ticket_id IS 'Reference to the ticket this attachment belongs to';


--
-- Name: COLUMN ticket_attachments.conversation_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.conversation_id IS 'Reference to the specific conversation message this attachment was added to';


--
-- Name: COLUMN ticket_attachments.blob_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.blob_id IS 'Reference to the blob in documents.blobs table where file is stored';


--
-- Name: COLUMN ticket_attachments.original_filename; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.original_filename IS 'Original filename as uploaded by the user';


--
-- Name: COLUMN ticket_attachments.uploaded_by; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.uploaded_by IS 'Reference to user in auth.users who uploaded this attachment';


--
-- Name: COLUMN ticket_attachments.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_attachments.created_at IS 'Timestamp when the file was uploaded';


--
-- Name: ticket_conversations; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.ticket_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    user_id uuid,
    content text NOT NULL,
    content_type character varying(20) DEFAULT 'text'::character varying,
    is_internal boolean DEFAULT false,
    is_system_message boolean DEFAULT false,
    message_type character varying(20) DEFAULT 'comment'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_content_type CHECK (((content_type)::text = ANY ((ARRAY['text'::character varying, 'html'::character varying])::text[]))),
    CONSTRAINT valid_message_type CHECK (((message_type)::text = ANY ((ARRAY['comment'::character varying, 'status_change'::character varying, 'assignment_change'::character varying])::text[])))
);


ALTER TABLE service.ticket_conversations OWNER TO postgres;

--
-- Name: TABLE ticket_conversations; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.ticket_conversations IS 'Conversation entries for tickets including comments and system messages';


--
-- Name: COLUMN ticket_conversations.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.id IS 'Unique identifier for the conversation entry';


--
-- Name: COLUMN ticket_conversations.ticket_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.ticket_id IS 'Reference to the ticket this conversation belongs to';


--
-- Name: COLUMN ticket_conversations.user_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.user_id IS 'Reference to user in auth.users who wrote this message, NULL for system-generated messages';


--
-- Name: COLUMN ticket_conversations.content; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.content IS 'The actual message content or note';


--
-- Name: COLUMN ticket_conversations.content_type; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.content_type IS 'Format of the content: text or html';


--
-- Name: COLUMN ticket_conversations.is_internal; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.is_internal IS 'Whether this is an internal note (true) or customer-visible message (false)';


--
-- Name: COLUMN ticket_conversations.is_system_message; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.is_system_message IS 'Whether this message was automatically generated by the system';


--
-- Name: COLUMN ticket_conversations.message_type; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.message_type IS 'Type of message: comment, status_change, or assignment_change';


--
-- Name: COLUMN ticket_conversations.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.created_at IS 'Timestamp when the message was created';


--
-- Name: COLUMN ticket_conversations.updated_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_conversations.updated_at IS 'Timestamp when the message was last edited';


--
-- Name: ticket_custom_fields; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.ticket_custom_fields (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    custom_field_id uuid NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE service.ticket_custom_fields OWNER TO postgres;

--
-- Name: TABLE ticket_custom_fields; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.ticket_custom_fields IS 'Values for custom fields associated with tickets';


--
-- Name: COLUMN ticket_custom_fields.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_custom_fields.id IS 'Unique identifier for the custom field value';


--
-- Name: COLUMN ticket_custom_fields.ticket_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_custom_fields.ticket_id IS 'Reference to the ticket this custom field value belongs to';


--
-- Name: COLUMN ticket_custom_fields.custom_field_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_custom_fields.custom_field_id IS 'Reference to the custom field definition';


--
-- Name: COLUMN ticket_custom_fields.value; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_custom_fields.value IS 'The value entered for this custom field (stored as text, JSON for complex types)';


--
-- Name: COLUMN ticket_custom_fields.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_custom_fields.created_at IS 'Timestamp when the custom field value was created';


--
-- Name: COLUMN ticket_custom_fields.updated_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_custom_fields.updated_at IS 'Timestamp when the custom field value was last updated';


--
-- Name: ticket_number_seq; Type: SEQUENCE; Schema: service; Owner: postgres
--

CREATE SEQUENCE service.ticket_number_seq
    START WITH 1000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE service.ticket_number_seq OWNER TO postgres;

--
-- Name: ticket_watchers; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.ticket_watchers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_id uuid NOT NULL,
    user_id uuid NOT NULL,
    added_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE service.ticket_watchers OWNER TO postgres;

--
-- Name: TABLE ticket_watchers; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.ticket_watchers IS 'Users watching tickets for notifications and updates';


--
-- Name: COLUMN ticket_watchers.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_watchers.id IS 'Unique identifier for the watcher record';


--
-- Name: COLUMN ticket_watchers.ticket_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_watchers.ticket_id IS 'Reference to the ticket being watched';


--
-- Name: COLUMN ticket_watchers.user_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_watchers.user_id IS 'Reference to user in auth.users who is watching the ticket';


--
-- Name: COLUMN ticket_watchers.added_by; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_watchers.added_by IS 'Reference to user in auth.users who added this person as a watcher';


--
-- Name: COLUMN ticket_watchers.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.ticket_watchers.created_at IS 'Timestamp when the watcher was added';


--
-- Name: tickets; Type: TABLE; Schema: service; Owner: postgres
--

CREATE TABLE service.tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticket_number character varying(50) NOT NULL,
    subject character varying(255) NOT NULL,
    description text NOT NULL,
    requester_id uuid NOT NULL,
    requester_email character varying(255),
    assignee_id uuid,
    priority character varying(20) DEFAULT 'medium'::character varying NOT NULL,
    status character varying(50) DEFAULT 'open'::character varying NOT NULL,
    source character varying(50) DEFAULT 'web'::character varying,
    tags text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    resolved_at timestamp with time zone,
    closed_at timestamp with time zone,
    CONSTRAINT valid_priority CHECK (((priority)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying])::text[]))),
    CONSTRAINT valid_status CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'pending'::character varying, 'in_progress'::character varying, 'resolved'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE service.tickets OWNER TO postgres;

--
-- Name: TABLE tickets; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON TABLE service.tickets IS 'Main table for customer service tickets';


--
-- Name: COLUMN tickets.id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.id IS 'Unique identifier for the ticket';


--
-- Name: COLUMN tickets.ticket_number; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.ticket_number IS 'Human-readable ticket number displayed to users (e.g., TKT-001234)';


--
-- Name: COLUMN tickets.subject; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.subject IS 'Brief summary of the ticket issue';


--
-- Name: COLUMN tickets.description; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.description IS 'Detailed description of the issue or request';


--
-- Name: COLUMN tickets.requester_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.requester_id IS 'Reference to user in auth.users who submitted the ticket';


--
-- Name: COLUMN tickets.requester_email; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.requester_email IS 'Email of ticket requester, used when requester is not a registered user';


--
-- Name: COLUMN tickets.assignee_id; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.assignee_id IS 'Reference to user in auth.users currently assigned to work on this ticket';


--
-- Name: COLUMN tickets.priority; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.priority IS 'Priority level: low, medium, high, or critical';


--
-- Name: COLUMN tickets.status; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.status IS 'Current status: open, pending, in_progress, resolved, or closed';


--
-- Name: COLUMN tickets.source; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.source IS 'How the ticket was submitted: email, web, phone, or chat';


--
-- Name: COLUMN tickets.tags; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.tags IS 'Array of tags for flexible categorization and searching';


--
-- Name: COLUMN tickets.created_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.created_at IS 'Timestamp when the ticket was created';


--
-- Name: COLUMN tickets.updated_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.updated_at IS 'Timestamp when the ticket was last updated';


--
-- Name: COLUMN tickets.resolved_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.resolved_at IS 'Timestamp when the ticket was marked as resolved';


--
-- Name: COLUMN tickets.closed_at; Type: COMMENT; Schema: service; Owner: postgres
--

COMMENT ON COLUMN service.tickets.closed_at IS 'Timestamp when the ticket was closed';


--
-- Name: notations; Type: TABLE; Schema: standards; Owner: postgres
--

CREATE TABLE standards.notations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    uid text NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    flow jsonb DEFAULT '{}'::jsonb NOT NULL,
    code public.citext NOT NULL,
    document_url character varying(255),
    document_mappings jsonb,
    alignment jsonb DEFAULT '{}'::jsonb NOT NULL,
    respondent_type character varying(255),
    document_text text,
    document_type character varying(255),
    repository character varying(255),
    commit_sha character varying(255),
    published boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT notations_respondent_type_check CHECK (((respondent_type)::text = ANY ((ARRAY['org'::character varying, 'org_and_user'::character varying])::text[])))
);


ALTER TABLE standards.notations OWNER TO postgres;

--
-- Name: TABLE notations; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON TABLE standards.notations IS 'A Notation is a collection of documents, questionnaires, and workflows';


--
-- Name: COLUMN notations.id; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.id IS 'Unique identifier for the notation';


--
-- Name: COLUMN notations.uid; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.uid IS 'User-defined unique identifier for the notation';


--
-- Name: COLUMN notations.title; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.title IS 'Title of the notation';


--
-- Name: COLUMN notations.description; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.description IS 'Detailed description of the notation';


--
-- Name: COLUMN notations.flow; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.flow IS 'How users are presented with questions. Must adhere to @question_map_schema. Empty if published=true';


--
-- Name: COLUMN notations.code; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.code IS 'Case-insensitive unique code identifier for the notation';


--
-- Name: COLUMN notations.document_url; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.document_url IS 'URL reference to the associated document';


--
-- Name: COLUMN notations.document_mappings; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.document_mappings IS 'PDF field placement coordinates. Each mapping defines a rectangle with upper_left, lower_left, upper_right, lower_right coordinates in PDF coordinate system (0,0 at top-left). For Markdown files, use Handlebars instead';


--
-- Name: COLUMN notations.alignment; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.alignment IS 'How staff review questionnaires and provide answers. Must adhere to @question_map_schema. Empty if published=true';


--
-- Name: COLUMN notations.respondent_type; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.respondent_type IS 'Must be "org" or "org_and_user". Determines if notation is for whole org (e.g., Secretary of State filing) or org and user (e.g., 83(b) election). Organization filings may need completion by multiple members';


--
-- Name: COLUMN notations.document_text; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.document_text IS 'Full text content of the associated document';


--
-- Name: COLUMN notations.document_type; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.document_type IS 'Type classification of the associated document';


--
-- Name: COLUMN notations.repository; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.repository IS 'Neon Law GitHub repository where the notation is stored';


--
-- Name: COLUMN notations.commit_sha; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.commit_sha IS 'Latest main branch commit SHA of most recent notation changes';


--
-- Name: COLUMN notations.published; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.published IS 'If true, flow and alignment are empty. Used for public notations like privacy policies posted on websites';


--
-- Name: COLUMN notations.created_at; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.created_at IS 'Timestamp when the notation was created';


--
-- Name: COLUMN notations.updated_at; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations.updated_at IS 'Timestamp when the notation was last updated';


--
-- Name: notations_questions; Type: TABLE; Schema: standards; Owner: postgres
--

CREATE TABLE standards.notations_questions (
    notation_id uuid NOT NULL,
    question_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE standards.notations_questions OWNER TO postgres;

--
-- Name: TABLE notations_questions; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON TABLE standards.notations_questions IS 'Join table linking notations to their associated questions';


--
-- Name: COLUMN notations_questions.notation_id; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations_questions.notation_id IS 'Foreign key reference to the notation';


--
-- Name: COLUMN notations_questions.question_id; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations_questions.question_id IS 'Foreign key reference to the question';


--
-- Name: COLUMN notations_questions.created_at; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations_questions.created_at IS 'Timestamp when the notation-question association was created';


--
-- Name: COLUMN notations_questions.updated_at; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.notations_questions.updated_at IS 'Timestamp when the notation-question association was last updated';


--
-- Name: questions; Type: TABLE; Schema: standards; Owner: postgres
--

CREATE TABLE standards.questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    prompt text NOT NULL,
    question_type text NOT NULL,
    code public.citext NOT NULL,
    help_text text,
    choices jsonb DEFAULT '{"options": []}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT questions_question_type_check CHECK ((question_type = ANY (ARRAY['string'::text, 'text'::text, 'date'::text, 'datetime'::text, 'number'::text, 'yes_no'::text, 'radio'::text, 'select'::text, 'multi_select'::text, 'secret'::text, 'signature'::text, 'notarization'::text, 'phone'::text, 'email'::text, 'ssn'::text, 'ein'::text, 'file'::text, 'person'::text, 'address'::text, 'issuance'::text, 'org'::text, 'document'::text, 'registered_agent'::text])))
);


ALTER TABLE standards.questions OWNER TO postgres;

--
-- Name: TABLE questions; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON TABLE standards.questions IS 'Questions templates used in Sagebrush Standards';


--
-- Name: COLUMN questions.id; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.id IS 'Unique identifier for the question';


--
-- Name: COLUMN questions.prompt; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.prompt IS 'The question text displayed to users';


--
-- Name: COLUMN questions.question_type; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.question_type IS 'Type of input control for the question';


--
-- Name: COLUMN questions.code; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.code IS 'Unique code identifier for referencing the question';


--
-- Name: COLUMN questions.help_text; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.help_text IS 'Additional help text displayed to users';


--
-- Name: COLUMN questions.choices; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.choices IS 'JSON object with options array for select/radio/multi_select types';


--
-- Name: COLUMN questions.created_at; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.created_at IS 'Timestamp when the question was created';


--
-- Name: COLUMN questions.updated_at; Type: COMMENT; Schema: standards; Owner: postgres
--

COMMENT ON COLUMN standards.questions.updated_at IS 'Timestamp when the question was last updated';


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: accounting; Owner: postgres
--

ALTER TABLE ONLY accounting.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: vendors vendors_pkey; Type: CONSTRAINT; Schema: accounting; Owner: postgres
--

ALTER TABLE ONLY accounting.vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (id);


--
-- Name: users auth_users_sub_unique; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT auth_users_sub_unique UNIQUE (sub);


--
-- Name: person_entity_roles person_entity_roles_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.person_entity_roles
    ADD CONSTRAINT person_entity_roles_pkey PRIMARY KEY (id);


--
-- Name: service_account_tokens service_account_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.service_account_tokens
    ADD CONSTRAINT service_account_tokens_pkey PRIMARY KEY (id);


--
-- Name: service_account_tokens service_account_tokens_token_hash_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.service_account_tokens
    ADD CONSTRAINT service_account_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: person_entity_roles unique_person_entity_role; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.person_entity_roles
    ADD CONSTRAINT unique_person_entity_role UNIQUE (person_id, entity_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: people people_email_key; Type: CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.people
    ADD CONSTRAINT people_email_key UNIQUE (email);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: entities uq_entities_name_type; Type: CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.entities
    ADD CONSTRAINT uq_entities_name_type UNIQUE (name, legal_entity_type_id);


--
-- Name: CONSTRAINT uq_entities_name_type ON entities; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON CONSTRAINT uq_entities_name_type ON directory.entities IS 'Ensures entity names are unique within each legal entity type';


--
-- Name: blobs blobs_pkey; Type: CONSTRAINT; Schema: documents; Owner: postgres
--

ALTER TABLE ONLY documents.blobs
    ADD CONSTRAINT blobs_pkey PRIMARY KEY (id);


--
-- Name: blobs unique_blob_reference; Type: CONSTRAINT; Schema: documents; Owner: postgres
--

ALTER TABLE ONLY documents.blobs
    ADD CONSTRAINT unique_blob_reference UNIQUE (referenced_by, referenced_by_id);


--
-- Name: share_classes share_classes_pkey; Type: CONSTRAINT; Schema: equity; Owner: postgres
--

ALTER TABLE ONLY equity.share_classes
    ADD CONSTRAINT share_classes_pkey PRIMARY KEY (id);


--
-- Name: share_issuances share_issuances_pkey; Type: CONSTRAINT; Schema: equity; Owner: postgres
--

ALTER TABLE ONLY equity.share_issuances
    ADD CONSTRAINT share_issuances_pkey PRIMARY KEY (id);


--
-- Name: birth_data birth_data_pkey; Type: CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_data
    ADD CONSTRAINT birth_data_pkey PRIMARY KEY (id);


--
-- Name: birth_date_times birth_date_times_pkey; Type: CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_date_times
    ADD CONSTRAINT birth_date_times_pkey PRIMARY KEY (id);


--
-- Name: birth_locations birth_locations_pkey; Type: CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_locations
    ADD CONSTRAINT birth_locations_pkey PRIMARY KEY (id);


--
-- Name: birth_data uq_birth_data_user_id; Type: CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_data
    ADD CONSTRAINT uq_birth_data_user_id UNIQUE (user_id);


--
-- Name: credentials credentials_pkey; Type: CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.credentials
    ADD CONSTRAINT credentials_pkey PRIMARY KEY (id);


--
-- Name: entity_types entity_types_pkey; Type: CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (id);


--
-- Name: jurisdictions jurisdictions_code_key; Type: CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.jurisdictions
    ADD CONSTRAINT jurisdictions_code_key UNIQUE (code);


--
-- Name: jurisdictions jurisdictions_pkey; Type: CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.jurisdictions
    ADD CONSTRAINT jurisdictions_pkey PRIMARY KEY (id);


--
-- Name: credentials uk_credentials_person_jurisdiction_license; Type: CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.credentials
    ADD CONSTRAINT uk_credentials_person_jurisdiction_license UNIQUE (person_id, jurisdiction_id, license_number);


--
-- Name: entity_types unique_jurisdiction_entity_type; Type: CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.entity_types
    ADD CONSTRAINT unique_jurisdiction_entity_type UNIQUE (legal_jurisdiction_id, name);


--
-- Name: letters letters_pkey; Type: CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.letters
    ADD CONSTRAINT letters_pkey PRIMARY KEY (id);


--
-- Name: mailboxes mailboxes_pkey; Type: CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.mailboxes
    ADD CONSTRAINT mailboxes_pkey PRIMARY KEY (id);


--
-- Name: mailboxes unique_address_mailbox; Type: CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.mailboxes
    ADD CONSTRAINT unique_address_mailbox UNIQUE (directory_address_id, mailbox_number);


--
-- Name: newsletter_analytics newsletter_analytics_pkey; Type: CONSTRAINT; Schema: marketing; Owner: postgres
--

ALTER TABLE ONLY marketing.newsletter_analytics
    ADD CONSTRAINT newsletter_analytics_pkey PRIMARY KEY (id);


--
-- Name: newsletter_templates newsletter_templates_name_key; Type: CONSTRAINT; Schema: marketing; Owner: postgres
--

ALTER TABLE ONLY marketing.newsletter_templates
    ADD CONSTRAINT newsletter_templates_name_key UNIQUE (name);


--
-- Name: newsletter_templates newsletter_templates_pkey; Type: CONSTRAINT; Schema: marketing; Owner: postgres
--

ALTER TABLE ONLY marketing.newsletter_templates
    ADD CONSTRAINT newsletter_templates_pkey PRIMARY KEY (id);


--
-- Name: newsletters newsletters_pkey; Type: CONSTRAINT; Schema: marketing; Owner: postgres
--

ALTER TABLE ONLY marketing.newsletters
    ADD CONSTRAINT newsletters_pkey PRIMARY KEY (id);


--
-- Name: answers answers_pkey; Type: CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.answers
    ADD CONSTRAINT answers_pkey PRIMARY KEY (id);


--
-- Name: assigned_notations assigned_notations_pkey; Type: CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.assigned_notations
    ADD CONSTRAINT assigned_notations_pkey PRIMARY KEY (id);


--
-- Name: disclosures disclosures_pkey; Type: CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.disclosures
    ADD CONSTRAINT disclosures_pkey PRIMARY KEY (id);


--
-- Name: projects projects_codename_key; Type: CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.projects
    ADD CONSTRAINT projects_codename_key UNIQUE (codename);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: relationship_logs relationship_logs_pkey; Type: CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.relationship_logs
    ADD CONSTRAINT relationship_logs_pkey PRIMARY KEY (id);


--
-- Name: lawyer_inquiries lawyer_inquiries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lawyer_inquiries
    ADD CONSTRAINT lawyer_inquiries_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (migration_name);


--
-- Name: statement_stats_hourly statement_stats_hourly_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.statement_stats_hourly
    ADD CONSTRAINT statement_stats_hourly_pkey PRIMARY KEY (id);


--
-- Name: statement_stats statement_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.statement_stats
    ADD CONSTRAINT statement_stats_pkey PRIMARY KEY (id);


--
-- Name: table_usage_stats table_usage_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.table_usage_stats
    ADD CONSTRAINT table_usage_stats_pkey PRIMARY KEY (id);


--
-- Name: table_usage_stats uk_table_usage_stats_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.table_usage_stats
    ADD CONSTRAINT uk_table_usage_stats_unique UNIQUE (schema_name, table_name, snapshot_at);


--
-- Name: custom_fields custom_fields_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.custom_fields
    ADD CONSTRAINT custom_fields_pkey PRIMARY KEY (id);


--
-- Name: ticket_assignments ticket_assignments_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_assignments
    ADD CONSTRAINT ticket_assignments_pkey PRIMARY KEY (id);


--
-- Name: ticket_attachments ticket_attachments_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_attachments
    ADD CONSTRAINT ticket_attachments_pkey PRIMARY KEY (id);


--
-- Name: ticket_conversations ticket_conversations_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_conversations
    ADD CONSTRAINT ticket_conversations_pkey PRIMARY KEY (id);


--
-- Name: ticket_custom_fields ticket_custom_fields_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_custom_fields
    ADD CONSTRAINT ticket_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: ticket_watchers ticket_watchers_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_watchers
    ADD CONSTRAINT ticket_watchers_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_ticket_number_key; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.tickets
    ADD CONSTRAINT tickets_ticket_number_key UNIQUE (ticket_number);


--
-- Name: custom_fields unique_custom_field_name; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.custom_fields
    ADD CONSTRAINT unique_custom_field_name UNIQUE (name);


--
-- Name: ticket_custom_fields unique_ticket_custom_field; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_custom_fields
    ADD CONSTRAINT unique_ticket_custom_field UNIQUE (ticket_id, custom_field_id);


--
-- Name: ticket_watchers unique_ticket_watcher; Type: CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_watchers
    ADD CONSTRAINT unique_ticket_watcher UNIQUE (ticket_id, user_id);


--
-- Name: notations notations_code_unique; Type: CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.notations
    ADD CONSTRAINT notations_code_unique UNIQUE (code);


--
-- Name: notations notations_pkey; Type: CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.notations
    ADD CONSTRAINT notations_pkey PRIMARY KEY (id);


--
-- Name: notations_questions notations_questions_pkey; Type: CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.notations_questions
    ADD CONSTRAINT notations_questions_pkey PRIMARY KEY (notation_id, question_id);


--
-- Name: notations notations_uid_unique; Type: CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.notations
    ADD CONSTRAINT notations_uid_unique UNIQUE (uid);


--
-- Name: questions questions_code_key; Type: CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.questions
    ADD CONSTRAINT questions_code_key UNIQUE (code);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: idx_invoices_invoiced_from; Type: INDEX; Schema: accounting; Owner: postgres
--

CREATE INDEX idx_invoices_invoiced_from ON accounting.invoices USING btree (invoiced_from);


--
-- Name: idx_invoices_sent_at; Type: INDEX; Schema: accounting; Owner: postgres
--

CREATE INDEX idx_invoices_sent_at ON accounting.invoices USING btree (sent_at);


--
-- Name: idx_invoices_vendor_id; Type: INDEX; Schema: accounting; Owner: postgres
--

CREATE INDEX idx_invoices_vendor_id ON accounting.invoices USING btree (vendor_id);


--
-- Name: idx_vendors_entity_id; Type: INDEX; Schema: accounting; Owner: postgres
--

CREATE INDEX idx_vendors_entity_id ON accounting.vendors USING btree (entity_id);


--
-- Name: idx_vendors_person_id; Type: INDEX; Schema: accounting; Owner: postgres
--

CREATE INDEX idx_vendors_person_id ON accounting.vendors USING btree (person_id);


--
-- Name: idx_auth_users_sub; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_auth_users_sub ON auth.users USING btree (sub) WHERE (sub IS NOT NULL);


--
-- Name: idx_person_entity_roles_entity_id; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_person_entity_roles_entity_id ON auth.person_entity_roles USING btree (entity_id);


--
-- Name: idx_person_entity_roles_person_id; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_person_entity_roles_person_id ON auth.person_entity_roles USING btree (person_id);


--
-- Name: idx_person_entity_roles_role; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_person_entity_roles_role ON auth.person_entity_roles USING btree (role);


--
-- Name: idx_service_account_tokens_active; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_service_account_tokens_active ON auth.service_account_tokens USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_service_account_tokens_expires_at; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_service_account_tokens_expires_at ON auth.service_account_tokens USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: idx_service_account_tokens_service_type; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_service_account_tokens_service_type ON auth.service_account_tokens USING btree (service_type);


--
-- Name: idx_service_account_tokens_token_hash; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_service_account_tokens_token_hash ON auth.service_account_tokens USING btree (token_hash);


--
-- Name: idx_users_person_id; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_person_id ON auth.users USING btree (person_id);


--
-- Name: idx_users_role; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_role ON auth.users USING btree (role);


--
-- Name: idx_users_subscribed_newsletters_sci_tech; Type: INDEX; Schema: auth; Owner: postgres
--

CREATE INDEX idx_users_subscribed_newsletters_sci_tech ON auth.users USING btree (((subscribed_newsletters ->> 'sci_tech'::text))) WHERE ((subscribed_newsletters ->> 'sci_tech'::text) IS NOT NULL);


--
-- Name: idx_address_entity_id; Type: INDEX; Schema: directory; Owner: postgres
--

CREATE INDEX idx_address_entity_id ON directory.addresses USING btree (entity_id);


--
-- Name: idx_address_is_verified; Type: INDEX; Schema: directory; Owner: postgres
--

CREATE INDEX idx_address_is_verified ON directory.addresses USING btree (is_verified);


--
-- Name: idx_address_person_id; Type: INDEX; Schema: directory; Owner: postgres
--

CREATE INDEX idx_address_person_id ON directory.addresses USING btree (person_id);


--
-- Name: idx_entities_legal_entity_type_id; Type: INDEX; Schema: directory; Owner: postgres
--

CREATE INDEX idx_entities_legal_entity_type_id ON directory.entities USING btree (legal_entity_type_id);


--
-- Name: idx_blobs_created_at; Type: INDEX; Schema: documents; Owner: postgres
--

CREATE INDEX idx_blobs_created_at ON documents.blobs USING btree (created_at);


--
-- Name: idx_blobs_referenced; Type: INDEX; Schema: documents; Owner: postgres
--

CREATE INDEX idx_blobs_referenced ON documents.blobs USING btree (referenced_by, referenced_by_id);


--
-- Name: idx_share_classes_entity_id; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE INDEX idx_share_classes_entity_id ON equity.share_classes USING btree (entity_id);


--
-- Name: idx_share_classes_entity_priority_unique; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE UNIQUE INDEX idx_share_classes_entity_priority_unique ON equity.share_classes USING btree (entity_id, priority);


--
-- Name: idx_share_issuances_calendar_year; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE INDEX idx_share_issuances_calendar_year ON equity.share_issuances USING btree (calendar_year);


--
-- Name: idx_share_issuances_document_id; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE INDEX idx_share_issuances_document_id ON equity.share_issuances USING btree (document_id);


--
-- Name: idx_share_issuances_holder_id; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE INDEX idx_share_issuances_holder_id ON equity.share_issuances USING btree (holder_id);


--
-- Name: idx_share_issuances_share_class_id; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE INDEX idx_share_issuances_share_class_id ON equity.share_issuances USING btree (share_class_id);


--
-- Name: idx_share_issuances_taxable_year; Type: INDEX; Schema: equity; Owner: postgres
--

CREATE INDEX idx_share_issuances_taxable_year ON equity.share_issuances USING btree (taxable_year);


--
-- Name: idx_birth_data_date_time_id; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_data_date_time_id ON ethereal.birth_data USING btree (date_time_id);


--
-- Name: idx_birth_data_location_id; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_data_location_id ON ethereal.birth_data USING btree (location_id);


--
-- Name: idx_birth_data_user_id; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_data_user_id ON ethereal.birth_data USING btree (user_id);


--
-- Name: idx_birth_date_times_birth_date; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_date_times_birth_date ON ethereal.birth_date_times USING btree (birth_date);


--
-- Name: idx_birth_date_times_utc_timestamp; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_date_times_utc_timestamp ON ethereal.birth_date_times USING btree (utc_timestamp);


--
-- Name: idx_birth_locations_city_country; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_locations_city_country ON ethereal.birth_locations USING btree (city, country);


--
-- Name: idx_birth_locations_coordinates; Type: INDEX; Schema: ethereal; Owner: postgres
--

CREATE INDEX idx_birth_locations_coordinates ON ethereal.birth_locations USING btree (latitude, longitude);


--
-- Name: idx_credentials_jurisdiction_id; Type: INDEX; Schema: legal; Owner: postgres
--

CREATE INDEX idx_credentials_jurisdiction_id ON legal.credentials USING btree (jurisdiction_id);


--
-- Name: idx_credentials_license_number; Type: INDEX; Schema: legal; Owner: postgres
--

CREATE INDEX idx_credentials_license_number ON legal.credentials USING btree (license_number);


--
-- Name: idx_credentials_person_id; Type: INDEX; Schema: legal; Owner: postgres
--

CREATE INDEX idx_credentials_person_id ON legal.credentials USING btree (person_id);


--
-- Name: idx_entity_types_jurisdiction; Type: INDEX; Schema: legal; Owner: postgres
--

CREATE INDEX idx_entity_types_jurisdiction ON legal.entity_types USING btree (legal_jurisdiction_id);


--
-- Name: idx_letters_is_priority; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_is_priority ON mail.letters USING btree (is_priority);


--
-- Name: idx_letters_mailbox_id; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_mailbox_id ON mail.letters USING btree (mailbox_id);


--
-- Name: idx_letters_received_date; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_received_date ON mail.letters USING btree (received_date);


--
-- Name: idx_letters_scanned_by; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_scanned_by ON mail.letters USING btree (scanned_by);


--
-- Name: idx_letters_scanned_document_id; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_scanned_document_id ON mail.letters USING btree (scanned_document_id);


--
-- Name: idx_letters_sender_address_id; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_sender_address_id ON mail.letters USING btree (sender_address_id);


--
-- Name: idx_letters_status; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_letters_status ON mail.letters USING btree (status);


--
-- Name: idx_mailboxes_directory_address_id; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_mailboxes_directory_address_id ON mail.mailboxes USING btree (directory_address_id);


--
-- Name: idx_mailboxes_is_active; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_mailboxes_is_active ON mail.mailboxes USING btree (is_active);


--
-- Name: idx_mailboxes_mailbox_number; Type: INDEX; Schema: mail; Owner: postgres
--

CREATE INDEX idx_mailboxes_mailbox_number ON mail.mailboxes USING btree (mailbox_number);


--
-- Name: idx_newsletter_analytics_created_at; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_analytics_created_at ON marketing.newsletter_analytics USING btree (created_at);


--
-- Name: idx_newsletter_analytics_event_type; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_analytics_event_type ON marketing.newsletter_analytics USING btree (event_type);


--
-- Name: idx_newsletter_analytics_newsletter_event; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_analytics_newsletter_event ON marketing.newsletter_analytics USING btree (newsletter_id, event_type);


--
-- Name: idx_newsletter_analytics_newsletter_id; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_analytics_newsletter_id ON marketing.newsletter_analytics USING btree (newsletter_id);


--
-- Name: idx_newsletter_analytics_user_id; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_analytics_user_id ON marketing.newsletter_analytics USING btree (user_id);


--
-- Name: idx_newsletter_templates_category; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_templates_category ON marketing.newsletter_templates USING btree (category);


--
-- Name: idx_newsletter_templates_created_by; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_templates_created_by ON marketing.newsletter_templates USING btree (created_by);


--
-- Name: idx_newsletter_templates_is_active; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletter_templates_is_active ON marketing.newsletter_templates USING btree (is_active);


--
-- Name: idx_newsletters_created_by; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletters_created_by ON marketing.newsletters USING btree (created_by);


--
-- Name: idx_newsletters_name; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletters_name ON marketing.newsletters USING btree (name);


--
-- Name: idx_newsletters_sent_at; Type: INDEX; Schema: marketing; Owner: postgres
--

CREATE INDEX idx_newsletters_sent_at ON marketing.newsletters USING btree (sent_at);


--
-- Name: idx_answers_answerer_entity; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_answerer_entity ON matters.answers USING btree (answerer_id, entity_id);


--
-- Name: idx_answers_answerer_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_answerer_id ON matters.answers USING btree (answerer_id);


--
-- Name: idx_answers_assigned_notation_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_assigned_notation_id ON matters.answers USING btree (assigned_notation_id);


--
-- Name: idx_answers_assigned_notation_question; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_assigned_notation_question ON matters.answers USING btree (assigned_notation_id, question_id);


--
-- Name: idx_answers_blob_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_blob_id ON matters.answers USING btree (blob_id);


--
-- Name: idx_answers_created_at; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_created_at ON matters.answers USING btree (created_at);


--
-- Name: idx_answers_entity_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_entity_id ON matters.answers USING btree (entity_id);


--
-- Name: idx_answers_entity_question; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_entity_question ON matters.answers USING btree (entity_id, question_id);


--
-- Name: idx_answers_question_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_answers_question_id ON matters.answers USING btree (question_id);


--
-- Name: idx_assigned_notations_due_at; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_assigned_notations_due_at ON matters.assigned_notations USING btree (due_at);


--
-- Name: idx_assigned_notations_entity_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_assigned_notations_entity_id ON matters.assigned_notations USING btree (entity_id);


--
-- Name: idx_assigned_notations_notation_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_assigned_notations_notation_id ON matters.assigned_notations USING btree (notation_id);


--
-- Name: idx_assigned_notations_person_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_assigned_notations_person_id ON matters.assigned_notations USING btree (person_id);


--
-- Name: idx_assigned_notations_project_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_assigned_notations_project_id ON matters.assigned_notations USING btree (project_id);


--
-- Name: idx_assigned_notations_state; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_assigned_notations_state ON matters.assigned_notations USING btree (state);


--
-- Name: idx_disclosures_active; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_disclosures_active ON matters.disclosures USING btree (active);


--
-- Name: idx_disclosures_credential_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_disclosures_credential_id ON matters.disclosures USING btree (credential_id);


--
-- Name: idx_disclosures_credential_project; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_disclosures_credential_project ON matters.disclosures USING btree (credential_id, project_id);


--
-- Name: idx_disclosures_disclosed_at; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_disclosures_disclosed_at ON matters.disclosures USING btree (disclosed_at);


--
-- Name: idx_disclosures_end_disclosed_at; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_disclosures_end_disclosed_at ON matters.disclosures USING btree (end_disclosed_at);


--
-- Name: idx_disclosures_project_id; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_disclosures_project_id ON matters.disclosures USING btree (project_id);


--
-- Name: idx_projects_codename; Type: INDEX; Schema: matters; Owner: postgres
--

CREATE INDEX idx_projects_codename ON matters.projects USING btree (codename);


--
-- Name: idx_lawyer_inquiries_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lawyer_inquiries_created_at ON public.lawyer_inquiries USING btree (created_at DESC);


--
-- Name: idx_lawyer_inquiries_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lawyer_inquiries_email ON public.lawyer_inquiries USING btree (email);


--
-- Name: idx_lawyer_inquiries_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lawyer_inquiries_status ON public.lawyer_inquiries USING btree (inquiry_status);


--
-- Name: idx_statement_stats_hourly_avg_exec_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_hourly_avg_exec_time ON public.statement_stats_hourly USING btree (avg_exec_time DESC);


--
-- Name: idx_statement_stats_hourly_hour; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_hourly_hour ON public.statement_stats_hourly USING btree (hour DESC);


--
-- Name: INDEX idx_statement_stats_hourly_hour; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON INDEX public.idx_statement_stats_hourly_hour IS 'Index for time-based filtering and ordering on statement_stats_hourly';


--
-- Name: idx_statement_stats_hourly_hour_query; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_hourly_hour_query ON public.statement_stats_hourly USING btree (hour, query_id);


--
-- Name: INDEX idx_statement_stats_hourly_hour_query; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON INDEX public.idx_statement_stats_hourly_hour_query IS 'Composite index for efficient time series and query-specific filtering on statement_stats_hourly';


--
-- Name: idx_statement_stats_hourly_hour_query_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_statement_stats_hourly_hour_query_unique ON public.statement_stats_hourly USING btree (hour, query_id);


--
-- Name: idx_statement_stats_hourly_query_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_hourly_query_id ON public.statement_stats_hourly USING btree (query_id);


--
-- Name: idx_statement_stats_query_id_snapshot; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_query_id_snapshot ON public.statement_stats USING btree (query_id, snapshot_at DESC);


--
-- Name: INDEX idx_statement_stats_query_id_snapshot; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON INDEX public.idx_statement_stats_query_id_snapshot IS 'Composite index for efficient query_id and time-based filtering on statement_stats';


--
-- Name: idx_statement_stats_snapshot_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_snapshot_at ON public.statement_stats USING btree (snapshot_at DESC);


--
-- Name: INDEX idx_statement_stats_snapshot_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON INDEX public.idx_statement_stats_snapshot_at IS 'Index for time-based filtering and ordering on statement_stats';


--
-- Name: idx_statement_stats_total_exec_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_statement_stats_total_exec_time ON public.statement_stats USING btree (total_exec_time DESC);


--
-- Name: idx_table_usage_stats_schema_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_table_usage_stats_schema_name ON public.table_usage_stats USING btree (schema_name);


--
-- Name: idx_table_usage_stats_snapshot_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_table_usage_stats_snapshot_at ON public.table_usage_stats USING btree (snapshot_at DESC);


--
-- Name: idx_table_usage_stats_table_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_table_usage_stats_table_name ON public.table_usage_stats USING btree (table_name);


--
-- Name: idx_table_usage_stats_table_schema_snapshot_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_table_usage_stats_table_schema_snapshot_unique ON public.table_usage_stats USING btree (table_name, schema_name, snapshot_at);


--
-- Name: idx_table_usage_stats_total_operations; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_table_usage_stats_total_operations ON public.table_usage_stats USING btree (((((select_count + insert_count) + update_count) + delete_count)) DESC);


--
-- Name: idx_service_custom_fields_position; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_custom_fields_position ON service.custom_fields USING btree ("position");


--
-- Name: idx_service_custom_fields_type; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_custom_fields_type ON service.custom_fields USING btree (field_type);


--
-- Name: idx_service_ticket_assignments_ticket; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_assignments_ticket ON service.ticket_assignments USING btree (ticket_id);


--
-- Name: idx_service_ticket_attachments_blob; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_attachments_blob ON service.ticket_attachments USING btree (blob_id);


--
-- Name: idx_service_ticket_attachments_ticket; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_attachments_ticket ON service.ticket_attachments USING btree (ticket_id);


--
-- Name: idx_service_ticket_conversations_created; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_conversations_created ON service.ticket_conversations USING btree (created_at);


--
-- Name: idx_service_ticket_conversations_ticket; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_conversations_ticket ON service.ticket_conversations USING btree (ticket_id);


--
-- Name: idx_service_ticket_custom_fields_field; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_custom_fields_field ON service.ticket_custom_fields USING btree (custom_field_id);


--
-- Name: idx_service_ticket_custom_fields_ticket; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_custom_fields_ticket ON service.ticket_custom_fields USING btree (ticket_id);


--
-- Name: idx_service_ticket_watchers_ticket; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_watchers_ticket ON service.ticket_watchers USING btree (ticket_id);


--
-- Name: idx_service_ticket_watchers_user; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_ticket_watchers_user ON service.ticket_watchers USING btree (user_id);


--
-- Name: idx_service_tickets_assignee; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_tickets_assignee ON service.tickets USING btree (assignee_id);


--
-- Name: idx_service_tickets_created_at; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_tickets_created_at ON service.tickets USING btree (created_at);


--
-- Name: idx_service_tickets_priority; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_tickets_priority ON service.tickets USING btree (priority);


--
-- Name: idx_service_tickets_requester; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_tickets_requester ON service.tickets USING btree (requester_id);


--
-- Name: idx_service_tickets_status; Type: INDEX; Schema: service; Owner: postgres
--

CREATE INDEX idx_service_tickets_status ON service.tickets USING btree (status);


--
-- Name: idx_notations_code; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_notations_code ON standards.notations USING btree (code);


--
-- Name: idx_notations_document_type; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_notations_document_type ON standards.notations USING btree (document_type);


--
-- Name: idx_notations_published; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_notations_published ON standards.notations USING btree (published);


--
-- Name: idx_notations_questions_notation_id; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_notations_questions_notation_id ON standards.notations_questions USING btree (notation_id);


--
-- Name: idx_notations_questions_question_id; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_notations_questions_question_id ON standards.notations_questions USING btree (question_id);


--
-- Name: idx_standards_questions_code; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_standards_questions_code ON standards.questions USING btree (code);


--
-- Name: idx_standards_questions_question_type; Type: INDEX; Schema: standards; Owner: postgres
--

CREATE INDEX idx_standards_questions_question_type ON standards.questions USING btree (question_type);


--
-- Name: invoices update_accounting_invoices_updated_at; Type: TRIGGER; Schema: accounting; Owner: postgres
--

CREATE TRIGGER update_accounting_invoices_updated_at BEFORE UPDATE ON accounting.invoices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: vendors update_accounting_vendors_updated_at; Type: TRIGGER; Schema: accounting; Owner: postgres
--

CREATE TRIGGER update_accounting_vendors_updated_at BEFORE UPDATE ON accounting.vendors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users prevent_admin_user_deletion; Type: TRIGGER; Schema: auth; Owner: postgres
--

CREATE TRIGGER prevent_admin_user_deletion BEFORE DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.prevent_system_admin_deletion();


--
-- Name: TRIGGER prevent_admin_user_deletion ON users; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON TRIGGER prevent_admin_user_deletion ON auth.users IS 'Prevents deletion of system administrator user account (admin@neonlaw.com)';


--
-- Name: person_entity_roles update_person_entity_roles_updated_at; Type: TRIGGER; Schema: auth; Owner: postgres
--

CREATE TRIGGER update_person_entity_roles_updated_at BEFORE UPDATE ON auth.person_entity_roles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: auth; Owner: postgres
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: people prevent_admin_person_deletion; Type: TRIGGER; Schema: directory; Owner: postgres
--

CREATE TRIGGER prevent_admin_person_deletion BEFORE DELETE ON directory.people FOR EACH ROW EXECUTE FUNCTION public.prevent_system_admin_deletion();


--
-- Name: TRIGGER prevent_admin_person_deletion ON people; Type: COMMENT; Schema: directory; Owner: postgres
--

COMMENT ON TRIGGER prevent_admin_person_deletion ON directory.people IS 'Prevents deletion of system administrator person record (admin@neonlaw.com)';


--
-- Name: addresses update_directory_addresses_updated_at; Type: TRIGGER; Schema: directory; Owner: postgres
--

CREATE TRIGGER update_directory_addresses_updated_at BEFORE UPDATE ON directory.addresses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: entities update_directory_entities_updated_at; Type: TRIGGER; Schema: directory; Owner: postgres
--

CREATE TRIGGER update_directory_entities_updated_at BEFORE UPDATE ON directory.entities FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: people update_people_updated_at; Type: TRIGGER; Schema: directory; Owner: postgres
--

CREATE TRIGGER update_people_updated_at BEFORE UPDATE ON directory.people FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: blobs update_documents_blobs_updated_at; Type: TRIGGER; Schema: documents; Owner: postgres
--

CREATE TRIGGER update_documents_blobs_updated_at BEFORE UPDATE ON documents.blobs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: share_classes update_equity_share_classes_updated_at; Type: TRIGGER; Schema: equity; Owner: postgres
--

CREATE TRIGGER update_equity_share_classes_updated_at BEFORE UPDATE ON equity.share_classes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: share_issuances update_equity_share_issuances_updated_at; Type: TRIGGER; Schema: equity; Owner: postgres
--

CREATE TRIGGER update_equity_share_issuances_updated_at BEFORE UPDATE ON equity.share_issuances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: birth_data update_birth_data_updated_at; Type: TRIGGER; Schema: ethereal; Owner: postgres
--

CREATE TRIGGER update_birth_data_updated_at BEFORE UPDATE ON ethereal.birth_data FOR EACH ROW EXECUTE FUNCTION ethereal.update_birth_data_updated_at();


--
-- Name: birth_date_times update_birth_date_times_updated_at; Type: TRIGGER; Schema: ethereal; Owner: postgres
--

CREATE TRIGGER update_birth_date_times_updated_at BEFORE UPDATE ON ethereal.birth_date_times FOR EACH ROW EXECUTE FUNCTION ethereal.update_birth_date_times_updated_at();


--
-- Name: birth_locations update_birth_locations_updated_at; Type: TRIGGER; Schema: ethereal; Owner: postgres
--

CREATE TRIGGER update_birth_locations_updated_at BEFORE UPDATE ON ethereal.birth_locations FOR EACH ROW EXECUTE FUNCTION ethereal.update_birth_locations_updated_at();


--
-- Name: credentials update_credentials_updated_at; Type: TRIGGER; Schema: legal; Owner: postgres
--

CREATE TRIGGER update_credentials_updated_at BEFORE UPDATE ON legal.credentials FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: entity_types update_entity_types_updated_at; Type: TRIGGER; Schema: legal; Owner: postgres
--

CREATE TRIGGER update_entity_types_updated_at BEFORE UPDATE ON legal.entity_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: jurisdictions update_jurisdictions_updated_at; Type: TRIGGER; Schema: legal; Owner: postgres
--

CREATE TRIGGER update_jurisdictions_updated_at BEFORE UPDATE ON legal.jurisdictions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: letters update_mail_letters_updated_at; Type: TRIGGER; Schema: mail; Owner: postgres
--

CREATE TRIGGER update_mail_letters_updated_at BEFORE UPDATE ON mail.letters FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: mailboxes update_mail_mailboxes_updated_at; Type: TRIGGER; Schema: mail; Owner: postgres
--

CREATE TRIGGER update_mail_mailboxes_updated_at BEFORE UPDATE ON mail.mailboxes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: newsletter_templates update_newsletter_templates_updated_at; Type: TRIGGER; Schema: marketing; Owner: postgres
--

CREATE TRIGGER update_newsletter_templates_updated_at BEFORE UPDATE ON marketing.newsletter_templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: newsletters update_newsletters_updated_at; Type: TRIGGER; Schema: marketing; Owner: postgres
--

CREATE TRIGGER update_newsletters_updated_at BEFORE UPDATE ON marketing.newsletters FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: relationship_logs trigger_update_relationship_logs_updated_at; Type: TRIGGER; Schema: matters; Owner: postgres
--

CREATE TRIGGER trigger_update_relationship_logs_updated_at BEFORE UPDATE ON matters.relationship_logs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: answers update_matters_answers_updated_at; Type: TRIGGER; Schema: matters; Owner: postgres
--

CREATE TRIGGER update_matters_answers_updated_at BEFORE UPDATE ON matters.answers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: assigned_notations update_matters_assigned_notations_updated_at; Type: TRIGGER; Schema: matters; Owner: postgres
--

CREATE TRIGGER update_matters_assigned_notations_updated_at BEFORE UPDATE ON matters.assigned_notations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: disclosures update_matters_disclosures_updated_at; Type: TRIGGER; Schema: matters; Owner: postgres
--

CREATE TRIGGER update_matters_disclosures_updated_at BEFORE UPDATE ON matters.disclosures FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: projects update_matters_projects_updated_at; Type: TRIGGER; Schema: matters; Owner: postgres
--

CREATE TRIGGER update_matters_projects_updated_at BEFORE UPDATE ON matters.projects FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: lawyer_inquiries update_lawyer_inquiries_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_lawyer_inquiries_updated_at BEFORE UPDATE ON public.lawyer_inquiries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: statement_stats_hourly update_statement_stats_hourly_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_statement_stats_hourly_updated_at BEFORE UPDATE ON public.statement_stats_hourly FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: statement_stats update_statement_stats_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_statement_stats_updated_at BEFORE UPDATE ON public.statement_stats FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: table_usage_stats update_table_usage_stats_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_table_usage_stats_updated_at BEFORE UPDATE ON public.table_usage_stats FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: tickets trigger_set_ticket_number; Type: TRIGGER; Schema: service; Owner: postgres
--

CREATE TRIGGER trigger_set_ticket_number BEFORE INSERT ON service.tickets FOR EACH ROW EXECUTE FUNCTION service.set_ticket_number();


--
-- Name: ticket_conversations trigger_ticket_conversations_updated_at; Type: TRIGGER; Schema: service; Owner: postgres
--

CREATE TRIGGER trigger_ticket_conversations_updated_at BEFORE UPDATE ON service.ticket_conversations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: tickets trigger_tickets_updated_at; Type: TRIGGER; Schema: service; Owner: postgres
--

CREATE TRIGGER trigger_tickets_updated_at BEFORE UPDATE ON service.tickets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: notations_questions update_standards_notations_questions_updated_at; Type: TRIGGER; Schema: standards; Owner: postgres
--

CREATE TRIGGER update_standards_notations_questions_updated_at BEFORE UPDATE ON standards.notations_questions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: notations update_standards_notations_updated_at; Type: TRIGGER; Schema: standards; Owner: postgres
--

CREATE TRIGGER update_standards_notations_updated_at BEFORE UPDATE ON standards.notations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: questions update_standards_questions_updated_at; Type: TRIGGER; Schema: standards; Owner: postgres
--

CREATE TRIGGER update_standards_questions_updated_at BEFORE UPDATE ON standards.questions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: invoices fk_invoices_vendor; Type: FK CONSTRAINT; Schema: accounting; Owner: postgres
--

ALTER TABLE ONLY accounting.invoices
    ADD CONSTRAINT fk_invoices_vendor FOREIGN KEY (vendor_id) REFERENCES accounting.vendors(id);


--
-- Name: vendors fk_vendors_entity; Type: FK CONSTRAINT; Schema: accounting; Owner: postgres
--

ALTER TABLE ONLY accounting.vendors
    ADD CONSTRAINT fk_vendors_entity FOREIGN KEY (entity_id) REFERENCES directory.entities(id);


--
-- Name: vendors fk_vendors_person; Type: FK CONSTRAINT; Schema: accounting; Owner: postgres
--

ALTER TABLE ONLY accounting.vendors
    ADD CONSTRAINT fk_vendors_person FOREIGN KEY (person_id) REFERENCES directory.people(id);


--
-- Name: users fk_auth_users_username_directory_people_email; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT fk_auth_users_username_directory_people_email FOREIGN KEY (username) REFERENCES directory.people(email);


--
-- Name: CONSTRAINT fk_auth_users_username_directory_people_email ON users; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON CONSTRAINT fk_auth_users_username_directory_people_email ON auth.users IS 'Ensures that auth.users.username must correspond to a valid directory.people.email record. This enforces referential integrity between authentication and directory systems.';


--
-- Name: users fk_users_person_id; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT fk_users_person_id FOREIGN KEY (person_id) REFERENCES directory.people(id);


--
-- Name: person_entity_roles person_entity_roles_entity_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.person_entity_roles
    ADD CONSTRAINT person_entity_roles_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES directory.entities(id) ON DELETE CASCADE;


--
-- Name: person_entity_roles person_entity_roles_person_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: postgres
--

ALTER TABLE ONLY auth.person_entity_roles
    ADD CONSTRAINT person_entity_roles_person_id_fkey FOREIGN KEY (person_id) REFERENCES directory.people(id) ON DELETE CASCADE;


--
-- Name: addresses fk_addresses_entity; Type: FK CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.addresses
    ADD CONSTRAINT fk_addresses_entity FOREIGN KEY (entity_id) REFERENCES directory.entities(id);


--
-- Name: addresses fk_addresses_person; Type: FK CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.addresses
    ADD CONSTRAINT fk_addresses_person FOREIGN KEY (person_id) REFERENCES directory.people(id);


--
-- Name: entities fk_entities_entity_type; Type: FK CONSTRAINT; Schema: directory; Owner: postgres
--

ALTER TABLE ONLY directory.entities
    ADD CONSTRAINT fk_entities_entity_type FOREIGN KEY (legal_entity_type_id) REFERENCES legal.entity_types(id);


--
-- Name: share_classes fk_share_classes_entity; Type: FK CONSTRAINT; Schema: equity; Owner: postgres
--

ALTER TABLE ONLY equity.share_classes
    ADD CONSTRAINT fk_share_classes_entity FOREIGN KEY (entity_id) REFERENCES directory.entities(id);


--
-- Name: share_issuances fk_share_issuances_document; Type: FK CONSTRAINT; Schema: equity; Owner: postgres
--

ALTER TABLE ONLY equity.share_issuances
    ADD CONSTRAINT fk_share_issuances_document FOREIGN KEY (document_id) REFERENCES documents.blobs(id);


--
-- Name: share_issuances fk_share_issuances_holder; Type: FK CONSTRAINT; Schema: equity; Owner: postgres
--

ALTER TABLE ONLY equity.share_issuances
    ADD CONSTRAINT fk_share_issuances_holder FOREIGN KEY (holder_id) REFERENCES directory.entities(id);


--
-- Name: share_issuances fk_share_issuances_share_class; Type: FK CONSTRAINT; Schema: equity; Owner: postgres
--

ALTER TABLE ONLY equity.share_issuances
    ADD CONSTRAINT fk_share_issuances_share_class FOREIGN KEY (share_class_id) REFERENCES equity.share_classes(id);


--
-- Name: birth_data fk_birth_data_date_time; Type: FK CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_data
    ADD CONSTRAINT fk_birth_data_date_time FOREIGN KEY (date_time_id) REFERENCES ethereal.birth_date_times(id) ON DELETE RESTRICT;


--
-- Name: birth_data fk_birth_data_location; Type: FK CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_data
    ADD CONSTRAINT fk_birth_data_location FOREIGN KEY (location_id) REFERENCES ethereal.birth_locations(id) ON DELETE RESTRICT;


--
-- Name: birth_data fk_birth_data_user; Type: FK CONSTRAINT; Schema: ethereal; Owner: postgres
--

ALTER TABLE ONLY ethereal.birth_data
    ADD CONSTRAINT fk_birth_data_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: CONSTRAINT fk_birth_data_user ON birth_data; Type: COMMENT; Schema: ethereal; Owner: postgres
--

COMMENT ON CONSTRAINT fk_birth_data_user ON ethereal.birth_data IS 'Links birth data to user accounts with cascade delete for data privacy';


--
-- Name: credentials fk_credentials_jurisdiction; Type: FK CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.credentials
    ADD CONSTRAINT fk_credentials_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES legal.jurisdictions(id) ON DELETE CASCADE;


--
-- Name: credentials fk_credentials_person; Type: FK CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.credentials
    ADD CONSTRAINT fk_credentials_person FOREIGN KEY (person_id) REFERENCES directory.people(id) ON DELETE CASCADE;


--
-- Name: entity_types fk_entity_types_jurisdiction; Type: FK CONSTRAINT; Schema: legal; Owner: postgres
--

ALTER TABLE ONLY legal.entity_types
    ADD CONSTRAINT fk_entity_types_jurisdiction FOREIGN KEY (legal_jurisdiction_id) REFERENCES legal.jurisdictions(id);


--
-- Name: letters fk_letter_mailbox; Type: FK CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.letters
    ADD CONSTRAINT fk_letter_mailbox FOREIGN KEY (mailbox_id) REFERENCES mail.mailboxes(id);


--
-- Name: letters fk_letter_scanned_by; Type: FK CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.letters
    ADD CONSTRAINT fk_letter_scanned_by FOREIGN KEY (scanned_by) REFERENCES auth.users(id);


--
-- Name: letters fk_letter_scanned_document; Type: FK CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.letters
    ADD CONSTRAINT fk_letter_scanned_document FOREIGN KEY (scanned_document_id) REFERENCES documents.blobs(id);


--
-- Name: letters fk_letter_sender_address; Type: FK CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.letters
    ADD CONSTRAINT fk_letter_sender_address FOREIGN KEY (sender_address_id) REFERENCES directory.addresses(id);


--
-- Name: mailboxes fk_mailbox_address; Type: FK CONSTRAINT; Schema: mail; Owner: postgres
--

ALTER TABLE ONLY mail.mailboxes
    ADD CONSTRAINT fk_mailbox_address FOREIGN KEY (directory_address_id) REFERENCES directory.addresses(id);


--
-- Name: newsletter_analytics newsletter_analytics_newsletter_id_fkey; Type: FK CONSTRAINT; Schema: marketing; Owner: postgres
--

ALTER TABLE ONLY marketing.newsletter_analytics
    ADD CONSTRAINT newsletter_analytics_newsletter_id_fkey FOREIGN KEY (newsletter_id) REFERENCES marketing.newsletters(id) ON DELETE CASCADE;


--
-- Name: answers fk_answers_answerer; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.answers
    ADD CONSTRAINT fk_answers_answerer FOREIGN KEY (answerer_id) REFERENCES directory.people(id) ON DELETE CASCADE;


--
-- Name: answers fk_answers_assigned_notation; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.answers
    ADD CONSTRAINT fk_answers_assigned_notation FOREIGN KEY (assigned_notation_id) REFERENCES matters.assigned_notations(id) ON DELETE SET NULL;


--
-- Name: answers fk_answers_blob; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.answers
    ADD CONSTRAINT fk_answers_blob FOREIGN KEY (blob_id) REFERENCES documents.blobs(id) ON DELETE SET NULL;


--
-- Name: answers fk_answers_entity; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.answers
    ADD CONSTRAINT fk_answers_entity FOREIGN KEY (entity_id) REFERENCES directory.entities(id) ON DELETE CASCADE;


--
-- Name: answers fk_answers_question; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.answers
    ADD CONSTRAINT fk_answers_question FOREIGN KEY (question_id) REFERENCES standards.questions(id) ON DELETE CASCADE;


--
-- Name: assigned_notations fk_assigned_notations_entity; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.assigned_notations
    ADD CONSTRAINT fk_assigned_notations_entity FOREIGN KEY (entity_id) REFERENCES directory.entities(id) ON DELETE CASCADE;


--
-- Name: assigned_notations fk_assigned_notations_notation; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.assigned_notations
    ADD CONSTRAINT fk_assigned_notations_notation FOREIGN KEY (notation_id) REFERENCES standards.notations(id) ON DELETE CASCADE;


--
-- Name: assigned_notations fk_assigned_notations_person; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.assigned_notations
    ADD CONSTRAINT fk_assigned_notations_person FOREIGN KEY (person_id) REFERENCES directory.people(id) ON DELETE SET NULL;


--
-- Name: assigned_notations fk_assigned_notations_project; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.assigned_notations
    ADD CONSTRAINT fk_assigned_notations_project FOREIGN KEY (project_id) REFERENCES matters.projects(id) ON DELETE SET NULL;


--
-- Name: disclosures fk_disclosures_credential; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.disclosures
    ADD CONSTRAINT fk_disclosures_credential FOREIGN KEY (credential_id) REFERENCES legal.credentials(id) ON DELETE CASCADE;


--
-- Name: disclosures fk_disclosures_project; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.disclosures
    ADD CONSTRAINT fk_disclosures_project FOREIGN KEY (project_id) REFERENCES matters.projects(id) ON DELETE CASCADE;


--
-- Name: relationship_logs fk_relationship_logs_credential; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.relationship_logs
    ADD CONSTRAINT fk_relationship_logs_credential FOREIGN KEY (credential_id) REFERENCES legal.credentials(id) ON DELETE CASCADE;


--
-- Name: relationship_logs fk_relationship_logs_project; Type: FK CONSTRAINT; Schema: matters; Owner: postgres
--

ALTER TABLE ONLY matters.relationship_logs
    ADD CONSTRAINT fk_relationship_logs_project FOREIGN KEY (project_id) REFERENCES matters.projects(id) ON DELETE CASCADE;


--
-- Name: custom_fields custom_fields_created_by_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.custom_fields
    ADD CONSTRAINT custom_fields_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: ticket_assignments ticket_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_assignments
    ADD CONSTRAINT ticket_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES auth.users(id);


--
-- Name: ticket_assignments ticket_assignments_assigned_from_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_assignments
    ADD CONSTRAINT ticket_assignments_assigned_from_fkey FOREIGN KEY (assigned_from) REFERENCES auth.users(id);


--
-- Name: ticket_assignments ticket_assignments_assigned_to_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_assignments
    ADD CONSTRAINT ticket_assignments_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id);


--
-- Name: ticket_assignments ticket_assignments_ticket_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_assignments
    ADD CONSTRAINT ticket_assignments_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES service.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_attachments ticket_attachments_conversation_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_attachments
    ADD CONSTRAINT ticket_attachments_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES service.ticket_conversations(id) ON DELETE CASCADE;


--
-- Name: ticket_attachments ticket_attachments_ticket_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_attachments
    ADD CONSTRAINT ticket_attachments_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES service.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_attachments ticket_attachments_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_attachments
    ADD CONSTRAINT ticket_attachments_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id);


--
-- Name: ticket_conversations ticket_conversations_ticket_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_conversations
    ADD CONSTRAINT ticket_conversations_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES service.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_conversations ticket_conversations_user_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_conversations
    ADD CONSTRAINT ticket_conversations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: ticket_custom_fields ticket_custom_fields_custom_field_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_custom_fields
    ADD CONSTRAINT ticket_custom_fields_custom_field_id_fkey FOREIGN KEY (custom_field_id) REFERENCES service.custom_fields(id) ON DELETE CASCADE;


--
-- Name: ticket_custom_fields ticket_custom_fields_ticket_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_custom_fields
    ADD CONSTRAINT ticket_custom_fields_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES service.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_watchers ticket_watchers_added_by_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_watchers
    ADD CONSTRAINT ticket_watchers_added_by_fkey FOREIGN KEY (added_by) REFERENCES auth.users(id);


--
-- Name: ticket_watchers ticket_watchers_ticket_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_watchers
    ADD CONSTRAINT ticket_watchers_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES service.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_watchers ticket_watchers_user_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.ticket_watchers
    ADD CONSTRAINT ticket_watchers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: tickets tickets_assignee_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.tickets
    ADD CONSTRAINT tickets_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES auth.users(id);


--
-- Name: tickets tickets_requester_id_fkey; Type: FK CONSTRAINT; Schema: service; Owner: postgres
--

ALTER TABLE ONLY service.tickets
    ADD CONSTRAINT tickets_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES auth.users(id);


--
-- Name: notations_questions fk_notations_questions_notation; Type: FK CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.notations_questions
    ADD CONSTRAINT fk_notations_questions_notation FOREIGN KEY (notation_id) REFERENCES standards.notations(id) ON DELETE CASCADE;


--
-- Name: notations_questions fk_notations_questions_question; Type: FK CONSTRAINT; Schema: standards; Owner: postgres
--

ALTER TABLE ONLY standards.notations_questions
    ADD CONSTRAINT fk_notations_questions_question FOREIGN KEY (question_id) REFERENCES standards.questions(id) ON DELETE CASCADE;


--
-- Name: invoices; Type: ROW SECURITY; Schema: accounting; Owner: postgres
--

ALTER TABLE accounting.invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: invoices invoices_admin_all; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY invoices_admin_all ON accounting.invoices TO admin USING (true);


--
-- Name: invoices invoices_customer_read; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY invoices_customer_read ON accounting.invoices FOR SELECT TO customer USING (true);


--
-- Name: invoices invoices_staff_read; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY invoices_staff_read ON accounting.invoices FOR SELECT TO staff USING (true);


--
-- Name: invoices invoices_staff_update; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY invoices_staff_update ON accounting.invoices FOR UPDATE TO staff USING (true);


--
-- Name: invoices invoices_staff_write; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY invoices_staff_write ON accounting.invoices FOR INSERT TO staff WITH CHECK (true);


--
-- Name: vendors; Type: ROW SECURITY; Schema: accounting; Owner: postgres
--

ALTER TABLE accounting.vendors ENABLE ROW LEVEL SECURITY;

--
-- Name: vendors vendors_admin_all; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY vendors_admin_all ON accounting.vendors TO admin USING (true);


--
-- Name: vendors vendors_customer_read; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY vendors_customer_read ON accounting.vendors FOR SELECT TO customer USING (true);


--
-- Name: vendors vendors_staff_read; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY vendors_staff_read ON accounting.vendors FOR SELECT TO staff USING (true);


--
-- Name: vendors vendors_staff_update; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY vendors_staff_update ON accounting.vendors FOR UPDATE TO staff USING (true);


--
-- Name: vendors vendors_staff_write; Type: POLICY; Schema: accounting; Owner: postgres
--

CREATE POLICY vendors_staff_write ON accounting.vendors FOR INSERT TO staff WITH CHECK (true);


--
-- Name: users admin_can_delete_users; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY admin_can_delete_users ON auth.users FOR DELETE TO admin USING (true);


--
-- Name: users admin_can_insert_users; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY admin_can_insert_users ON auth.users FOR INSERT TO admin WITH CHECK (true);


--
-- Name: users admin_can_see_all_users; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY admin_can_see_all_users ON auth.users TO admin USING (true);


--
-- Name: users admin_can_update_users; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY admin_can_update_users ON auth.users FOR UPDATE TO admin USING (true) WITH CHECK (true);


--
-- Name: users customer_can_see_own_user; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY customer_can_see_own_user ON auth.users FOR SELECT TO customer USING (((username)::text = CURRENT_USER));


--
-- Name: person_entity_roles; Type: ROW SECURITY; Schema: auth; Owner: postgres
--

ALTER TABLE auth.person_entity_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: person_entity_roles person_entity_roles_admin_all; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY person_entity_roles_admin_all ON auth.person_entity_roles TO admin USING (true);


--
-- Name: person_entity_roles person_entity_roles_customer_read; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY person_entity_roles_customer_read ON auth.person_entity_roles FOR SELECT TO customer USING (true);


--
-- Name: person_entity_roles person_entity_roles_staff_read; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY person_entity_roles_staff_read ON auth.person_entity_roles FOR SELECT TO staff USING (true);


--
-- Name: users postgres_can_authenticate_users; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY postgres_can_authenticate_users ON auth.users FOR SELECT TO postgres USING (true);


--
-- Name: POLICY postgres_can_authenticate_users ON users; Type: COMMENT; Schema: auth; Owner: postgres
--

COMMENT ON POLICY postgres_can_authenticate_users ON auth.users IS 'Allows postgres user to query auth.users table for authentication purposes in SessionMiddleware';


--
-- Name: service_account_tokens; Type: ROW SECURITY; Schema: auth; Owner: postgres
--

ALTER TABLE auth.service_account_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: service_account_tokens service_account_tokens_admin_policy; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY service_account_tokens_admin_policy ON auth.service_account_tokens TO admin USING (true) WITH CHECK (true);


--
-- Name: service_account_tokens service_account_tokens_staff_read_policy; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY service_account_tokens_staff_read_policy ON auth.service_account_tokens FOR SELECT TO staff USING (true);


--
-- Name: users staff_can_see_all_users; Type: POLICY; Schema: auth; Owner: postgres
--

CREATE POLICY staff_can_see_all_users ON auth.users FOR SELECT TO staff USING (true);


--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: postgres
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: addresses address_staff_read; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY address_staff_read ON directory.addresses FOR SELECT TO staff USING (true);


--
-- Name: addresses; Type: ROW SECURITY; Schema: directory; Owner: postgres
--

ALTER TABLE directory.addresses ENABLE ROW LEVEL SECURITY;

--
-- Name: addresses addresses_admin_all; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY addresses_admin_all ON directory.addresses TO admin USING (true);


--
-- Name: addresses addresses_customer_read; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY addresses_customer_read ON directory.addresses FOR SELECT TO customer USING (true);


--
-- Name: addresses addresses_staff_all; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY addresses_staff_all ON directory.addresses TO staff USING (true);


--
-- Name: people admin_can_delete_people; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY admin_can_delete_people ON directory.people FOR DELETE TO admin USING (true);


--
-- Name: people admin_can_insert_people; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY admin_can_insert_people ON directory.people FOR INSERT TO admin WITH CHECK (true);


--
-- Name: people admin_can_see_all_people; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY admin_can_see_all_people ON directory.people FOR SELECT TO admin USING (true);


--
-- Name: people admin_can_update_people; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY admin_can_update_people ON directory.people FOR UPDATE TO admin USING (true) WITH CHECK (true);


--
-- Name: people customer_can_see_own_person; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY customer_can_see_own_person ON directory.people FOR SELECT TO customer USING (((email)::text = current_setting('app.current_user_email'::text, true)));


--
-- Name: entities; Type: ROW SECURITY; Schema: directory; Owner: postgres
--

ALTER TABLE directory.entities ENABLE ROW LEVEL SECURITY;

--
-- Name: entities entities_admin_all; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY entities_admin_all ON directory.entities TO admin USING (true);


--
-- Name: entities entities_customer_read; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY entities_customer_read ON directory.entities FOR SELECT TO customer USING (true);


--
-- Name: entities entities_staff_read; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY entities_staff_read ON directory.entities FOR SELECT TO staff USING (true);


--
-- Name: people; Type: ROW SECURITY; Schema: directory; Owner: postgres
--

ALTER TABLE directory.people ENABLE ROW LEVEL SECURITY;

--
-- Name: people staff_can_see_all_people; Type: POLICY; Schema: directory; Owner: postgres
--

CREATE POLICY staff_can_see_all_people ON directory.people FOR SELECT TO staff USING (true);


--
-- Name: blobs; Type: ROW SECURITY; Schema: documents; Owner: postgres
--

ALTER TABLE documents.blobs ENABLE ROW LEVEL SECURITY;

--
-- Name: blobs blobs_admin_all; Type: POLICY; Schema: documents; Owner: postgres
--

CREATE POLICY blobs_admin_all ON documents.blobs TO admin USING (true);


--
-- Name: blobs blobs_customer_read; Type: POLICY; Schema: documents; Owner: postgres
--

CREATE POLICY blobs_customer_read ON documents.blobs FOR SELECT TO customer USING (true);


--
-- Name: blobs blobs_staff_insert; Type: POLICY; Schema: documents; Owner: postgres
--

CREATE POLICY blobs_staff_insert ON documents.blobs FOR INSERT TO staff WITH CHECK (true);


--
-- Name: blobs blobs_staff_read; Type: POLICY; Schema: documents; Owner: postgres
--

CREATE POLICY blobs_staff_read ON documents.blobs FOR SELECT TO staff USING (true);


--
-- Name: blobs blobs_staff_update; Type: POLICY; Schema: documents; Owner: postgres
--

CREATE POLICY blobs_staff_update ON documents.blobs FOR UPDATE TO staff USING (true);


--
-- Name: share_classes; Type: ROW SECURITY; Schema: equity; Owner: postgres
--

ALTER TABLE equity.share_classes ENABLE ROW LEVEL SECURITY;

--
-- Name: share_classes share_classes_admin_all; Type: POLICY; Schema: equity; Owner: postgres
--

CREATE POLICY share_classes_admin_all ON equity.share_classes TO admin USING (true);


--
-- Name: share_classes share_classes_customer_read; Type: POLICY; Schema: equity; Owner: postgres
--

CREATE POLICY share_classes_customer_read ON equity.share_classes FOR SELECT TO customer USING (true);


--
-- Name: share_classes share_classes_staff_read; Type: POLICY; Schema: equity; Owner: postgres
--

CREATE POLICY share_classes_staff_read ON equity.share_classes FOR SELECT TO staff USING (true);


--
-- Name: share_issuances; Type: ROW SECURITY; Schema: equity; Owner: postgres
--

ALTER TABLE equity.share_issuances ENABLE ROW LEVEL SECURITY;

--
-- Name: share_issuances share_issuances_admin_all; Type: POLICY; Schema: equity; Owner: postgres
--

CREATE POLICY share_issuances_admin_all ON equity.share_issuances TO admin USING (true);


--
-- Name: share_issuances share_issuances_customer_read; Type: POLICY; Schema: equity; Owner: postgres
--

CREATE POLICY share_issuances_customer_read ON equity.share_issuances FOR SELECT TO customer USING (true);


--
-- Name: share_issuances share_issuances_staff_read; Type: POLICY; Schema: equity; Owner: postgres
--

CREATE POLICY share_issuances_staff_read ON equity.share_issuances FOR SELECT TO staff USING (true);


--
-- Name: birth_data; Type: ROW SECURITY; Schema: ethereal; Owner: postgres
--

ALTER TABLE ethereal.birth_data ENABLE ROW LEVEL SECURITY;

--
-- Name: birth_data birth_data_admin_all; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_data_admin_all ON ethereal.birth_data TO admin USING (true);


--
-- Name: birth_data birth_data_customer_delete; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_data_customer_delete ON ethereal.birth_data FOR DELETE TO customer USING ((EXISTS ( SELECT 1
   FROM auth.users u
  WHERE ((u.id = birth_data.user_id) AND ((u.username)::text = current_setting('app.current_user_username'::text, true))))));


--
-- Name: birth_data birth_data_customer_insert; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_data_customer_insert ON ethereal.birth_data FOR INSERT TO customer WITH CHECK ((EXISTS ( SELECT 1
   FROM auth.users u
  WHERE ((u.id = birth_data.user_id) AND ((u.username)::text = current_setting('app.current_user_username'::text, true))))));


--
-- Name: birth_data birth_data_customer_select; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_data_customer_select ON ethereal.birth_data FOR SELECT TO customer USING ((EXISTS ( SELECT 1
   FROM auth.users u
  WHERE ((u.id = birth_data.user_id) AND ((u.username)::text = current_setting('app.current_user_username'::text, true))))));


--
-- Name: birth_data birth_data_customer_update; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_data_customer_update ON ethereal.birth_data FOR UPDATE TO customer USING ((EXISTS ( SELECT 1
   FROM auth.users u
  WHERE ((u.id = birth_data.user_id) AND ((u.username)::text = current_setting('app.current_user_username'::text, true)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM auth.users u
  WHERE ((u.id = birth_data.user_id) AND ((u.username)::text = current_setting('app.current_user_username'::text, true))))));


--
-- Name: birth_data birth_data_staff_select; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_data_staff_select ON ethereal.birth_data FOR SELECT TO staff USING (true);


--
-- Name: birth_date_times; Type: ROW SECURITY; Schema: ethereal; Owner: postgres
--

ALTER TABLE ethereal.birth_date_times ENABLE ROW LEVEL SECURITY;

--
-- Name: birth_date_times birth_date_times_admin_all; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_date_times_admin_all ON ethereal.birth_date_times TO admin USING (true);


--
-- Name: birth_date_times birth_date_times_customer_select; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_date_times_customer_select ON ethereal.birth_date_times FOR SELECT TO customer USING ((EXISTS ( SELECT 1
   FROM (ethereal.birth_data bd
     JOIN auth.users u ON ((u.id = bd.user_id)))
  WHERE ((bd.date_time_id = birth_date_times.id) AND ((u.username)::text = current_setting('app.current_user_username'::text, true))))));


--
-- Name: birth_date_times birth_date_times_staff_select; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_date_times_staff_select ON ethereal.birth_date_times FOR SELECT TO staff USING (true);


--
-- Name: birth_locations; Type: ROW SECURITY; Schema: ethereal; Owner: postgres
--

ALTER TABLE ethereal.birth_locations ENABLE ROW LEVEL SECURITY;

--
-- Name: birth_locations birth_locations_admin_all; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_locations_admin_all ON ethereal.birth_locations TO admin USING (true);


--
-- Name: birth_locations birth_locations_customer_select; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_locations_customer_select ON ethereal.birth_locations FOR SELECT TO customer USING (true);


--
-- Name: birth_locations birth_locations_staff_select; Type: POLICY; Schema: ethereal; Owner: postgres
--

CREATE POLICY birth_locations_staff_select ON ethereal.birth_locations FOR SELECT TO staff USING (true);


--
-- Name: entity_types; Type: ROW SECURITY; Schema: legal; Owner: postgres
--

ALTER TABLE legal.entity_types ENABLE ROW LEVEL SECURITY;

--
-- Name: entity_types entity_types_admin_all; Type: POLICY; Schema: legal; Owner: postgres
--

CREATE POLICY entity_types_admin_all ON legal.entity_types TO admin USING (true) WITH CHECK (true);


--
-- Name: entity_types entity_types_customer_select; Type: POLICY; Schema: legal; Owner: postgres
--

CREATE POLICY entity_types_customer_select ON legal.entity_types FOR SELECT TO customer USING (true);


--
-- Name: entity_types entity_types_staff_insert; Type: POLICY; Schema: legal; Owner: postgres
--

CREATE POLICY entity_types_staff_insert ON legal.entity_types FOR INSERT TO staff WITH CHECK (true);


--
-- Name: entity_types entity_types_staff_select; Type: POLICY; Schema: legal; Owner: postgres
--

CREATE POLICY entity_types_staff_select ON legal.entity_types FOR SELECT TO staff USING (true);


--
-- Name: entity_types entity_types_staff_update; Type: POLICY; Schema: legal; Owner: postgres
--

CREATE POLICY entity_types_staff_update ON legal.entity_types FOR UPDATE TO staff USING (true) WITH CHECK (true);


--
-- Name: letters; Type: ROW SECURITY; Schema: mail; Owner: postgres
--

ALTER TABLE mail.letters ENABLE ROW LEVEL SECURITY;

--
-- Name: letters letters_admin_all; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY letters_admin_all ON mail.letters TO admin USING (true);


--
-- Name: letters letters_customer_read; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY letters_customer_read ON mail.letters FOR SELECT TO customer USING (true);


--
-- Name: letters letters_staff_insert; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY letters_staff_insert ON mail.letters FOR INSERT TO staff WITH CHECK (true);


--
-- Name: letters letters_staff_read; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY letters_staff_read ON mail.letters FOR SELECT TO staff USING (true);


--
-- Name: letters letters_staff_update; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY letters_staff_update ON mail.letters FOR UPDATE TO staff USING (true);


--
-- Name: mailboxes; Type: ROW SECURITY; Schema: mail; Owner: postgres
--

ALTER TABLE mail.mailboxes ENABLE ROW LEVEL SECURITY;

--
-- Name: mailboxes mailboxes_admin_all; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY mailboxes_admin_all ON mail.mailboxes TO admin USING (true);


--
-- Name: mailboxes mailboxes_customer_read; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY mailboxes_customer_read ON mail.mailboxes FOR SELECT TO customer USING (true);


--
-- Name: mailboxes mailboxes_staff_read; Type: POLICY; Schema: mail; Owner: postgres
--

CREATE POLICY mailboxes_staff_read ON mail.mailboxes FOR SELECT TO staff USING (true);


--
-- Name: newsletter_analytics; Type: ROW SECURITY; Schema: marketing; Owner: postgres
--

ALTER TABLE marketing.newsletter_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: newsletter_analytics newsletter_analytics_admin_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletter_analytics_admin_policy ON marketing.newsletter_analytics TO admin USING (true) WITH CHECK (true);


--
-- Name: newsletter_analytics newsletter_analytics_staff_read_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletter_analytics_staff_read_policy ON marketing.newsletter_analytics FOR SELECT TO staff USING (true);


--
-- Name: newsletter_analytics newsletter_analytics_user_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletter_analytics_user_policy ON marketing.newsletter_analytics FOR SELECT TO customer USING (true);


--
-- Name: newsletter_templates; Type: ROW SECURITY; Schema: marketing; Owner: postgres
--

ALTER TABLE marketing.newsletter_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: newsletter_templates newsletter_templates_admin_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletter_templates_admin_policy ON marketing.newsletter_templates TO admin USING (true) WITH CHECK (true);


--
-- Name: newsletter_templates newsletter_templates_staff_read_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletter_templates_staff_read_policy ON marketing.newsletter_templates FOR SELECT TO staff USING ((is_active = true));


--
-- Name: newsletters; Type: ROW SECURITY; Schema: marketing; Owner: postgres
--

ALTER TABLE marketing.newsletters ENABLE ROW LEVEL SECURITY;

--
-- Name: newsletters newsletters_admin_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletters_admin_policy ON marketing.newsletters TO admin USING (true) WITH CHECK (true);


--
-- Name: newsletters newsletters_customer_read_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletters_customer_read_policy ON marketing.newsletters FOR SELECT TO customer USING ((sent_at IS NOT NULL));


--
-- Name: newsletters newsletters_staff_read_policy; Type: POLICY; Schema: marketing; Owner: postgres
--

CREATE POLICY newsletters_staff_read_policy ON marketing.newsletters FOR SELECT TO staff USING (true);


--
-- Name: relationship_logs admin_full_access; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY admin_full_access ON matters.relationship_logs TO admin USING (true) WITH CHECK (true);


--
-- Name: answers; Type: ROW SECURITY; Schema: matters; Owner: postgres
--

ALTER TABLE matters.answers ENABLE ROW LEVEL SECURITY;

--
-- Name: answers answers_admin_all_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_admin_all_policy ON matters.answers TO admin USING (true) WITH CHECK (true);


--
-- Name: answers answers_customer_insert_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_customer_insert_policy ON matters.answers FOR INSERT TO customer WITH CHECK (true);


--
-- Name: answers answers_customer_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_customer_select_policy ON matters.answers FOR SELECT TO customer USING (true);


--
-- Name: answers answers_customer_update_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_customer_update_policy ON matters.answers FOR UPDATE TO customer USING (true) WITH CHECK (true);


--
-- Name: answers answers_staff_insert_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_staff_insert_policy ON matters.answers FOR INSERT TO staff WITH CHECK (true);


--
-- Name: answers answers_staff_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_staff_select_policy ON matters.answers FOR SELECT TO staff USING (true);


--
-- Name: answers answers_staff_update_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY answers_staff_update_policy ON matters.answers FOR UPDATE TO staff USING (true) WITH CHECK (true);


--
-- Name: assigned_notations; Type: ROW SECURITY; Schema: matters; Owner: postgres
--

ALTER TABLE matters.assigned_notations ENABLE ROW LEVEL SECURITY;

--
-- Name: assigned_notations assigned_notations_admin_all_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY assigned_notations_admin_all_policy ON matters.assigned_notations TO admin USING (true) WITH CHECK (true);


--
-- Name: assigned_notations assigned_notations_customer_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY assigned_notations_customer_select_policy ON matters.assigned_notations FOR SELECT TO customer USING (true);


--
-- Name: assigned_notations assigned_notations_staff_insert_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY assigned_notations_staff_insert_policy ON matters.assigned_notations FOR INSERT TO staff WITH CHECK (true);


--
-- Name: assigned_notations assigned_notations_staff_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY assigned_notations_staff_select_policy ON matters.assigned_notations FOR SELECT TO staff USING (true);


--
-- Name: assigned_notations assigned_notations_staff_update_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY assigned_notations_staff_update_policy ON matters.assigned_notations FOR UPDATE TO staff USING (true) WITH CHECK (true);


--
-- Name: relationship_logs customer_read_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY customer_read_policy ON matters.relationship_logs FOR SELECT TO customer USING (true);


--
-- Name: disclosures; Type: ROW SECURITY; Schema: matters; Owner: postgres
--

ALTER TABLE matters.disclosures ENABLE ROW LEVEL SECURITY;

--
-- Name: disclosures disclosures_admin_all_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY disclosures_admin_all_policy ON matters.disclosures TO admin USING (true) WITH CHECK (true);


--
-- Name: disclosures disclosures_customer_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY disclosures_customer_select_policy ON matters.disclosures FOR SELECT TO customer USING (true);


--
-- Name: disclosures disclosures_staff_insert_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY disclosures_staff_insert_policy ON matters.disclosures FOR INSERT TO staff WITH CHECK (true);


--
-- Name: disclosures disclosures_staff_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY disclosures_staff_select_policy ON matters.disclosures FOR SELECT TO staff USING (true);


--
-- Name: disclosures disclosures_staff_update_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY disclosures_staff_update_policy ON matters.disclosures FOR UPDATE TO staff USING (true) WITH CHECK (true);


--
-- Name: projects; Type: ROW SECURITY; Schema: matters; Owner: postgres
--

ALTER TABLE matters.projects ENABLE ROW LEVEL SECURITY;

--
-- Name: projects projects_admin_all_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY projects_admin_all_policy ON matters.projects TO admin USING (true) WITH CHECK (true);


--
-- Name: projects projects_customer_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY projects_customer_select_policy ON matters.projects FOR SELECT TO customer USING (true);


--
-- Name: projects projects_staff_insert_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY projects_staff_insert_policy ON matters.projects FOR INSERT TO staff WITH CHECK (true);


--
-- Name: projects projects_staff_select_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY projects_staff_select_policy ON matters.projects FOR SELECT TO staff USING (true);


--
-- Name: projects projects_staff_update_policy; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY projects_staff_update_policy ON matters.projects FOR UPDATE TO staff USING (true) WITH CHECK (true);


--
-- Name: relationship_logs; Type: ROW SECURITY; Schema: matters; Owner: postgres
--

ALTER TABLE matters.relationship_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: relationship_logs staff_full_access; Type: POLICY; Schema: matters; Owner: postgres
--

CREATE POLICY staff_full_access ON matters.relationship_logs TO staff USING (true) WITH CHECK (true);


--
-- Name: statement_stats admin_all_statement_stats; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_all_statement_stats ON public.statement_stats TO admin USING (true);


--
-- Name: statement_stats_hourly admin_all_statement_stats_hourly; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_all_statement_stats_hourly ON public.statement_stats_hourly TO admin USING (true);


--
-- Name: table_usage_stats admin_all_table_usage_stats; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY admin_all_table_usage_stats ON public.table_usage_stats TO admin USING (true);


--
-- Name: lawyer_inquiries; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.lawyer_inquiries ENABLE ROW LEVEL SECURITY;

--
-- Name: lawyer_inquiries lawyer_inquiries_admin_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY lawyer_inquiries_admin_policy ON public.lawyer_inquiries TO admin USING (true);


--
-- Name: lawyer_inquiries lawyer_inquiries_customer_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY lawyer_inquiries_customer_policy ON public.lawyer_inquiries TO customer USING (false);


--
-- Name: lawyer_inquiries lawyer_inquiries_staff_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY lawyer_inquiries_staff_policy ON public.lawyer_inquiries FOR SELECT TO staff USING (true);


--
-- Name: statement_stats; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.statement_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: statement_stats statement_stats_admin_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY statement_stats_admin_policy ON public.statement_stats TO admin USING (true) WITH CHECK (true);


--
-- Name: POLICY statement_stats_admin_policy ON statement_stats; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON POLICY statement_stats_admin_policy ON public.statement_stats IS 'Admin role has full access to view and manage PostgreSQL statement statistics';


--
-- Name: statement_stats_hourly; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.statement_stats_hourly ENABLE ROW LEVEL SECURITY;

--
-- Name: statement_stats_hourly statement_stats_hourly_admin_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY statement_stats_hourly_admin_policy ON public.statement_stats_hourly TO admin USING (true) WITH CHECK (true);


--
-- Name: POLICY statement_stats_hourly_admin_policy ON statement_stats_hourly; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON POLICY statement_stats_hourly_admin_policy ON public.statement_stats_hourly IS 'Admin role has full access to view and manage PostgreSQL hourly statement statistics';


--
-- Name: table_usage_stats; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.table_usage_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: table_usage_stats table_usage_stats_admin_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY table_usage_stats_admin_policy ON public.table_usage_stats TO admin USING (true) WITH CHECK (true);


--
-- Name: POLICY table_usage_stats_admin_policy ON table_usage_stats; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON POLICY table_usage_stats_admin_policy ON public.table_usage_stats IS 'Admin role has full access to view and manage PostgreSQL table usage statistics';


--
-- Name: notations; Type: ROW SECURITY; Schema: standards; Owner: postgres
--

ALTER TABLE standards.notations ENABLE ROW LEVEL SECURITY;

--
-- Name: notations notations_admin_all_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_admin_all_policy ON standards.notations TO admin USING (true) WITH CHECK (true);


--
-- Name: notations notations_customer_select_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_customer_select_policy ON standards.notations FOR SELECT TO customer USING ((published = true));


--
-- Name: notations_questions; Type: ROW SECURITY; Schema: standards; Owner: postgres
--

ALTER TABLE standards.notations_questions ENABLE ROW LEVEL SECURITY;

--
-- Name: notations_questions notations_questions_admin_all_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_questions_admin_all_policy ON standards.notations_questions TO admin USING (true) WITH CHECK (true);


--
-- Name: notations_questions notations_questions_customer_select_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_questions_customer_select_policy ON standards.notations_questions FOR SELECT TO customer USING ((EXISTS ( SELECT 1
   FROM standards.notations n
  WHERE ((n.id = notations_questions.notation_id) AND (n.published = true)))));


--
-- Name: notations_questions notations_questions_staff_delete_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_questions_staff_delete_policy ON standards.notations_questions FOR DELETE TO staff USING ((EXISTS ( SELECT 1
   FROM standards.notations n
  WHERE ((n.id = notations_questions.notation_id) AND (n.published = false)))));


--
-- Name: notations_questions notations_questions_staff_insert_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_questions_staff_insert_policy ON standards.notations_questions FOR INSERT TO staff WITH CHECK ((EXISTS ( SELECT 1
   FROM standards.notations n
  WHERE ((n.id = notations_questions.notation_id) AND (n.published = false)))));


--
-- Name: notations_questions notations_questions_staff_select_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_questions_staff_select_policy ON standards.notations_questions FOR SELECT TO staff USING (true);


--
-- Name: notations_questions notations_questions_staff_update_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_questions_staff_update_policy ON standards.notations_questions FOR UPDATE TO staff USING ((EXISTS ( SELECT 1
   FROM standards.notations n
  WHERE ((n.id = notations_questions.notation_id) AND (n.published = false))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM standards.notations n
  WHERE ((n.id = notations_questions.notation_id) AND (n.published = false)))));


--
-- Name: notations notations_staff_insert_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_staff_insert_policy ON standards.notations FOR INSERT TO staff WITH CHECK ((published = false));


--
-- Name: notations notations_staff_select_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_staff_select_policy ON standards.notations FOR SELECT TO staff USING (true);


--
-- Name: notations notations_staff_update_policy; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY notations_staff_update_policy ON standards.notations FOR UPDATE TO staff USING ((published = false)) WITH CHECK ((published = false));


--
-- Name: questions; Type: ROW SECURITY; Schema: standards; Owner: postgres
--

ALTER TABLE standards.questions ENABLE ROW LEVEL SECURITY;

--
-- Name: questions questions_admin_all; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY questions_admin_all ON standards.questions TO admin USING (true);


--
-- Name: questions questions_customer_read; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY questions_customer_read ON standards.questions FOR SELECT TO customer USING (true);


--
-- Name: questions questions_staff_read; Type: POLICY; Schema: standards; Owner: postgres
--

CREATE POLICY questions_staff_read ON standards.questions FOR SELECT TO staff USING (true);


--
-- Name: SCHEMA accounting; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA accounting TO customer;
GRANT USAGE ON SCHEMA accounting TO staff;
GRANT USAGE ON SCHEMA accounting TO admin;


--
-- Name: SCHEMA admin; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA admin TO admin;
GRANT USAGE ON SCHEMA admin TO customer;
GRANT USAGE ON SCHEMA admin TO staff;


--
-- Name: SCHEMA auth; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA auth TO customer;
GRANT USAGE ON SCHEMA auth TO staff;
GRANT USAGE ON SCHEMA auth TO admin;


--
-- Name: SCHEMA directory; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA directory TO customer;
GRANT USAGE ON SCHEMA directory TO staff;
GRANT USAGE ON SCHEMA directory TO admin;


--
-- Name: SCHEMA documents; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA documents TO customer;
GRANT USAGE ON SCHEMA documents TO staff;
GRANT USAGE ON SCHEMA documents TO admin;


--
-- Name: SCHEMA equity; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA equity TO customer;
GRANT USAGE ON SCHEMA equity TO staff;
GRANT USAGE ON SCHEMA equity TO admin;


--
-- Name: SCHEMA estates; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA estates TO customer;
GRANT USAGE ON SCHEMA estates TO staff;
GRANT USAGE ON SCHEMA estates TO admin;


--
-- Name: SCHEMA ethereal; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA ethereal TO customer;
GRANT USAGE ON SCHEMA ethereal TO staff;
GRANT USAGE ON SCHEMA ethereal TO admin;


--
-- Name: SCHEMA legal; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA legal TO customer;
GRANT USAGE ON SCHEMA legal TO staff;
GRANT USAGE ON SCHEMA legal TO admin;


--
-- Name: SCHEMA mail; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA mail TO customer;
GRANT USAGE ON SCHEMA mail TO staff;
GRANT USAGE ON SCHEMA mail TO admin;


--
-- Name: SCHEMA marketing; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA marketing TO customer;
GRANT USAGE ON SCHEMA marketing TO staff;
GRANT USAGE ON SCHEMA marketing TO admin;


--
-- Name: SCHEMA matters; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA matters TO customer;
GRANT USAGE ON SCHEMA matters TO staff;
GRANT USAGE ON SCHEMA matters TO admin;


--
-- Name: SCHEMA service; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA service TO customer;
GRANT USAGE ON SCHEMA service TO staff;
GRANT USAGE ON SCHEMA service TO admin;


--
-- Name: SCHEMA standards; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA standards TO customer;
GRANT USAGE ON SCHEMA standards TO staff;
GRANT USAGE ON SCHEMA standards TO admin;


--
-- Name: FUNCTION aggregate_statement_stats_hourly(); Type: ACL; Schema: admin; Owner: postgres
--

GRANT ALL ON FUNCTION admin.aggregate_statement_stats_hourly() TO admin;


--
-- Name: FUNCTION capture_statement_stats(); Type: ACL; Schema: admin; Owner: postgres
--

GRANT ALL ON FUNCTION admin.capture_statement_stats() TO admin;


--
-- Name: FUNCTION create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role); Type: ACL; Schema: admin; Owner: postgres
--

REVOKE ALL ON FUNCTION admin.create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role) FROM PUBLIC;
GRANT ALL ON FUNCTION admin.create_person_and_user(p_name character varying, p_email public.citext, p_username character varying, p_role auth.user_role) TO admin;


--
-- Name: FUNCTION extract_table_usage_stats(); Type: ACL; Schema: admin; Owner: postgres
--

GRANT ALL ON FUNCTION admin.extract_table_usage_stats() TO admin;


--
-- Name: TABLE invoices; Type: ACL; Schema: accounting; Owner: postgres
--

GRANT SELECT ON TABLE accounting.invoices TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE accounting.invoices TO staff;
GRANT ALL ON TABLE accounting.invoices TO admin;


--
-- Name: TABLE vendors; Type: ACL; Schema: accounting; Owner: postgres
--

GRANT SELECT ON TABLE accounting.vendors TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE accounting.vendors TO staff;
GRANT ALL ON TABLE accounting.vendors TO admin;


--
-- Name: TABLE person_entity_roles; Type: ACL; Schema: auth; Owner: postgres
--

GRANT SELECT ON TABLE auth.person_entity_roles TO customer;
GRANT SELECT ON TABLE auth.person_entity_roles TO staff;
GRANT ALL ON TABLE auth.person_entity_roles TO admin;


--
-- Name: TABLE service_account_tokens; Type: ACL; Schema: auth; Owner: postgres
--

GRANT SELECT ON TABLE auth.service_account_tokens TO staff;
GRANT ALL ON TABLE auth.service_account_tokens TO admin;


--
-- Name: TABLE users; Type: ACL; Schema: auth; Owner: postgres
--

GRANT SELECT ON TABLE auth.users TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE auth.users TO staff;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE auth.users TO admin;


--
-- Name: TABLE addresses; Type: ACL; Schema: directory; Owner: postgres
--

GRANT SELECT ON TABLE directory.addresses TO customer;
GRANT SELECT ON TABLE directory.addresses TO staff;
GRANT ALL ON TABLE directory.addresses TO admin;


--
-- Name: TABLE entities; Type: ACL; Schema: directory; Owner: postgres
--

GRANT SELECT ON TABLE directory.entities TO customer;
GRANT SELECT ON TABLE directory.entities TO staff;
GRANT ALL ON TABLE directory.entities TO admin;


--
-- Name: TABLE people; Type: ACL; Schema: directory; Owner: postgres
--

GRANT SELECT ON TABLE directory.people TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE directory.people TO staff;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE directory.people TO admin;


--
-- Name: TABLE blobs; Type: ACL; Schema: documents; Owner: postgres
--

GRANT SELECT ON TABLE documents.blobs TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE documents.blobs TO staff;
GRANT ALL ON TABLE documents.blobs TO admin;


--
-- Name: TABLE share_classes; Type: ACL; Schema: equity; Owner: postgres
--

GRANT SELECT ON TABLE equity.share_classes TO customer;
GRANT SELECT ON TABLE equity.share_classes TO staff;
GRANT ALL ON TABLE equity.share_classes TO admin;


--
-- Name: TABLE share_issuances; Type: ACL; Schema: equity; Owner: postgres
--

GRANT SELECT ON TABLE equity.share_issuances TO customer;
GRANT SELECT ON TABLE equity.share_issuances TO staff;
GRANT ALL ON TABLE equity.share_issuances TO admin;


--
-- Name: TABLE birth_data; Type: ACL; Schema: ethereal; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ethereal.birth_data TO customer;
GRANT SELECT ON TABLE ethereal.birth_data TO staff;
GRANT ALL ON TABLE ethereal.birth_data TO admin;


--
-- Name: TABLE birth_date_times; Type: ACL; Schema: ethereal; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ethereal.birth_date_times TO customer;
GRANT SELECT ON TABLE ethereal.birth_date_times TO staff;
GRANT ALL ON TABLE ethereal.birth_date_times TO admin;


--
-- Name: TABLE birth_locations; Type: ACL; Schema: ethereal; Owner: postgres
--

GRANT SELECT ON TABLE ethereal.birth_locations TO customer;
GRANT SELECT ON TABLE ethereal.birth_locations TO staff;
GRANT ALL ON TABLE ethereal.birth_locations TO admin;


--
-- Name: TABLE credentials; Type: ACL; Schema: legal; Owner: postgres
--

GRANT SELECT ON TABLE legal.credentials TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE legal.credentials TO staff;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE legal.credentials TO admin;


--
-- Name: TABLE entity_types; Type: ACL; Schema: legal; Owner: postgres
--

GRANT SELECT ON TABLE legal.entity_types TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE legal.entity_types TO staff;
GRANT ALL ON TABLE legal.entity_types TO admin;


--
-- Name: TABLE jurisdictions; Type: ACL; Schema: legal; Owner: postgres
--

GRANT SELECT ON TABLE legal.jurisdictions TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE legal.jurisdictions TO staff;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE legal.jurisdictions TO admin;


--
-- Name: TABLE letters; Type: ACL; Schema: mail; Owner: postgres
--

GRANT SELECT ON TABLE mail.letters TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE mail.letters TO staff;
GRANT ALL ON TABLE mail.letters TO admin;


--
-- Name: TABLE mailboxes; Type: ACL; Schema: mail; Owner: postgres
--

GRANT SELECT ON TABLE mail.mailboxes TO customer;
GRANT SELECT ON TABLE mail.mailboxes TO staff;
GRANT ALL ON TABLE mail.mailboxes TO admin;


--
-- Name: TABLE newsletter_analytics; Type: ACL; Schema: marketing; Owner: postgres
--

GRANT SELECT ON TABLE marketing.newsletter_analytics TO customer;
GRANT SELECT ON TABLE marketing.newsletter_analytics TO staff;
GRANT ALL ON TABLE marketing.newsletter_analytics TO admin;


--
-- Name: TABLE newsletter_templates; Type: ACL; Schema: marketing; Owner: postgres
--

GRANT SELECT ON TABLE marketing.newsletter_templates TO staff;
GRANT ALL ON TABLE marketing.newsletter_templates TO admin;


--
-- Name: TABLE newsletters; Type: ACL; Schema: marketing; Owner: postgres
--

GRANT SELECT ON TABLE marketing.newsletters TO customer;
GRANT SELECT ON TABLE marketing.newsletters TO staff;
GRANT ALL ON TABLE marketing.newsletters TO admin;


--
-- Name: TABLE answers; Type: ACL; Schema: matters; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE matters.answers TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE matters.answers TO staff;
GRANT ALL ON TABLE matters.answers TO admin;


--
-- Name: TABLE assigned_notations; Type: ACL; Schema: matters; Owner: postgres
--

GRANT SELECT ON TABLE matters.assigned_notations TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE matters.assigned_notations TO staff;
GRANT ALL ON TABLE matters.assigned_notations TO admin;


--
-- Name: TABLE disclosures; Type: ACL; Schema: matters; Owner: postgres
--

GRANT SELECT ON TABLE matters.disclosures TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE matters.disclosures TO staff;
GRANT ALL ON TABLE matters.disclosures TO admin;


--
-- Name: TABLE projects; Type: ACL; Schema: matters; Owner: postgres
--

GRANT SELECT ON TABLE matters.projects TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE matters.projects TO staff;
GRANT ALL ON TABLE matters.projects TO admin;


--
-- Name: TABLE relationship_logs; Type: ACL; Schema: matters; Owner: postgres
--

GRANT SELECT ON TABLE matters.relationship_logs TO customer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE matters.relationship_logs TO staff;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE matters.relationship_logs TO admin;


--
-- Name: TABLE lawyer_inquiries; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.lawyer_inquiries TO staff;
GRANT ALL ON TABLE public.lawyer_inquiries TO admin;


--
-- Name: TABLE statement_stats; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.statement_stats TO admin;


--
-- Name: TABLE statement_stats_hourly; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.statement_stats_hourly TO admin;


--
-- Name: TABLE table_usage_stats; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.table_usage_stats TO admin;


--
-- Name: TABLE custom_fields; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.custom_fields TO customer;
GRANT SELECT ON TABLE service.custom_fields TO staff;
GRANT ALL ON TABLE service.custom_fields TO admin;


--
-- Name: TABLE ticket_assignments; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.ticket_assignments TO customer;
GRANT SELECT,INSERT ON TABLE service.ticket_assignments TO staff;
GRANT ALL ON TABLE service.ticket_assignments TO admin;


--
-- Name: TABLE ticket_attachments; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.ticket_attachments TO customer;
GRANT SELECT,INSERT ON TABLE service.ticket_attachments TO staff;
GRANT ALL ON TABLE service.ticket_attachments TO admin;


--
-- Name: TABLE ticket_conversations; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.ticket_conversations TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE service.ticket_conversations TO staff;
GRANT ALL ON TABLE service.ticket_conversations TO admin;


--
-- Name: TABLE ticket_custom_fields; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.ticket_custom_fields TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE service.ticket_custom_fields TO staff;
GRANT ALL ON TABLE service.ticket_custom_fields TO admin;


--
-- Name: SEQUENCE ticket_number_seq; Type: ACL; Schema: service; Owner: postgres
--

GRANT USAGE ON SEQUENCE service.ticket_number_seq TO staff;
GRANT USAGE ON SEQUENCE service.ticket_number_seq TO admin;


--
-- Name: TABLE ticket_watchers; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.ticket_watchers TO customer;
GRANT SELECT,INSERT,DELETE ON TABLE service.ticket_watchers TO staff;
GRANT ALL ON TABLE service.ticket_watchers TO admin;


--
-- Name: TABLE tickets; Type: ACL; Schema: service; Owner: postgres
--

GRANT SELECT ON TABLE service.tickets TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE service.tickets TO staff;
GRANT ALL ON TABLE service.tickets TO admin;


--
-- Name: TABLE notations; Type: ACL; Schema: standards; Owner: postgres
--

GRANT SELECT ON TABLE standards.notations TO customer;
GRANT SELECT,INSERT,UPDATE ON TABLE standards.notations TO staff;
GRANT ALL ON TABLE standards.notations TO admin;


--
-- Name: TABLE notations_questions; Type: ACL; Schema: standards; Owner: postgres
--

GRANT SELECT ON TABLE standards.notations_questions TO customer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE standards.notations_questions TO staff;
GRANT ALL ON TABLE standards.notations_questions TO admin;


--
-- Name: TABLE questions; Type: ACL; Schema: standards; Owner: postgres
--

GRANT SELECT ON TABLE standards.questions TO customer;
GRANT SELECT ON TABLE standards.questions TO staff;
GRANT ALL ON TABLE standards.questions TO admin;


--
-- PostgreSQL database dump complete
--

