import { describe, expect, it } from 'vitest';
import { OfflineQueue, type KeyValueStore } from '../src/offlineQueue';
import type { Change } from '../src/types';

const memory = (): KeyValueStore & { data: Map<string, string> } => {
  const data = new Map<string, string>();
  return { data, getItem: async (k) => data.get(k) ?? null, setItem: async (k, v) => void data.set(k, v) };
};
const ch = (id: string): Change => ({ id, setlistId: 'l1', author: 'u1', at: 'now', kind: 'move', entryId: 'a', from: 0, to: 1 });

describe('OfflineQueue', () => {
  it('keeps order, ignores duplicates and survives a restart', async () => {
    const store = memory();
    const q = new OfflineQueue(store);
    await q.enqueue(ch('1')); await q.enqueue(ch('2')); await q.enqueue(ch('1'));
    expect(await q.size()).toBe(2);
    expect(await new OfflineQueue(store).size()).toBe(2);
  });
  it('sends oldest first', async () => {
    const q = new OfflineQueue(memory());
    for (const id of ['1', '2', '3']) await q.enqueue(ch(id));
    const sent: string[] = [];
    expect(await q.flush(async (c) => void sent.push(c.id))).toEqual({ sent: 3, remaining: 0 });
    expect(sent).toEqual(['1', '2', '3']);
  });
  it('stops at the first failure and keeps the rest for the next attempt', async () => {
    const q = new OfflineQueue(memory());
    for (const id of ['1', '2', '3']) await q.enqueue(ch(id));
    const r = await q.flush(async (c) => { if (c.id === '2') throw new Error('offline'); });
    expect(r).toEqual({ sent: 1, remaining: 2 });
    expect((await q.load()).map((c) => c.id)).toEqual(['2', '3']);
  });
});
