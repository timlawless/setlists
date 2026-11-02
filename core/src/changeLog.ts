import type { Change, Entry, EntryFields, Id, Setlist } from './types';

const FIELDS: (keyof EntryFields)[] = ['title', 'artist', 'bpm', 'key', 'chords', 'notes', 'link', 'lyricsLink', 'lyrics', 'charts'];

/** Strict equality for simple values, structural equality for lists such as `charts`. */
const same = (a: unknown, b: unknown) => a === b || JSON.stringify(a) === JSON.stringify(b);

/** Field-level diff. `inverse` holds the old values, so an edit can be restored later. */
export function diffFields(before: EntryFields, after: EntryFields) {
  const patch: Partial<EntryFields> = {};
  const inverse: Partial<EntryFields> = {};
  for (const f of FIELDS) {
    if (!same(before[f], after[f])) {
      (patch as Record<string, unknown>)[f] = after[f];
      (inverse as Record<string, unknown>)[f] = before[f];
    }
  }
  return { patch, inverse };
}

/** Pure: returns a new setlist. Changes to an entry that no longer exists are ignored. */
export function applyChange(setlist: Setlist, c: Change): Setlist {
  const entries = setlist.entries.slice();
  switch (c.kind) {
    case 'add':
      if (entries.some((e) => e.id === c.entry.id)) break; // idempotent
      entries.splice(Math.min(c.index, entries.length), 0, c.entry);
      break;
    case 'remove': {
      const i = entries.findIndex((e) => e.id === c.entryId);
      if (i >= 0) entries.splice(i, 1);
      break;
    }
    case 'move': {
      const i = entries.findIndex((e) => e.id === c.entryId);
      if (i < 0) break;
      const [e] = entries.splice(i, 1);
      entries.splice(Math.min(c.to, entries.length), 0, e as Entry);
      break;
    }
    case 'edit': {
      const i = entries.findIndex((e) => e.id === c.entryId);
      if (i >= 0) entries[i] = { ...(entries[i] as Entry), ...c.patch };
      break;
    }
  }
  return { ...setlist, entries };
}

/** Apply changes in server order. Two members editing different fields never conflict. */
export function replay(base: Setlist, changes: readonly Change[]): Setlist {
  return changes.reduce(applyChange, base);
}

/** Build the change that undoes `c`. Restoring is a new change, so history is never rewritten. */
export function invert(c: Change, meta: { id: Id; author: Id; at: string }): Change {
  const base = { ...meta, setlistId: c.setlistId, revertOf: c.id };
  switch (c.kind) {
    case 'add': return { ...base, kind: 'remove', entryId: c.entry.id, removed: c.entry, index: c.index };
    case 'remove': return { ...base, kind: 'add', entry: c.removed, index: c.index };
    case 'move': return { ...base, kind: 'move', entryId: c.entryId, from: c.to, to: c.from };
    case 'edit': return { ...base, kind: 'edit', entryId: c.entryId, patch: c.inverse, inverse: c.patch };
  }
}

/** Short text for the history list. */
export function describe(c: Change, titleOf: (entryId: Id) => string): string {
  switch (c.kind) {
    case 'add': return `Added ${c.entry.title}`;
    case 'remove': return `Removed ${c.removed.title}`;
    case 'move': return `Moved ${titleOf(c.entryId)} to position ${c.to + 1}`;
    case 'edit': {
      const keys = Object.keys(c.patch) as (keyof EntryFields)[];
      return `${titleOf(c.entryId)}: ${keys.join(', ') || 'no changes'}`;
    }
  }
}
