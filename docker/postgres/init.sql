-- PostgreSQL initialization for Luxe ALB simulation
-- This script creates the basic database structure needed for testing

-- Ensure the luxe database exists
SELECT 'CREATE DATABASE luxe'
    WHERE NOT EXISTS (
        SELECT
        FROM pg_database
        WHERE datname = 'luxe'
    ) \gexec

-- Connect to the luxe database
\c luxe;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create schemas that will be used by the application
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS directory;
CREATE SCHEMA IF NOT EXISTS mail;
CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS equity;
CREATE SCHEMA IF NOT EXISTS estates;
CREATE SCHEMA IF NOT EXISTS standards;
CREATE SCHEMA IF NOT EXISTS legal;
CREATE SCHEMA IF NOT EXISTS matters;
CREATE SCHEMA IF NOT EXISTS documents;
CREATE SCHEMA IF NOT EXISTS service;
CREATE SCHEMA IF NOT EXISTS admin;

-- Set default search path
ALTER DATABASE luxe SET search_path TO auth, directory, mail, accounting, equity, estates, standards, legal, matters, documents, service, admin, public;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE luxe TO postgres;
GRANT ALL ON SCHEMA auth TO postgres;
GRANT ALL ON SCHEMA directory TO postgres;
GRANT ALL ON SCHEMA mail TO postgres;
GRANT ALL ON SCHEMA accounting TO postgres;
GRANT ALL ON SCHEMA equity TO postgres;
GRANT ALL ON SCHEMA estates TO postgres;
GRANT ALL ON SCHEMA standards TO postgres;
GRANT ALL ON SCHEMA legal TO postgres;
GRANT ALL ON SCHEMA matters TO postgres;
GRANT ALL ON SCHEMA documents TO postgres;
GRANT ALL ON SCHEMA service TO postgres;
GRANT ALL ON SCHEMA admin TO postgres;

-- Create a basic user role enum (the application will create the full schema via migrations)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE auth.user_role AS ENUM ('admin', 'staff', 'customer');
    END IF;
END
$$;

-- Create basic test tables that might be needed for the ALB simulation
-- Note: The full schema will be created by Palette migrations

-- Basic people table for directory schema
CREATE TABLE IF NOT EXISTS directory.people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Basic users table for auth schema
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    sub TEXT UNIQUE, -- Cognito subject ID
    person_id UUID REFERENCES directory.people(id),
    role auth.user_role NOT NULL DEFAULT 'customer',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert test users for ALB simulation
INSERT INTO directory.people (name, email) VALUES 
    ('Admin User', 'admin@neonlaw.com'),
    ('Staff User', 'staff@neonlaw.com'),
    ('Customer User', 'customer@example.com')
ON CONFLICT (email) DO NOTHING;

INSERT INTO auth.users (username, sub, person_id, role)
SELECT 
    p.email, 
    CASE 
        WHEN p.email = 'admin@neonlaw.com' THEN 'admin-user-sub'
        WHEN p.email = 'staff@neonlaw.com' THEN 'staff-user-sub'
        WHEN p.email = 'customer@example.com' THEN 'customer-user-sub'
    END,
    p.id,
    CASE 
        WHEN p.email = 'admin@neonlaw.com' THEN 'admin'::auth.user_role
        WHEN p.email = 'staff@neonlaw.com' THEN 'staff'::auth.user_role
        WHEN p.email = 'customer@example.com' THEN 'customer'::auth.user_role
    END
FROM directory.people p
WHERE p.email IN ('admin@neonlaw.com', 'staff@neonlaw.com', 'customer@example.com')
ON CONFLICT (username) DO NOTHING;