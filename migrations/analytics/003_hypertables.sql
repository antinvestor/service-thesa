-- 003: Create local hypertables for each service's analytics data.
--
-- These are the query targets for the analytics engine. Data is synced
-- into them from the FDW foreign tables via the sync procedures in 005.
--
-- Every table includes:
--   - created_at TIMESTAMPTZ as the hypertable partition column
--   - tenant_id TEXT + partition_id TEXT for mandatory multi-tenant isolation
--   - An index on (tenant_id, partition_id, created_at) for efficient scoped queries

-- ============================================================
-- Payment
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.payments (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    route          TEXT,
    status         TEXT,
    state          TEXT,
    amount         NUMERIC,
    currency       TEXT,
    recipient      TEXT,
    processing_ms  NUMERIC
);
SELECT create_hypertable('analytics.payments', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_payments_tenant ON analytics.payments (tenant_id, partition_id, created_at DESC);

-- ============================================================
-- Profile
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.profiles (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    last_active    TIMESTAMPTZ,
    profile_type   TEXT,
    verified       BOOLEAN DEFAULT FALSE,
    display_name   TEXT
);
SELECT create_hypertable('analytics.profiles', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_profiles_tenant ON analytics.profiles (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.profile_activity (
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    display_name   TEXT NOT NULL,
    period_start   TIMESTAMPTZ NOT NULL,
    activity_count BIGINT NOT NULL DEFAULT 0
);
SELECT create_hypertable('analytics.profile_activity', 'period_start', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_profile_activity_tenant ON analytics.profile_activity (tenant_id, partition_id, period_start DESC);

-- ============================================================
-- Notification
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.notifications (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    channel        TEXT,
    status         TEXT,
    template_name  TEXT,
    delivered      BOOLEAN DEFAULT FALSE,
    opened         BOOLEAN DEFAULT FALSE
);
SELECT create_hypertable('analytics.notifications', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_notifications_tenant ON analytics.notifications (tenant_id, partition_id, created_at DESC);

-- ============================================================
-- Billing
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.subscriptions (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    updated_at     TIMESTAMPTZ,
    status         TEXT,
    plan_name      TEXT,
    monthly_amount NUMERIC
);
SELECT create_hypertable('analytics.subscriptions', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_subscriptions_tenant ON analytics.subscriptions (tenant_id, partition_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscriptions_updated ON analytics.subscriptions (tenant_id, partition_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS analytics.invoices (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    paid_at        TIMESTAMPTZ,
    status         TEXT,
    amount         NUMERIC,
    customer_name  TEXT
);
SELECT create_hypertable('analytics.invoices', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant ON analytics.invoices (tenant_id, partition_id, created_at DESC);

-- ============================================================
-- Files
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.files (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    content_type   TEXT,
    size_bytes     BIGINT,
    uploader       TEXT
);
SELECT create_hypertable('analytics.files', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_files_tenant ON analytics.files (tenant_id, partition_id, created_at DESC);

-- ============================================================
-- Geolocation
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.geo_areas (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    area_name      TEXT
);
SELECT create_hypertable('analytics.geo_areas', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_geo_areas_tenant ON analytics.geo_areas (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.geo_routes (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL
);
SELECT create_hypertable('analytics.geo_routes', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_geo_routes_tenant ON analytics.geo_routes (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.geo_events (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    event_type     TEXT,
    device_id      TEXT,
    area_name      TEXT
);
SELECT create_hypertable('analytics.geo_events', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_geo_events_tenant ON analytics.geo_events (tenant_id, partition_id, created_at DESC);

-- ============================================================
-- Settings
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.settings (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    module         TEXT
);
SELECT create_hypertable('analytics.settings', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_settings_tenant ON analytics.settings (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.setting_changes (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    changed_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, changed_at),
    module         TEXT,
    setting_key    TEXT,
    actor_id       TEXT
);
SELECT create_hypertable('analytics.setting_changes', 'changed_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_setting_changes_tenant ON analytics.setting_changes (tenant_id, partition_id, changed_at DESC);

-- ============================================================
-- Tenancy
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.tenants (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    tenant_name    TEXT,
    plan           TEXT
);
SELECT create_hypertable('analytics.tenants', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tenants_tenant ON analytics.tenants (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.partitions (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL
);
SELECT create_hypertable('analytics.partitions', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_partitions_tenant ON analytics.partitions (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.access_logs (
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    user_id        TEXT NOT NULL
);
SELECT create_hypertable('analytics.access_logs', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_access_logs_tenant ON analytics.access_logs (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.tenant_stats (
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    tenant_name    TEXT,
    period_end     TIMESTAMPTZ NOT NULL,
    user_count     BIGINT NOT NULL DEFAULT 0
);
SELECT create_hypertable('analytics.tenant_stats', 'period_end', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tenant_stats_tenant ON analytics.tenant_stats (tenant_id, partition_id, period_end DESC);

-- ============================================================
-- Audit
-- ============================================================
CREATE TABLE IF NOT EXISTS analytics.audit_entries (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, created_at),
    action         TEXT,
    service        TEXT,
    actor_id       TEXT,
    actor_name     TEXT
);
SELECT create_hypertable('analytics.audit_entries', 'created_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_audit_entries_tenant ON analytics.audit_entries (tenant_id, partition_id, created_at DESC);

CREATE TABLE IF NOT EXISTS analytics.integrity_checks (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    checked_at     TIMESTAMPTZ NOT NULL,
    UNIQUE (id, checked_at)
);
SELECT create_hypertable('analytics.integrity_checks', 'checked_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_integrity_checks_tenant ON analytics.integrity_checks (tenant_id, partition_id, checked_at DESC);

CREATE TABLE IF NOT EXISTS analytics.audit_anomalies (
    id             TEXT NOT NULL,
    tenant_id      TEXT NOT NULL,
    partition_id   TEXT NOT NULL,
    detected_at    TIMESTAMPTZ NOT NULL,
    UNIQUE (id, detected_at)
);
SELECT create_hypertable('analytics.audit_anomalies', 'detected_at', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_audit_anomalies_tenant ON analytics.audit_anomalies (tenant_id, partition_id, detected_at DESC);
