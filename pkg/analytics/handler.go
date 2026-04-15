package analytics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/pitabwire/util"
)

// RegisterRoutes registers the analytics POST endpoints on the given mux,
// wrapped in the provided auth middleware chain.
func RegisterRoutes(
	mux *http.ServeMux,
	engine *Engine,
	authChain func(http.Handler) http.Handler,
) {
	mux.Handle("POST /api/analytics/query/scalar", authChain(handleScalar(engine)))
	mux.Handle("POST /api/analytics/query/timeseries", authChain(handleTimeSeries(engine)))
	mux.Handle("POST /api/analytics/query/grouped", authChain(handleGrouped(engine)))
	mux.Handle("POST /api/analytics/query/topn", authChain(handleTopN(engine)))
}

func handleScalar(engine *Engine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req AnalyticsRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}

		tr, err := parseTimeRange(req.TimeRange)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		query := req.ToMetricQuery()
		val, err := engine.Scalar(r.Context(), query, req.PartitionIDs, tr)
		if err != nil {
			if isValidationError(err) {
				writeError(w, err.Error(), http.StatusBadRequest)
			} else {
				logAndWriteInternalError(r, w, "scalar query failed", err)
			}
			return
		}

		writeJSON(w, map[string]any{"value": val})
	}
}

func handleTimeSeries(engine *Engine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req AnalyticsRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}

		tr, err := parseTimeRange(req.TimeRange)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		// Parse step from request, default to "hour".
		stepStr := req.Step
		if stepStr == "" {
			stepStr = "hour"
		}
		step, err := ValidateGranularity(stepStr)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		query := req.ToMetricQuery()
		points, err := engine.TimeSeriesQuery(r.Context(), query, req.PartitionIDs, tr, step)
		if err != nil {
			if isValidationError(err) {
				writeError(w, err.Error(), http.StatusBadRequest)
			} else {
				logAndWriteInternalError(r, w, "timeseries query failed", err)
			}
			return
		}

		writeJSON(w, map[string]any{"points": points})
	}
}

func handleGrouped(engine *Engine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req AnalyticsRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.GroupBy == "" {
			writeError(w, "missing required field: group_by", http.StatusBadRequest)
			return
		}

		tr, err := parseTimeRange(req.TimeRange)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		query := req.ToMetricQuery()
		segments, err := engine.Grouped(r.Context(), query, req.PartitionIDs, tr, req.GroupBy)
		if err != nil {
			if isValidationError(err) {
				writeError(w, err.Error(), http.StatusBadRequest)
			} else {
				logAndWriteInternalError(r, w, "grouped query failed", err)
			}
			return
		}

		writeJSON(w, map[string]any{"segments": segments})
	}
}

func handleTopN(engine *Engine) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req AnalyticsRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, "invalid request body", http.StatusBadRequest)
			return
		}

		if req.GroupBy == "" {
			writeError(w, "missing required field: group_by", http.StatusBadRequest)
			return
		}

		tr, err := parseTimeRange(req.TimeRange)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		limit := req.Limit
		if limit <= 0 {
			limit = 10
		}

		query := req.ToMetricQuery()
		items, err := engine.TopN(r.Context(), query, req.PartitionIDs, tr, req.GroupBy, limit)
		if err != nil {
			if isValidationError(err) {
				writeError(w, err.Error(), http.StatusBadRequest)
			} else {
				logAndWriteInternalError(r, w, "top-N query failed", err)
			}
			return
		}

		writeJSON(w, map[string]any{"items": items})
	}
}

// --- parsing & response helpers ---

func parseTimeRange(trr TimeRangeRequest) (TimeRange, error) {
	now := time.Now().UTC()
	tr := TimeRange{
		Start: now.AddDate(0, 0, -30),
		End:   now,
	}

	if trr.Start != "" {
		t, err := time.Parse(time.RFC3339, trr.Start)
		if err != nil {
			return tr, fmt.Errorf("invalid start: expected RFC3339 format")
		}
		tr.Start = t
	}
	if trr.End != "" {
		t, err := time.Parse(time.RFC3339, trr.End)
		if err != nil {
			return tr, fmt.Errorf("invalid end: expected RFC3339 format")
		}
		tr.End = t
	}
	return tr, nil
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

func writeError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func logAndWriteInternalError(r *http.Request, w http.ResponseWriter, msg string, err error) {
	util.Log(r.Context()).WithError(err).Error(msg)
	writeError(w, "internal server error", http.StatusInternalServerError)
}
