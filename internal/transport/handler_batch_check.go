package transport

import (
	"encoding/json"
	"net/http"

	"github.com/antinvestor/service-thesa/model"
)

// batchCheckRequest is the request body for POST /ui/capabilities/batch-check.
type batchCheckRequest struct {
	Checks []batchCheckItem `json:"checks"`
}

type batchCheckItem struct {
	Namespace   string   `json:"namespace"`
	Permissions []string `json:"permissions"`
}

// batchCheckResponse is the response for batch permission checks.
type batchCheckResponse struct {
	Granted []string `json:"granted"`
}

// handleBatchCheck performs a batch permission check against the capability resolver.
// It resolves the user's full capability set once, then filters to only the
// requested permissions that are granted.
//
// POST /ui/capabilities/batch-check
// Request:  { "checks": [{ "namespace": "service_profile", "permissions": ["profile_view", ...] }] }
// Response: { "granted": ["profile_view", "profile_create", ...] }
func handleBatchCheck(capResolver model.CapabilityResolver) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		rctx := model.RequestContextFrom(r.Context())
		if rctx == nil {
			WriteError(w, model.NewUnauthorizedError("missing request context"))
			return
		}

		var req batchCheckRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, model.NewBadRequestError("invalid request body: "+err.Error()))
			return
		}

		// Resolve all capabilities for the user once.
		caps, err := capResolver.Resolve(r.Context(), rctx)
		if err != nil {
			WriteError(w, err)
			return
		}

		// Filter to only requested permissions that are granted.
		granted := make([]string, 0, 64)
		for _, check := range req.Checks {
			for _, perm := range check.Permissions {
				// Check both the bare permission key and the namespaced form.
				if caps.Has(perm) || caps.Has(check.Namespace+":"+perm) {
					granted = append(granted, perm)
				}
			}
		}

		WriteJSON(w, http.StatusOK, batchCheckResponse{Granted: granted})
	}
}
