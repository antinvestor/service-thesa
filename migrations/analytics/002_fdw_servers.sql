-- 002: Create Foreign Data Wrapper servers for each service database.
--
-- IMPORTANT: Replace the placeholder connection details with your actual
-- service database hosts, ports, and credentials before running.
--
-- Each server connects to one service's PostgreSQL database with a
-- read-only user. The user mapping should use a dedicated analytics
-- reader role with SELECT-only grants on the relevant tables.

-- Payment / Ledger service
CREATE SERVER IF NOT EXISTS payment_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'payment-db', dbname 'payment', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER payment_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Profile service
CREATE SERVER IF NOT EXISTS profile_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'profile-db', dbname 'profile', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER profile_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Notification service
CREATE SERVER IF NOT EXISTS notification_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'notification-db', dbname 'notification', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER notification_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Billing service
CREATE SERVER IF NOT EXISTS billing_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'billing-db', dbname 'billing', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER billing_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Files service
CREATE SERVER IF NOT EXISTS files_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'files-db', dbname 'files', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER files_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Geolocation service
CREATE SERVER IF NOT EXISTS geolocation_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'geolocation-db', dbname 'geolocation', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER geolocation_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Settings service
CREATE SERVER IF NOT EXISTS settings_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'settings-db', dbname 'settings', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER settings_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Tenancy / Partition service
CREATE SERVER IF NOT EXISTS tenancy_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'tenancy-db', dbname 'tenancy', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER tenancy_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Audit service
CREATE SERVER IF NOT EXISTS audit_srv
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'audit-db', dbname 'audit', port '5432');

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
    SERVER audit_srv
    OPTIONS (user 'analytics_reader', password 'CHANGE_ME');

-- Create schemas for foreign tables (one per service to avoid collisions).
CREATE SCHEMA IF NOT EXISTS fdw_payment;
CREATE SCHEMA IF NOT EXISTS fdw_profile;
CREATE SCHEMA IF NOT EXISTS fdw_notification;
CREATE SCHEMA IF NOT EXISTS fdw_billing;
CREATE SCHEMA IF NOT EXISTS fdw_files;
CREATE SCHEMA IF NOT EXISTS fdw_geolocation;
CREATE SCHEMA IF NOT EXISTS fdw_settings;
CREATE SCHEMA IF NOT EXISTS fdw_tenancy;
CREATE SCHEMA IF NOT EXISTS fdw_audit;

-- Import the tables you need from each service. Adjust table names to match
-- your actual service schemas. Example:
--
-- IMPORT FOREIGN SCHEMA public
--     LIMIT TO (payments, payment_links)
--     FROM SERVER payment_srv INTO fdw_payment;
--
-- IMPORT FOREIGN SCHEMA public
--     LIMIT TO (profiles, devices)
--     FROM SERVER profile_srv INTO fdw_profile;
--
-- Repeat for each service...
