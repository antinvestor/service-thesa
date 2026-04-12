-- 006: Compression and retention policies.
--
-- Compression shrinks old chunks 90-95% using TimescaleDB's columnar compression.
-- Retention drops raw data past a threshold while continuous aggregates survive.

-- ============================================================
-- Compression policies — compress chunks older than 30 days
-- ============================================================
ALTER TABLE analytics.payments       SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.profiles       SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.notifications  SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.subscriptions  SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.invoices       SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.files          SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.geo_events     SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.audit_entries  SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.setting_changes SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');
ALTER TABLE analytics.access_logs    SET (timescaledb.compress, timescaledb.compress_segmentby = 'tenant_id');

SELECT add_compression_policy('analytics.payments',       INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.profiles',       INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.notifications',  INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.subscriptions',  INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.invoices',       INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.files',          INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.geo_events',     INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.audit_entries',  INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.setting_changes', INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('analytics.access_logs',    INTERVAL '30 days', if_not_exists => TRUE);

-- ============================================================
-- Retention policies — drop raw data older than 1 year
-- ============================================================
-- Continuous aggregates (payments_hourly, etc.) are NOT affected by retention
-- policies on the underlying hypertable — they survive independently.
SELECT add_retention_policy('analytics.payments',       INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.profiles',       INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.notifications',  INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.subscriptions',  INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.invoices',       INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.files',          INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.geo_events',     INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.audit_entries',  INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.setting_changes', INTERVAL '1 year', if_not_exists => TRUE);
SELECT add_retention_policy('analytics.access_logs',    INTERVAL '1 year', if_not_exists => TRUE);
