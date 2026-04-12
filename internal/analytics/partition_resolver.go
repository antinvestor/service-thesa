package analytics

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/pitabwire/util"

	"github.com/antinvestor/service-thesa/model"
)

const analyticsPermissionPrefix = "analytics:"

// PartitionLister abstracts the tenancy service call that lists child
// partitions. This avoids a direct dependency on the tenancy client.
type PartitionLister interface {
	ListChildPartitions(ctx context.Context, tenantID, partitionID string) ([]string, error)
}

// HierarchicalPartitionResolver resolves the user's current partition plus
// all child partitions they have access to. Results are cached per
// (subject, tenant, partition) tuple with bounded size.
type HierarchicalPartitionResolver struct {
	lister      PartitionLister
	capResolver model.CapabilityResolver
	cacheTTL    time.Duration
	maxEntries  int

	mu    sync.RWMutex
	cache map[string]cachedPartitions
}

type cachedPartitions struct {
	ids       []string
	expiresAt time.Time
}

// NewHierarchicalPartitionResolver creates a resolver that expands the
// partition hierarchy and filters by the user's access.
func NewHierarchicalPartitionResolver(
	lister PartitionLister,
	capResolver model.CapabilityResolver,
	cacheTTL time.Duration,
	maxEntries int,
) *HierarchicalPartitionResolver {
	if maxEntries <= 0 {
		maxEntries = 10000
	}
	return &HierarchicalPartitionResolver{
		lister:      lister,
		capResolver: capResolver,
		cacheTTL:    cacheTTL,
		maxEntries:  maxEntries,
		cache:       make(map[string]cachedPartitions),
	}
}

func (r *HierarchicalPartitionResolver) ResolveAccessiblePartitions(
	ctx context.Context,
	rctx *model.RequestContext,
) ([]string, error) {
	key := cacheKey(rctx)

	r.mu.RLock()
	if cached, ok := r.cache[key]; ok && time.Now().Before(cached.expiresAt) {
		r.mu.RUnlock()
		return cached.ids, nil
	}
	r.mu.RUnlock()

	// Always include the user's own partition.
	accessible := []string{rctx.PartitionID}

	children, err := r.lister.ListChildPartitions(ctx, rctx.TenantID, rctx.PartitionID)
	if err != nil {
		util.Log(ctx).WithError(err).Warn("analytics: failed to list child partitions, falling back to current partition only",
			"tenant_id", rctx.TenantID,
			"partition_id", rctx.PartitionID,
		)
		r.cacheResult(key, accessible)
		return accessible, nil
	}

	for _, childID := range children {
		childRctx := &model.RequestContext{
			SubjectID:   rctx.SubjectID,
			TenantID:    rctx.TenantID,
			PartitionID: childID,
			Roles:       rctx.Roles,
			Token:       rctx.Token,
		}

		caps, err := r.capResolver.Resolve(ctx, childRctx)
		if err != nil {
			continue
		}

		if caps.Has("analytics:*") || hasAnyAnalyticsView(caps) {
			accessible = append(accessible, childID)
		}
	}

	r.cacheResult(key, accessible)
	return accessible, nil
}

// cacheKey produces a collision-free key by quoting each component.
func cacheKey(rctx *model.RequestContext) string {
	return fmt.Sprintf("%q\x00%q\x00%q", rctx.SubjectID, rctx.TenantID, rctx.PartitionID)
}

func (r *HierarchicalPartitionResolver) cacheResult(key string, ids []string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Evict expired entries when cache is full.
	if len(r.cache) >= r.maxEntries {
		now := time.Now()
		for k, v := range r.cache {
			if now.After(v.expiresAt) {
				delete(r.cache, k)
			}
		}
		// If still full after eviction, drop oldest half.
		if len(r.cache) >= r.maxEntries {
			count := 0
			for k := range r.cache {
				delete(r.cache, k)
				count++
				if count >= r.maxEntries/2 {
					break
				}
			}
		}
	}

	r.cache[key] = cachedPartitions{
		ids:       ids,
		expiresAt: time.Now().Add(r.cacheTTL),
	}
}

func hasAnyAnalyticsView(caps model.CapabilitySet) bool {
	for cap := range caps {
		if strings.HasPrefix(cap, analyticsPermissionPrefix) {
			return true
		}
	}
	return false
}
