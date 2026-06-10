package config

import (
	"testing"
	"time"
)

func TestLoad_valid(t *testing.T) {
	cfg, err := Load("testdata/valid.yaml")
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Server.Port != 9090 {
		t.Errorf("Server.Port = %d, want 9090", cfg.Server.Port)
	}
	if cfg.Server.ReadTimeout != 15*time.Second {
		t.Errorf("Server.ReadTimeout = %v, want 15s", cfg.Server.ReadTimeout)
	}
	if !cfg.Definitions.HotReload {
		t.Error("Definitions.HotReload = false, want true")
	}
	if len(cfg.Specs.Sources) != 1 {
		t.Errorf("Specs.Sources = %d entries, want 1", len(cfg.Specs.Sources))
	}

	svc, ok := cfg.Services["orders-svc"]
	if !ok {
		t.Fatal("Services[orders-svc] not found")
	}
	if svc.BaseURL != "https://orders.internal" {
		t.Errorf("orders-svc.BaseURL = %q", svc.BaseURL)
	}
	if svc.Timeout != 10*time.Second {
		t.Errorf("orders-svc.Timeout = %v, want 10s", svc.Timeout)
	}
	if svc.Retry.MaxAttempts != 3 {
		t.Errorf("orders-svc.Retry.MaxAttempts = %d, want 3", svc.Retry.MaxAttempts)
	}
}

func TestLoad_missing_file(t *testing.T) {
	_, err := Load("testdata/nonexistent.yaml")
	if err == nil {
		t.Fatal("Load() with missing file should return error")
	}
}

func TestDefaults(t *testing.T) {
	cfg := Defaults()
	if cfg.Server.Port != 8080 {
		t.Errorf("default Server.Port = %d, want 8080", cfg.Server.Port)
	}
	if cfg.Capability.Cache.TTL != 5*time.Minute {
		t.Errorf("default Capability.Cache.TTL = %v, want 5m", cfg.Capability.Cache.TTL)
	}
	if cfg.Observability.LogLevel != "info" {
		t.Errorf("default LogLevel = %q, want info", cfg.Observability.LogLevel)
	}
}

func TestEnvOverrides(t *testing.T) {
	t.Setenv("THESA_SERVER_PORT", "3000")
	t.Setenv("THESA_OBSERVABILITY_LOG_LEVEL", "error")

	cfg, err := Load("testdata/valid.yaml")
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Server.Port != 3000 {
		t.Errorf("Server.Port = %d, want 3000 (env override)", cfg.Server.Port)
	}
	if cfg.Observability.LogLevel != "error" {
		t.Errorf("LogLevel = %q, want error (env override)", cfg.Observability.LogLevel)
	}
}

func TestEnvOverrides_AnalyticsUptrace(t *testing.T) {
	t.Setenv("ANALYTICS_BACKEND_TYPE", "uptrace")
	t.Setenv("ANALYTICS_BACKEND_URL", "https://api.uptrace.dev/api/prometheus/4242")
	t.Setenv("ANALYTICS_TOKEN", "project-token-abc")
	t.Setenv("ANALYTICS_CACHE_TTL", "45s")
	t.Setenv("ANALYTICS_ALLOWED_METRICS", `^foo_.+, ^bar\..+`)

	cfg, err := Load("testdata/valid.yaml")
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Analytics.BackendType != "uptrace" {
		t.Errorf("Analytics.BackendType = %q, want uptrace", cfg.Analytics.BackendType)
	}
	if cfg.Analytics.BackendURL != "https://api.uptrace.dev/api/prometheus/4242" {
		t.Errorf("Analytics.BackendURL = %q", cfg.Analytics.BackendURL)
	}
	if !cfg.Analytics.Enabled {
		t.Error("Analytics.Enabled = false, want true when ANALYTICS_BACKEND_URL is set")
	}
	if cfg.Analytics.Token != "project-token-abc" {
		t.Errorf("Analytics.Token = %q, want project-token-abc", cfg.Analytics.Token)
	}
	if cfg.Analytics.CacheTTL != 45*time.Second {
		t.Errorf("Analytics.CacheTTL = %v, want 45s", cfg.Analytics.CacheTTL)
	}
	want := []string{`^foo_.+`, `^bar\..+`}
	if len(cfg.Analytics.AllowedMetrics) != len(want) {
		t.Fatalf("Analytics.AllowedMetrics = %v, want %v", cfg.Analytics.AllowedMetrics, want)
	}
	for i, p := range want {
		if cfg.Analytics.AllowedMetrics[i] != p {
			t.Errorf("Analytics.AllowedMetrics[%d] = %q, want %q", i, cfg.Analytics.AllowedMetrics[i], p)
		}
	}
}

func TestEnvOverrides_AnalyticsCacheTTLPlainSeconds(t *testing.T) {
	t.Setenv("ANALYTICS_CACHE_TTL", "300")

	cfg, err := Load("testdata/valid.yaml")
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.Analytics.CacheTTL != 300*time.Second {
		t.Errorf("Analytics.CacheTTL = %v, want 300s (plain integer seconds)", cfg.Analytics.CacheTTL)
	}
}

func TestDefaults_AnalyticsCacheTTL(t *testing.T) {
	cfg := Defaults()
	if cfg.Analytics.CacheTTL != 120*time.Second {
		t.Errorf("default Analytics.CacheTTL = %v, want 120s", cfg.Analytics.CacheTTL)
	}
}

func TestValidate_invalid_port(t *testing.T) {
	cfg := Defaults()
	cfg.Server.Port = 0

	err := cfg.Validate()
	if err == nil {
		t.Fatal("Validate() with port 0 should return error")
	}
}

func TestLoad_env_priority_over_file(t *testing.T) {
	// File sets port 9090, env sets 5555 — env wins
	t.Setenv("THESA_SERVER_PORT", "5555")

	cfg, err := Load("testdata/valid.yaml")
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.Server.Port != 5555 {
		t.Errorf("Server.Port = %d, want 5555 (env override beats file)", cfg.Server.Port)
	}
}
