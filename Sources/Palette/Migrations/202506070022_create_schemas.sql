-- users, person_entity_roles
CREATE SCHEMA IF NOT EXISTS auth;

-- people, entities, addresses
CREATE SCHEMA IF NOT EXISTS directory;

-- letters, mailboxes
CREATE SCHEMA IF NOT EXISTS mail;

-- invoices, vendors
CREATE SCHEMA IF NOT EXISTS accounting;

-- share_classes, share_issuances, vesting_schedules
CREATE SCHEMA IF NOT EXISTS equity;

-- assets, beneficiaries
CREATE SCHEMA IF NOT EXISTS estates;

-- notations, questions, notation_questions
CREATE SCHEMA IF NOT EXISTS standards;

-- jurisdictions, courts, legal_credentials, licenses, notarizations, entity_types
CREATE SCHEMA IF NOT EXISTS legal;

-- relationship_notes, contracts, answers, retainers, signatures, assigned_notations
CREATE SCHEMA IF NOT EXISTS matters;

-- blobs
CREATE SCHEMA IF NOT EXISTS documents;
