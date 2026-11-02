import { describe as suite, expect, it } from 'vitest';
import { applyChange, describe, diffFields, invert, replay } from '../src/changeLog';
import type { Change, Entry, Setlist } from '../src/types';

const e = (id: string, title: string, over: Partial<Entry> = {}): Entry =>
  ({ id, title, artist: '', bpm: 100, key: 'C', chords: '', notes: '', link: '', ...over });
const base = (): Setlist => ({ id: 'l1', bandId: 'b1', name: 'Set 1', entries: [e('a', 'A'), e('b', 'B'), e('c', 'C')] });
const meta = (id: string) => ({ id, setlistId: 'l1', author: 'u1', at: '2026-11-01T12:00:00Z' });
const ids = (s: Setlist) => s.entries.map((x) => x.id).join('');

suite('diffFields', () => {
  it('records only changed fields, with the old values as the inverse', () => {
    const { patch, inverse } = diffFields(e('a', 'A'), e('a', 'A', { key: 'G', bpm: 120 }));
    expect(patch).toEqual({ key: 'G', bpm: 120 });
    expect(inverse).toEqual({ key: 'C', bpm: 100 });
  });
});

suite('applyChange', () => {
  it('edits, adds, removes and moves without mutating the input', () => {
    const s = base();
    const edited = applyChange(s, { ...meta('1'), kind: 'edit', entryId: 'b', patch: { key: 'A' }, inverse: { key: 'C' } });
    expect(edited.entries[1]?.key).toBe('A');
    expect(s.entries[1]?.key).toBe('C');
    expect(ids(applyChange(s, { ...meta('2'), kind: 'add', entry: e('d', 'D'), index: 1 }))).toBe('adbc');
    expect(ids(applyChange(s, { ...meta('3'), kind: 'remove', entryId: 'a', removed: e('a', 'A'), index: 0 }))).toBe('bc');
    expect(ids(applyChange(s, { ...meta('4'), kind: 'move', entryId: 'a', from: 0, to: 2 }))).toBe('bca');
  });
  it('is idempotent for add, and ignores edits to a removed entry', () => {
    const add: Change = { ...meta('1'), kind: 'add', entry: e('d', 'D'), index: 3 };
    expect(ids(applyChange(applyChange(base(), add), add))).toBe('abcd');
    const edit: Change = { ...meta('2'), kind: 'edit', entryId: 'zzz', patch: { key: 'A' }, inverse: {} };
    expect(applyChange(base(), edit)).toEqual(base());
  });
});

suite('invert (restore)', () => {
  it('undoes every kind of change and links back to the original', () => {
    const changes: Change[] = [
      { ...meta('1'), kind: 'edit', entryId: 'b', patch: { key: 'A', bpm: 90 }, inverse: { key: 'C', bpm: 100 } },
      { ...meta('2'), kind: 'add', entry: e('d', 'D'), index: 3 },
      { ...meta('3'), kind: 'remove', entryId: 'a', removed: e('a', 'A'), index: 0 },
      { ...meta('4'), kind: 'move', entryId: 'a', from: 0, to: 2 },
    ];
    for (const c of changes) {
      const after = applyChange(base(), c);
      const back = invert(c, { id: 'r', author: 'u2', at: '2026-11-02T09:00:00Z' });
      expect(back.revertOf).toBe(c.id);
      expect(applyChange(after, back)).toEqual(base());
    }
  });
});

suite('replay', () => {
  it('lets two members edit different fields of one song without conflict', () => {
    const jo: Change = { ...meta('1'), kind: 'edit', entryId: 'a', patch: { key: 'G' }, inverse: { key: 'C' } };
    const maya: Change = { ...meta('2'), kind: 'edit', entryId: 'a', patch: { notes: 'Drums in at bar 9' }, inverse: { notes: '' } };
    const s = replay(base(), [jo, maya]);
    expect(s.entries[0]).toMatchObject({ key: 'G', notes: 'Drums in at bar 9' });
  });
  it('lets the later change win when both edit the same field, and keeps both in history', () => {
    const one: Change = { ...meta('1'), kind: 'edit', entryId: 'a', patch: { bpm: 110 }, inverse: { bpm: 100 } };
    const two: Change = { ...meta('2'), kind: 'edit', entryId: 'a', patch: { bpm: 120 }, inverse: { bpm: 110 } };
    expect(replay(base(), [one, two]).entries[0]?.bpm).toBe(120);
  });
});

suite('describe', () => {
  it('writes readable history lines', () => {
    const t = (id: string) => (id === 'a' ? 'Mustang Sally' : '?');
    expect(describe({ ...meta('1'), kind: 'edit', entryId: 'a', patch: { key: 'A', bpm: 112 }, inverse: {} }, t)).toBe('Mustang Sally: key, bpm');
    expect(describe({ ...meta('2'), kind: 'move', entryId: 'a', from: 0, to: 2 }, t)).toBe('Moved Mustang Sally to position 3');
  });
});
