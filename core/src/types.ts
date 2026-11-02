export type Id = string;
export type Role = 'admin' | 'member';

export interface Member { userId: Id; name: string; role: Role }
export interface Band { id: Id; name: string; members: Member[] }

/** A labelled link to sheet music or a tab, added by a band member. */
export interface ChartLink { label: string; url: string }

/** The per-song fields a band can edit. */
export interface EntryFields {
  title: string;
  artist: string;
  bpm: number | null;
  key: string;
  chords: string;
  notes: string;
  /** Video link, for example a YouTube video of the version the band is learning. */
  link: string;
  /** Link to a lyrics or chords site the band already uses. Stored as a clean http(s) URL. */
  lyricsLink: string;
  /** Optional text the band types or pastes in for its own use (lyrics, cues). Never supplied by the app. */
  lyrics: string;
  /** Any number of links to sheet music or tabs. Each url is a clean http(s) link. */
  charts: ChartLink[];
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
