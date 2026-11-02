import type { Change } from './types';

/** AsyncStorage, MMKV or an expo-sqlite key-value table can all satisfy this. */
export interface KeyValueStore {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
}

/**
 * Changes made while offline wait here, in order, and survive an app restart.
 * The server must treat change ids as idempotency keys, so a retry never double-applies.
 */
export class OfflineQueue {
  constructor(private store: KeyValueStore, private key = 'pending-changes') {}

  async load(): Promise<Change[]> {
    const raw = await this.store.getItem(this.key);
    return raw ? (JSON.parse(raw) as Change[]) : [];
  }

  async enqueue(c: Change): Promise<void> {
    const q = await this.load();
    if (q.some((x) => x.id === c.id)) return;
    await this.store.setItem(this.key, JSON.stringify(q.concat(c)));
  }

  async size(): Promise<number> {
    return (await this.load()).length;
  }

  /** Sends oldest first and stops at the first failure so order is preserved. */
  async flush(send: (c: Change) => Promise<void>): Promise<{ sent: number; remaining: number }> {
    const q = await this.load();
    let sent = 0;
    for (const c of q) {
      try { await send(c); } catch { break; }
      sent++;
      await this.store.setItem(this.key, JSON.stringify(q.slice(sent)));
    }
    return { sent, remaining: q.length - sent };
  }
}
