package analytics

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"
)

// RegisterRoutes registers analytics API endpoints on the given mux.
func RegisterRoutes(mux *http.ServeMux, engine *AnalyticsEngine) {
	mux.HandleFunc("GET /api/analytics/metrics", handleMetrics(engine))
	mux.HandleFunc("GET /api/analytics/timeseries", handleTimeSeries(engine))
	mux.HandleFunc("GET /api/analytics/distribution", handleDistribution(engine))
	mux.HandleFunc("GET /api/analytics/top", handleTopN(engine))
}

// parseTimeRange extracts a TimeRange from query parameters.
func parseTimeRange(r *http.Request) TimeRange {
	now := time.Now().UTC()
	tr := TimeRange{
		Start:       now.AddDate(0, 0, -30),
		End:         now,
		Granularity: r.URL.Query().Get("granularity"),
	}

	if s := r.URL.Query().Get("start"); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			tr.Start = t
		}
	}
	if s := r.URL.Query().Get("end"); s != "" {
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			tr.End = t
		}
	}
	return tr
}

// writeJSON encodes v as JSON and writes it to w.
func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// writeError writes a JSON error response.
func writeError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func handleMetrics(engine *AnalyticsEngine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service := r.URL.Query().Get("service")
		if service == "" {
			writeError(w, "missing required parameter: service", http.StatusBadRequest)
			return
		}

		tr := parseTimeRange(r)
		metrics, err := engine.QueryMetrics(r.Context(), service, tr)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}

		writeJSON(w, map[string]any{
			"service": service,
			"metrics": metrics,
		})
	}
}

func handleTimeSeries(engine *AnalyticsEngine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service := r.URL.Query().Get("service")
		metric := r.URL.Query().Get("metric")
		if service == "" || metric == "" {
			writeError(w, "missing required parameters: service, metric", http.StatusBadRequest)
			return
		}

		tr := parseTimeRange(r)
		series, err := engine.QueryTimeSeries(r.Context(), service, metric, tr)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}

		writeJSON(w, map[string]any{
			"service": service,
			"metric":  metric,
			"series":  series,
		})
	}
}

func handleDistribution(engine *AnalyticsEngine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service := r.URL.Query().Get("service")
		metric := r.URL.Query().Get("metric")
		groupBy := r.URL.Query().Get("group_by")
		if service == "" || metric == "" {
			writeError(w, "missing required parameters: service, metric", http.StatusBadRequest)
			return
		}
		if groupBy == "" {
			groupBy = "default"
		}

		tr := parseTimeRange(r)
		segments, err := engine.QueryDistribution(r.Context(), service, metric, groupBy, tr)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}

		writeJSON(w, map[string]any{
			"service":  service,
			"metric":   metric,
			"group_by": groupBy,
			"segments": segments,
		})
	}
}

func handleTopN(engine *AnalyticsEngine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service := r.URL.Query().Get("service")
		metric := r.URL.Query().Get("metric")
		if service == "" || metric == "" {
			writeError(w, "missing required parameters: service, metric", http.StatusBadRequest)
			return
		}

		limit := 10
		if s := r.URL.Query().Get("limit"); s != "" {
			if n, err := strconv.Atoi(s); err == nil && n > 0 {
				limit = n
			}
		}

		tr := parseTimeRange(r)
		items, err := engine.QueryTopN(r.Context(), service, metric, limit, tr)
		if err != nil {
			writeError(w, err.Error(), http.StatusInternalServerError)
			return
		}

		writeJSON(w, map[string]any{
			"service": service,
			"metric":  metric,
			"items":   items,
		})
	}
}
