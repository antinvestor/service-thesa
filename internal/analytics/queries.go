package analytics

// MetricQuery defines a SQL query that returns a single aggregate value.
type MetricQuery struct {
	Key   string // Unique key referenced from the frontend
	Label string // Human-readable label
	SQL   string // Query with {{start}}, {{end}} placeholders
	Unit  string // count, currency, percent, bytes
	Icon  string // Material icon name hint for the frontend
}

// TimeSeriesQuery defines a SQL query that returns (timestamp, value) rows.
type TimeSeriesQuery struct {
	Key   string
	Label string
	SQL   string // Query with {{start}}, {{end}}, {{granularity}} placeholders
}

// DistributionQuery defines a SQL query that returns (label, value) rows.
type DistributionQuery struct {
	Key   string
	Label string
	SQL   string // Query with {{start}}, {{end}}, {{group_by}} placeholders
}

// TopNQuery defines a SQL query that returns (label, value) rows ordered by value desc.
type TopNQuery struct {
	Key   string
	Label string
	SQL   string // Query with {{start}}, {{end}}, {{limit}} placeholders
}

// ServiceQuerySet groups all analytics queries for a single service.
type ServiceQuerySet struct {
	Metrics       []MetricQuery
	TimeSeries    []TimeSeriesQuery
	Distributions []DistributionQuery
	TopN          []TopNQuery
}

// ServiceQueries is the global registry of analytics queries keyed by service ID.
// Add new services here to expose their analytics through the API.
var ServiceQueries = map[string]ServiceQuerySet{
	"payment": {
		Metrics: []MetricQuery{
			{Key: "total_payments", Label: "Total Payments", Unit: "count", Icon: "payment",
				SQL: "SELECT count(*) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "total_volume", Label: "Total Volume", Unit: "currency", Icon: "attach_money",
				SQL: "SELECT coalesce(sum(amount), 0) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "success_rate", Label: "Success Rate", Unit: "percent", Icon: "check_circle",
				SQL: "SELECT coalesce(avg(case when status = 'success' then 100.0 else 0 end), 0) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "avg_processing_time", Label: "Avg Processing", Unit: "count", Icon: "timer",
				SQL: "SELECT coalesce(avg(processing_ms), 0) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "payment_volume", Label: "Payment Volume",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
			{Key: "payment_amount", Label: "Payment Amount",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, sum(amount) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "payment_routes", Label: "By Route",
				SQL: "SELECT route, count(*) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY route ORDER BY count(*) DESC"},
			{Key: "payment_status", Label: "By Status",
				SQL: "SELECT status, count(*) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY status ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_recipients", Label: "Top Recipients",
				SQL: "SELECT recipient, sum(amount) FROM analytics.payments WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY recipient ORDER BY sum(amount) DESC LIMIT {{limit}}"},
		},
	},
	"profile": {
		Metrics: []MetricQuery{
			{Key: "total_profiles", Label: "Total Profiles", Unit: "count", Icon: "people",
				SQL: "SELECT count(*) FROM analytics.profiles WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "active_profiles", Label: "Active Profiles", Unit: "count", Icon: "person",
				SQL: "SELECT count(*) FROM analytics.profiles WHERE last_active >= '{{start}}' AND last_active < '{{end}}'"},
			{Key: "new_registrations", Label: "New Registrations", Unit: "count", Icon: "person_add",
				SQL: "SELECT count(*) FROM analytics.profiles WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "verification_rate", Label: "Verification Rate", Unit: "percent", Icon: "verified",
				SQL: "SELECT coalesce(avg(case when verified then 100.0 else 0 end), 0) FROM analytics.profiles WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "registrations", Label: "Registrations",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.profiles WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "profile_types", Label: "By Type",
				SQL: "SELECT profile_type, count(*) FROM analytics.profiles WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY profile_type ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_active_profiles", Label: "Most Active Profiles",
				SQL: "SELECT display_name, activity_count FROM analytics.profile_activity WHERE period_start >= '{{start}}' AND period_start < '{{end}}' ORDER BY activity_count DESC LIMIT {{limit}}"},
		},
	},
	"notification": {
		Metrics: []MetricQuery{
			{Key: "total_sent", Label: "Total Sent", Unit: "count", Icon: "send",
				SQL: "SELECT count(*) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "delivery_rate", Label: "Delivery Rate", Unit: "percent", Icon: "mark_email_read",
				SQL: "SELECT coalesce(avg(case when delivered then 100.0 else 0 end), 0) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "open_rate", Label: "Open Rate", Unit: "percent", Icon: "visibility",
				SQL: "SELECT coalesce(avg(case when opened then 100.0 else 0 end), 0) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "failed_count", Label: "Failed", Unit: "count", Icon: "error",
				SQL: "SELECT count(*) FROM analytics.notifications WHERE status = 'failed' AND created_at >= '{{start}}' AND created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "notifications_sent", Label: "Notifications Sent",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "notification_channels", Label: "By Channel",
				SQL: "SELECT channel, count(*) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY channel ORDER BY count(*) DESC"},
			{Key: "notification_status", Label: "By Status",
				SQL: "SELECT status, count(*) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY status ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_templates", Label: "Top Templates",
				SQL: "SELECT template_name, count(*) FROM analytics.notifications WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY template_name ORDER BY count(*) DESC LIMIT {{limit}}"},
		},
	},
	"billing": {
		Metrics: []MetricQuery{
			{Key: "active_subscriptions", Label: "Active Subscriptions", Unit: "count", Icon: "autorenew",
				SQL: "SELECT count(*) FROM analytics.subscriptions WHERE status = 'active' AND created_at < '{{end}}'"},
			{Key: "mrr", Label: "Monthly Revenue", Unit: "currency", Icon: "trending_up",
				SQL: "SELECT coalesce(sum(monthly_amount), 0) FROM analytics.subscriptions WHERE status = 'active' AND created_at < '{{end}}'"},
			{Key: "outstanding_invoices", Label: "Outstanding", Unit: "currency", Icon: "receipt_long",
				SQL: "SELECT coalesce(sum(amount), 0) FROM analytics.invoices WHERE status = 'pending' AND created_at < '{{end}}'"},
			{Key: "churn_rate", Label: "Churn Rate", Unit: "percent", Icon: "trending_down",
				SQL: "SELECT coalesce(avg(case when status = 'cancelled' then 100.0 else 0 end), 0) FROM analytics.subscriptions WHERE updated_at >= '{{start}}' AND updated_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "revenue", Label: "Revenue",
				SQL: "SELECT date_trunc('{{granularity}}', paid_at) AS bucket, sum(amount) FROM analytics.invoices WHERE status = 'paid' AND paid_at >= '{{start}}' AND paid_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "subscription_plans", Label: "By Plan",
				SQL: "SELECT plan_name, count(*) FROM analytics.subscriptions WHERE status = 'active' AND created_at < '{{end}}' GROUP BY plan_name ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_customers", Label: "Top Customers by Revenue",
				SQL: "SELECT customer_name, sum(amount) FROM analytics.invoices WHERE status = 'paid' AND paid_at >= '{{start}}' AND paid_at < '{{end}}' GROUP BY customer_name ORDER BY sum(amount) DESC LIMIT {{limit}}"},
		},
	},
	"files": {
		Metrics: []MetricQuery{
			{Key: "total_files", Label: "Total Files", Unit: "count", Icon: "folder",
				SQL: "SELECT count(*) FROM analytics.files WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "total_storage", Label: "Storage Used", Unit: "bytes", Icon: "storage",
				SQL: "SELECT coalesce(sum(size_bytes), 0) FROM analytics.files WHERE created_at < '{{end}}'"},
			{Key: "uploads_today", Label: "Uploads Today", Unit: "count", Icon: "upload",
				SQL: "SELECT count(*) FROM analytics.files WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "avg_file_size", Label: "Avg File Size", Unit: "bytes", Icon: "description",
				SQL: "SELECT coalesce(avg(size_bytes), 0) FROM analytics.files WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "upload_volume", Label: "Uploads",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.files WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "file_types", Label: "By Type",
				SQL: "SELECT content_type, count(*) FROM analytics.files WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY content_type ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_uploaders", Label: "Top Uploaders",
				SQL: "SELECT uploader, count(*) FROM analytics.files WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY uploader ORDER BY count(*) DESC LIMIT {{limit}}"},
		},
	},
	"geolocation": {
		Metrics: []MetricQuery{
			{Key: "total_areas", Label: "Total Areas", Unit: "count", Icon: "map",
				SQL: "SELECT count(*) FROM analytics.geo_areas WHERE created_at < '{{end}}'"},
			{Key: "total_routes", Label: "Total Routes", Unit: "count", Icon: "route",
				SQL: "SELECT count(*) FROM analytics.geo_routes WHERE created_at < '{{end}}'"},
			{Key: "geo_events", Label: "Geo Events", Unit: "count", Icon: "place",
				SQL: "SELECT count(*) FROM analytics.geo_events WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "active_trackers", Label: "Active Trackers", Unit: "count", Icon: "gps_fixed",
				SQL: "SELECT count(distinct device_id) FROM analytics.geo_events WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "geo_event_volume", Label: "Geo Events",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.geo_events WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "event_types", Label: "By Event Type",
				SQL: "SELECT event_type, count(*) FROM analytics.geo_events WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY event_type ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_areas", Label: "Most Active Areas",
				SQL: "SELECT area_name, count(*) FROM analytics.geo_events WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY area_name ORDER BY count(*) DESC LIMIT {{limit}}"},
		},
	},
	"settings": {
		Metrics: []MetricQuery{
			{Key: "total_settings", Label: "Total Settings", Unit: "count", Icon: "settings",
				SQL: "SELECT count(*) FROM analytics.settings WHERE created_at < '{{end}}'"},
			{Key: "recent_changes", Label: "Recent Changes", Unit: "count", Icon: "edit",
				SQL: "SELECT count(*) FROM analytics.setting_changes WHERE changed_at >= '{{start}}' AND changed_at < '{{end}}'"},
			{Key: "modules_count", Label: "Modules", Unit: "count", Icon: "widgets",
				SQL: "SELECT count(distinct module) FROM analytics.settings WHERE created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "setting_changes", Label: "Configuration Changes",
				SQL: "SELECT date_trunc('{{granularity}}', changed_at) AS bucket, count(*) FROM analytics.setting_changes WHERE changed_at >= '{{start}}' AND changed_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "settings_by_module", Label: "By Module",
				SQL: "SELECT module, count(*) FROM analytics.settings WHERE created_at < '{{end}}' GROUP BY module ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{},
	},
	"tenancy": {
		Metrics: []MetricQuery{
			{Key: "total_tenants", Label: "Total Tenants", Unit: "count", Icon: "domain",
				SQL: "SELECT count(*) FROM analytics.tenants WHERE created_at < '{{end}}'"},
			{Key: "total_partitions", Label: "Total Partitions", Unit: "count", Icon: "account_tree",
				SQL: "SELECT count(*) FROM analytics.partitions WHERE created_at < '{{end}}'"},
			{Key: "active_users", Label: "Active Users", Unit: "count", Icon: "group",
				SQL: "SELECT count(distinct user_id) FROM analytics.access_logs WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "new_tenants", Label: "New Tenants", Unit: "count", Icon: "add_business",
				SQL: "SELECT count(*) FROM analytics.tenants WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "tenant_growth", Label: "Tenant Growth",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.tenants WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "tenants_by_plan", Label: "By Plan",
				SQL: "SELECT plan, count(*) FROM analytics.tenants WHERE created_at < '{{end}}' GROUP BY plan ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_tenants", Label: "Largest Tenants",
				SQL: "SELECT tenant_name, user_count FROM analytics.tenant_stats WHERE period_end >= '{{start}}' ORDER BY user_count DESC LIMIT {{limit}}"},
		},
	},
	"audit": {
		Metrics: []MetricQuery{
			{Key: "total_entries", Label: "Audit Entries", Unit: "count", Icon: "history",
				SQL: "SELECT count(*) FROM analytics.audit_entries WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "unique_actors", Label: "Unique Actors", Unit: "count", Icon: "people",
				SQL: "SELECT count(distinct actor_id) FROM analytics.audit_entries WHERE created_at >= '{{start}}' AND created_at < '{{end}}'"},
			{Key: "integrity_checks", Label: "Integrity Checks", Unit: "count", Icon: "verified",
				SQL: "SELECT count(*) FROM analytics.integrity_checks WHERE checked_at >= '{{start}}' AND checked_at < '{{end}}'"},
			{Key: "anomalies", Label: "Anomalies", Unit: "count", Icon: "warning",
				SQL: "SELECT count(*) FROM analytics.audit_anomalies WHERE detected_at >= '{{start}}' AND detected_at < '{{end}}'"},
		},
		TimeSeries: []TimeSeriesQuery{
			{Key: "audit_volume", Label: "Audit Volume",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.audit_entries WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionQuery{
			{Key: "audit_actions", Label: "By Action",
				SQL: "SELECT action, count(*) FROM analytics.audit_entries WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY action ORDER BY count(*) DESC"},
			{Key: "audit_services", Label: "By Service",
				SQL: "SELECT service, count(*) FROM analytics.audit_entries WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY service ORDER BY count(*) DESC"},
		},
		TopN: []TopNQuery{
			{Key: "top_actors", Label: "Most Active Actors",
				SQL: "SELECT actor_name, count(*) FROM analytics.audit_entries WHERE created_at >= '{{start}}' AND created_at < '{{end}}' GROUP BY actor_name ORDER BY count(*) DESC LIMIT {{limit}}"},
		},
	},
}
