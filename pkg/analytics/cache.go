package analytics

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"sort"
	"sync"
	"time"
)

// defaultCacheMaxEntries bounds the response cache size; expired entries are
// evicted on insert once the cap is reached.
const defaultCacheMaxEntries = 4096

// cacheKeyTimeBucket is the resolution timestamps are truncated to when
// hashing a request, so that "last 30 days ending now" style requests issued
// in quick succession share a cache entry.
const cacheKeyTimeBucket = time.Minute

// queryCache is a TTL response cache for analytics queries. Uptrace Cloud's
// query API is documented as suitable for occasional use only — this cache is
// the protection that keeps dashboard refreshes from hammering it.
type queryCache struct {
	ttl        time.Duration
	maxEntries int

	mu      sync.Mutex
	entries map[string]queryCacheEntry
}

type queryCacheEntry struct {
	value     any
	expiresAt time.Time
}

func newQueryCache(ttl time.Duration) *queryCache {
	return &queryCache{
		ttl:        ttl,
		maxEntries: defaultCacheMaxEntries,
		entries:    make(map[string]queryCacheEntry),
	}
}

func (c *queryCache) get(key string) (any, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	entry, ok := c.entries[key]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil, false
	}
	return entry.value, true
}

func (c *queryCache) put(key string, value any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.entries) >= c.maxEntries {
		now := time.Now()
		for k, v := range c.entries {
			if now.After(v.expiresAt) {
				delete(c.entries, k)
			}
		}
		if len(c.entries) >= c.maxEntries {
			// Still full of live entries: skip caching rather than grow unbounded.
			return
		}
	}
	c.entries[key] = queryCacheEntry{value: value, expiresAt: time.Now().Add(c.ttl)}
}

// cacheKeyPayload is the canonical request fingerprint that is hashed into a
// cache key: tenancy scope, query kind, the full sanitized query, and the
// time window (bucketed to the minute).
type cacheKeyPayload struct {
	Kind       string            `json:"kind"`
	TenantID   string            `json:"tenant_id"`
	Partitions []string          `json:"partitions"`
	Scoped     bool              `json:"scoped"`
	Query      MetricQuery       `json:"query"`
	Start      int64             `json:"start"`
	End        int64             `json:"end"`
	Extra      map[string]string `json:"extra,omitempty"`
}

// buildCacheKey produces a stable hash for (tenant, partition set, query
// kind, request). Partition order does not affect the key.
func buildCacheKey(kind string, query MetricQuery, filter TenantFilter, tr TimeRange, extra map[string]string) string {
	partitions := make([]string, len(filter.PartitionIDs))
	copy(partitions, filter.PartitionIDs)
	sort.Strings(partitions)

	payload := cacheKeyPayload{
		Kind:       kind,
		TenantID:   filter.TenantID,
		Partitions: partitions,
		Scoped:     filter.Scoped,
		Query:      query,
		Start:      tr.Start.Truncate(cacheKeyTimeBucket).Unix(),
		End:        tr.End.Truncate(cacheKeyTimeBucket).Unix(),
		Extra:      extra,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		// MetricQuery contains only marshalable types; this is unreachable in
		// practice, but fall back to an uncacheable sentinel just in case.
		return ""
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}
