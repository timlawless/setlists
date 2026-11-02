import { describe, expect, it } from 'vitest';
import { BeatScheduler, flashAllowed, type BeatEvent } from '../src/metronome';

describe('BeatScheduler', () => {
  it('schedules beats exactly 500 ms apart at 120 BPM, with beat 1 first in each bar', () => {
    let now = 1000; const beats: BeatEvent[] = [];
    const s = new BeatScheduler({ bpm: 120, now: () => now, onBeat: (b) => beats.push(b) });
    s.start();
    for (let i = 0; i < 100; i++) { now += 25; s.tick(); }   // 2.5 s of 25 ms timer wake-ups
    expect(beats.slice(0, 6).map((b) => b.atMs)).toEqual([1000, 1500, 2000, 2500, 3000, 3500]);
    expect(beats.slice(0, 6).map((b) => b.beat)).toEqual([0, 1, 2, 3, 0, 1]);
  });
  it('is not thrown off by a late timer wake-up', () => {
    let now = 0; const beats: BeatEvent[] = [];
    const s = new BeatScheduler({ bpm: 120, now: () => now, onBeat: (b) => beats.push(b) });
    s.start(); now = 480; s.tick();      // timer fired 380 ms late
    expect(beats.map((b) => b.atMs)).toEqual([0, 500]);
  });
  it('changes tempo for the next beats and stops when asked', () => {
    let now = 0; const beats: BeatEvent[] = [];
    const s = new BeatScheduler({ bpm: 60, lookaheadMs: 0, now: () => now, onBeat: (b) => beats.push(b) });
    s.start(); s.setBpm(120); now = 1; s.tick(); now = 600; s.tick();
    expect(beats.map((b) => b.atMs)).toEqual([0, 500]);
    s.stop(); now = 5000; s.tick();
    expect(beats.length).toBe(2);
  });
});

describe('flashAllowed', () => {
  it('flashes every beat up to 180 BPM and only beat 1 above that', () => {
    expect([0, 1, 2, 3].map((b) => flashAllowed(180, b))).toEqual([true, true, true, true]);
    expect([0, 1, 2, 3].map((b) => flashAllowed(181, b))).toEqual([true, false, false, false]);
  });
});
