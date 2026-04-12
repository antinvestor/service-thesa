-- 001: Enable required extensions and create the analytics schema.
--
-- Prerequisites:
--   - PostgreSQL 14+ with TimescaleDB extension installed
--   - postgres_fdw extension available (ships with PostgreSQL)
--
-- Run as a superuser or a role with CREATE EXTENSION privileges.

CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- All analytics tables live in their own schema to avoid namespace collisions.
CREATE SCHEMA IF NOT EXISTS analytics;

-- Metadata table tracking FDW sync state per source table.
CREATE TABLE IF NOT EXISTS analytics.sync_state (
    source_table   TEXT PRIMARY KEY,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT '1970-01-01T00:00:00Z',
    rows_synced    BIGINT NOT NULL DEFAULT 0,
    last_error     TEXT,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
