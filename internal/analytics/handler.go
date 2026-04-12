package analytics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/pitabwire/util"

	"github.com/antinvestor/service-thesa/model"
)

// ctxExtractors holds functions that extract auth context values. These are
// injected to avoid a compile-time dependency on the transport package.
type ctxExtractors struct {
	capabilities func(r *http.Request) model.CapabilitySet
	requestCtx   func(r *http.Request) *model.RequestContext
}

// RegisterRoutes registers all analytics API endpoints on the given mux,
// wrapped in the provided auth middleware chain.
func RegisterRoutes(
	mux *http.ServeMux,
	engine *Engine,
	authChain func(http.Handler) http.Handler,
	capsFn func(r *http.Request) model.CapabilitySet,
	rctxFn func(r *http.Request) *model.RequestContext,
) {
	ext := &ctxExtractors{capabilities: capsFn, requestCtx: rctxFn}

	mux.Handle("GET /api/analytics/services", authChain(handleListServices(engine, ext)))
	mux.Handle("GET /api/analytics/metrics", authChain(handleMetrics(engine, ext)))
	mux.Handle("GET /api/analytics/timeseries", authChain(handleTimeSeries(engine, ext)))
	mux.Handle("GET /api/analytics/distribution", authChain(handleDistribution(engine, ext)))
	mux.Handle("GET /api/analytics/top", authChain(handleTopN(engine, ext)))
}

func handleListServices(engine *Engine, ext *ctxExtractors) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		caps := ext.capabilities(r)
		if caps == nil {
			writeError(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var accessible []serviceInfo
		for _, id := range engine.registry.Services() {
			sa, _ := engine.registry.Get(id)
			if sa != nil && caps.Has(sa.ViewPermission) {
				accessible = append(accessible, serviceInfo{
					ID:         sa.ServiceID,
					Permission: sa.ViewPermission,
				})
			}
		}
		sort.Slice(accessible, func(i, j int) bool { return accessible[i].ID < accessible[j].ID })

		writeJSON(w, map[string]any{"services": accessible})
	}
}

type serviceInfo struct {
	ID         string `json:"id"`
	Permission string `json:"permission"`
}

func handleMetrics(engine *Engine, ext *ctxExtractors) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service, caps, err := extractAndAuthorize(r, engine, ext)
		if err != nil {
			writeAuthError(w, err)
			return
		}

		tr, err := parseTimeRange(r)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		allMetrics, err := engine.QueryMetrics(r.Context(), service, tr)
		if err != nil {
			logAndWriteInternalError(r, w, "metrics query failed", err)
			return
		}

		sa, _ := engine.registry.Get(service)
		filtered := filterMetrics(allMetrics, sa, caps)

		writeJSON(w, map[string]any{
			"service": service,
			"metrics": filtered,
		})
	}
}

func handleTimeSeries(engine *Engine, ext *ctxExtractors) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service, caps, err := extractAndAuthorize(r, engine, ext)
		if err != nil {
			writeAuthError(w, err)
			return
		}

		metric := r.URL.Query().Get("metric")
		if metric == "" {
			writeError(w, "missing required parameter: metric", http.StatusBadRequest)
			return
		}

		if !hasMetricPermission(engine, service, "timeseries", metric, caps) {
			writeError(w, "insufficient permissions", http.StatusForbidden)
			return
		}

		tr, err := parseTimeRange(r)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		series, err := engine.QueryTimeSeries(r.Context(), service, metric, tr)
		if err != nil {
			logAndWriteInternalError(r, w, "timeseries query failed", err)
			return
		}

		writeJSON(w, map[string]any{
			"service": service,
			"metric":  metric,
			"series":  series,
		})
	}
}

func handleDistribution(engine *Engine, ext *ctxExtractors) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service, caps, err := extractAndAuthorize(r, engine, ext)
		if err != nil {
			writeAuthError(w, err)
			return
		}

		metric := r.URL.Query().Get("metric")
		groupBy := r.URL.Query().Get("group_by")
		if metric == "" {
			writeError(w, "missing required parameter: metric", http.StatusBadRequest)
			return
		}

		if !hasMetricPermission(engine, service, "distribution", metric, caps) {
			writeError(w, "insufficient permissions", http.StatusForbidden)
			return
		}

		if groupBy == "" {
			sa, _ := engine.registry.Get(service)
			if sa != nil {
				for _, d := range sa.Distributions {
					if d.Key == metric && len(d.AllowedGroupBy) > 0 {
						groupBy = d.AllowedGroupBy[0]
						break
					}
				}
			}
		}

		tr, err := parseTimeRange(r)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		segments, err := engine.QueryDistribution(r.Context(), service, metric, groupBy, tr)
		if err != nil {
			if isValidationError(err) {
				writeError(w, "invalid group_by parameter", http.StatusBadRequest)
			} else {
				logAndWriteInternalError(r, w, "distribution query failed", err)
			}
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

func handleTopN(engine *Engine, ext *ctxExtractors) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		service, caps, err := extractAndAuthorize(r, engine, ext)
		if err != nil {
			writeAuthError(w, err)
			return
		}

		metric := r.URL.Query().Get("metric")
		if metric == "" {
			writeError(w, "missing required parameter: metric", http.StatusBadRequest)
			return
		}

		if !hasMetricPermission(engine, service, "topn", metric, caps) {
			writeError(w, "insufficient permissions", http.StatusForbidden)
			return
		}

		limit := 10
		if s := r.URL.Query().Get("limit"); s != "" {
			if n, err := strconv.Atoi(s); err == nil && n > 0 {
				limit = n
			}
		}

		tr, err := parseTimeRange(r)
		if err != nil {
			writeError(w, err.Error(), http.StatusBadRequest)
			return
		}

		items, err := engine.QueryTopN(r.Context(), service, metric, limit, tr)
		if err != nil {
			logAndWriteInternalError(r, w, "top-N query failed", err)
			return
		}

		writeJSON(w, map[string]any{
			"service": service,
			"metric":  metric,
			"items":   items,
		})
	}
}

// --- authorization helpers ---

type authError struct {
	msg    string
	status int
}

func (e *authError) Error() string { return e.msg }

func extractAndAuthorize(
	r *http.Request,
	engine *Engine,
	ext *ctxExtractors,
) (string, model.CapabilitySet, error) {
	service := r.URL.Query().Get("service")
	if service == "" {
		return "", nil, &authError{"missing required parameter: service", http.StatusBadRequest}
	}

	rctx := ext.requestCtx(r)
	if rctx == nil {
		return "", nil, &authError{"unauthorized", http.StatusUnauthorized}
	}

	caps := ext.capabilities(r)
	if caps == nil {
		return "", nil, &authError{"unauthorized", http.StatusUnauthorized}
	}

	sa, ok := engine.registry.Get(service)
	if !ok {
		return "", nil, &authError{"unknown analytics service", http.StatusNotFound}
	}

	if !caps.Has(sa.ViewPermission) {
		return "", nil, &authError{"insufficient permissions", http.StatusForbidden}
	}

	return service, caps, nil
}

// writeAuthError writes the appropriate HTTP status from an authError,
// defaulting to 403 for untyped errors.
func writeAuthError(w http.ResponseWriter, err error) {
	if ae, ok := err.(*authError); ok {
		writeError(w, ae.msg, ae.status)
		return
	}
	writeError(w, "forbidden", http.StatusForbidden)
}

func hasMetricPermission(engine *Engine, service, queryType, metric string, caps model.CapabilitySet) bool {
	sa, ok := engine.registry.Get(service)
	if !ok {
		return false
	}

	var perm string
	switch queryType {
	case "timeseries":
		for _, ts := range sa.TimeSeries {
			if ts.Key == metric {
				perm = sa.effectivePermission(ts.Permission)
				break
			}
		}
	case "distribution":
		for _, d := range sa.Distributions {
			if d.Key == metric {
				perm = sa.effectivePermission(d.Permission)
				break
			}
		}
	case "topn":
		for _, t := range sa.TopN {
			if t.Key == metric {
				perm = sa.effectivePermission(t.Permission)
				break
			}
		}
	}

	if perm == "" {
		perm = sa.ViewPermission
	}
	return caps.Has(perm)
}

// filterMetrics removes metrics the user does not have permission to see.
// Metrics not found in the registry are excluded (fail-closed).
func filterMetrics(metrics []Metric, sa *ServiceAnalytics, caps model.CapabilitySet) []Metric {
	if sa == nil {
		return nil
	}

	defMap := make(map[string]string, len(sa.Metrics))
	for _, md := range sa.Metrics {
		defMap[md.Key] = sa.effectivePermission(md.Permission)
	}

	var filtered []Metric
	for _, m := range metrics {
		perm, known := defMap[m.Key]
		if known && caps.Has(perm) {
			filtered = append(filtered, m)
		}
	}
	return filtered
}

// isValidationError checks if an error is a user-input validation error
// (group_by, granularity) vs a backend/DB error.
func isValidationError(err error) bool {
	msg := err.Error()
	return strings.HasPrefix(msg, "invalid group_by") ||
		strings.HasPrefix(msg, "invalid granularity")
}

// --- parsing & response helpers ---

func parseTimeRange(r *http.Request) (TimeRange, error) {
	now := time.Now().UTC()
	tr := TimeRange{
		Start:       now.AddDate(0, 0, -30),
		End:         now,
		Granularity: r.URL.Query().Get("granularity"),
	}

	if s := r.URL.Query().Get("start"); s != "" {
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			return tr, fmt.Errorf("invalid start parameter: expected RFC3339 format")
		}
		tr.Start = t
	}
	if s := r.URL.Query().Get("end"); s != "" {
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			return tr, fmt.Errorf("invalid end parameter: expected RFC3339 format")
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
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// logAndWriteInternalError logs the real error and returns a generic message.
func logAndWriteInternalError(r *http.Request, w http.ResponseWriter, msg string, err error) {
	util.Log(r.Context()).WithError(err).Error(msg)
	writeError(w, "internal server error", http.StatusInternalServerError)
}
