/**
 * Flashing more than about three times a second can be a seizure risk for some people.
 * Up to 180 BPM every beat may flash. Above that only beat 1 does.
 */
export function flashAllowed(bpm: number, beatIndex: number): boolean {
  return bpm <= 180 || beatIndex === 0;
}

export interface BeatEvent { beat: number; atMs: number }

export interface SchedulerOptions {
  bpm: number;
  beatsPerBar?: number;
  /** How far ahead beats are handed to the audio layer. */
  lookaheadMs?: number;
  now: () => number;
  /** Called with the exact time a click should sound; the audio engine plays it on its own clock. */
  onBeat: (e: BeatEvent) => void;
}

/**
 * Lookahead scheduler. A JS timer wakes up often, but each click is scheduled for an exact time,
 * so timer jitter does not move the beat. Call tick() from setInterval (about every 25 ms).
 */
export class BeatScheduler {
  private bpm: number;
  private beat = 0;
  private next = 0;
  private running = false;
  constructor(private o: SchedulerOptions) { this.bpm = o.bpm; }

  start() { this.running = true; this.beat = 0; this.next = this.o.now(); this.tick(); }
  stop() { this.running = false; }
  setBpm(bpm: number) { this.bpm = Math.max(40, Math.min(240, bpm)); }

  tick() {
    if (!this.running) return;
    const horizon = this.o.now() + (this.o.lookaheadMs ?? 100);
    const per = this.o.beatsPerBar ?? 4;
    while (this.next < horizon) {
      this.o.onBeat({ beat: this.beat, atMs: this.next });
      this.next += 60000 / this.bpm;
      this.beat = (this.beat + 1) % per;
    }
  }
}
