/**
 * Per-instance in-memory cache for the public HTTP endpoints.
 *
 * Their `Cache-Control: s-maxage` is never honoured: nothing routes them
 * through Firebase Hosting, and direct `cloudfunctions.net` responses are not
 * CDN-cached. So each warm instance keeps its own copy for the same TTL the
 * header advertises, which bounds the Firestore reads / upstream fetches a
 * flood of identical requests can cause (with `maxInstances` capping the
 * number of instances). Entries are capped so caller-chosen keys (a free-text
 * `branch` param) cannot grow memory without bound: the oldest entry is
 * evicted first.
 */
export class TtlCache<V> {
  private readonly entries = new Map<string, { value: V; expiresAt: number }>();

  constructor(
    private readonly maxEntries: number,
    private readonly now: () => number = Date.now,
  ) {}

  get(key: string): V | undefined {
    const entry = this.entries.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= this.now()) {
      this.entries.delete(key);
      return undefined;
    }
    return entry.value;
  }

  set(key: string, value: V, ttlMs: number): void {
    this.entries.delete(key);
    if (this.entries.size >= this.maxEntries) {
      const oldest = this.entries.keys().next();
      if (!oldest.done) this.entries.delete(oldest.value);
    }
    this.entries.set(key, { value, expiresAt: this.now() + ttlMs });
  }

  /** The cached value for [key], or [load]'s result cached for [ttlMs]. */
  async getOrLoad(key: string, ttlMs: number, load: () => Promise<V>): Promise<V> {
    const hit = this.get(key);
    if (hit !== undefined) return hit;
    const value = await load();
    this.set(key, value, ttlMs);
    return value;
  }
}

/** Instance cap for the unauthenticated HTTP endpoints (default would be 100). */
export const PUBLIC_MAX_INSTANCES = 10;
