export type Id = string;
export type Role = 'admin' | 'member';

export interface Member { userId: Id; name: string; role: Role }
export interface Band { id: Id; name: string; members: Member[] }

/** The per-song fields a band can edit. */
export interface EntryFields {
  title: string;
  artist: string;
  bpm: number | null;
  key: string;
  chords: string;
  notes: string;
  link: string;
}

/** One song in one setlist. Arrangement edits live here, not in the shared catalog. */
export interface Entry extends EntryFields {
  id: Id;
  /** Catalog values for the chosen version, kept so the band can reset to them. */
  original?: { bpm: number; key: string; artist: string };
}

export interface Setlist { id: Id; bandId: Id; name: string; entries: Entry[] }

interface ChangeBase {
  id: Id;
  setlistId: Id;
  author: Id;
  /** ISO timestamp from the author's device. Display only: order comes from the server. */
  at: string;
  /** Set when this change restores an earlier one. */
  revertOf?: Id;
}

export type Change = ChangeBase & (
  | { kind: 'add'; entry: Entry; index: number }
  | { kind: 'remove'; entryId: Id; removed: Entry; index: number }
  | { kind: 'move'; entryId: Id; from: number; to: number }
  | { kind: 'edit'; entryId: Id; patch: Partial<EntryFields>; inverse: Partial<EntryFields> }
);
