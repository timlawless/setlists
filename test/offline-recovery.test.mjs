import assert from 'node:assert/strict';
import test from 'node:test';
import { createAuthRecovery, createSyncFollowupLatch, restoreCachedStartup } from '../app/offline-recovery.mjs';

const user = { id: 'user-a', email: 'member@example.test' };

function fakeTimers() {
  let nextId = 1;
  const tasks = new Map();
  return {
    setTimer(fn, delay) { const id = nextId++; tasks.set(id, { fn, delay }); return id; },
    clearTimer(id) { tasks.delete(id); },
    async runNext() {
      const [id, task] = [...tasks.entries()].sort((a, b) => a[1].delay - b[1].delay)[0] || [];
      if (!task) return false;
      tasks.delete(id); task.fn();
      for (let i = 0; i < 10; i++) await Promise.resolve();
      return true;
    },
    pending() { return [...tasks.values()].map((task) => task.delay); }
  };
}

test('cached startup is restored synchronously before queued metadata finishes loading', async () => {
  let current = null, provisional = false, releaseQueue;
  const events = [];
  const queueWait = new Promise((resolve) => { releaseQueue = resolve; });
  const restored = restoreCachedStartup(user, current, {
    setIdentity(identity, isProvisional) { current = identity; provisional = isProvisional; events.push('identity'); },
    restoreCache() { events.push('cache'); },
    loadQueue: () => queueWait,
    isCurrent: (uid, isProvisional) => current?.id === uid && provisional === isProvisional
  });
  assert.equal(restored, true);
  assert.deepEqual(events, ['identity', 'cache']);
  assert.equal(provisional, true);
  releaseQueue(); for (let i = 0; i < 10; i++) await Promise.resolve();
  assert.deepEqual(events, ['identity', 'cache', 'cache']);
});

test('cached startup never replaces a different current account identity', () => {
  const other = { id: 'user-b' };
  let set = false;
  assert.equal(restoreCachedStartup(user, other, {
    setIdentity() { set = true; }, restoreCache() {}, loadQueue() {}, isCurrent() { return true; }
  }), false);
  assert.equal(set, false);
});

test('offline startup makes no authentication request and reconnect starts one immediately', async () => {
  let online = false, checks = 0, confirmed = 0, syncRequests = 0;
  const recovery = createAuthRecovery({
    isOnline: () => online,
    check: async () => { checks++; return { status: 'authenticated' }; },
    onConfirmed: (_uid, request) => { confirmed++; if (request.immediateSync) syncRequests++; }
  });
  recovery.setUser(user.id);
  assert.equal(await recovery.request(), false);
  assert.equal(checks, 0);
  online = true;
  assert.equal(await recovery.online(user.id), true);
  assert.equal(checks, 1);
  assert.equal(confirmed, 1);
  assert.equal(syncRequests, 1);
});

test('a hung authentication check is aborted at its deadline and retried with backoff', async () => {
  const timers = fakeTimers(); let calls = 0, aborted = 0, confirmed = 0;
  const recovery = createAuthRecovery({
    isOnline: () => true,
    timeoutMs: 1200,
    delayForAttempt: (attempt) => attempt === 1 ? 2000 : 4000,
    setTimer: timers.setTimer,
    clearTimer: timers.clearTimer,
    check: (_uid, signal) => {
      calls++;
      if (calls > 1) return Promise.resolve({ status: 'authenticated' });
      return new Promise(() => signal.addEventListener('abort', () => { aborted++; }, { once: true }));
    },
    onConfirmed: () => confirmed++
  });
  recovery.setUser(user.id);
  const firstAttempt = recovery.request();
  await Promise.resolve();
  await timers.runNext();
  await firstAttempt;
  assert.equal(calls, 1);
  assert.equal(aborted, 1);
  assert.deepEqual(timers.pending(), [2000]);
  await timers.runNext();
  await Promise.resolve();
  assert.equal(calls, 2);
  assert.equal(confirmed, 1);
});

test('temporary auth failures retry at capped intervals and definitive rejection stops retries', async () => {
  const timers = fakeTimers(); let calls = 0, rejected = 0;
  const recovery = createAuthRecovery({
    isOnline: () => true,
    delayForAttempt: (attempt) => Math.min(8000, attempt * 3000),
    setTimer: timers.setTimer,
    clearTimer: timers.clearTimer,
    check: async () => { calls++; return calls < 4 ? { status: 'unavailable' } : { status: 'rejected' }; },
    onRejected: () => rejected++
  });
  recovery.setUser(user.id);
  await recovery.request();
  assert.deepEqual(timers.pending(), [3000]);
  await timers.runNext(); await Promise.resolve();
  assert.deepEqual(timers.pending(), [6000]);
  await timers.runNext(); await Promise.resolve();
  assert.deepEqual(timers.pending(), [8000]);
  await timers.runNext(); await Promise.resolve(); await Promise.resolve();
  assert.equal(calls, 4);
  assert.equal(rejected, 1);
  assert.deepEqual(timers.pending(), []);
});

test('offline transition cancels retries and invalidates late auth results', async () => {
  const timers = fakeTimers(); let online = true, resolveCheck, confirmed = 0;
  const recovery = createAuthRecovery({
    isOnline: () => online,
    setTimer: timers.setTimer,
    clearTimer: timers.clearTimer,
    check: () => new Promise((resolve) => { resolveCheck = resolve; }),
    onConfirmed: () => confirmed++
  });
  recovery.setUser(user.id);
  const request = recovery.request();
  await Promise.resolve();
  online = false; recovery.offline();
  resolveCheck({ status: 'authenticated' });
  assert.equal(await request, false);
  assert.equal(confirmed, 0);
  assert.deepEqual(timers.pending(), []);
});

test('overlapping auth requests share one check; an online event after sync work can request an immediate attempt', async () => {
  let calls = 0, release;
  const recovery = createAuthRecovery({
    isOnline: () => true,
    check: () => { calls++; return new Promise((resolve) => { release = resolve; }); }
  });
  recovery.setUser(user.id);
  const first = recovery.request();
  const second = recovery.online(user.id);
  await Promise.resolve();
  assert.equal(calls, 1);
  release({ status: 'authenticated' });
  assert.equal(await first, true);
  assert.equal(await second, true);
  assert.equal(calls, 1);
});

test('reconnect requests during an active sync coalesce into one follow-up attempt', () => {
  const followup = createSyncFollowupLatch();
  assert.equal(followup.take(), false);
  followup.request(); followup.request(); followup.request();
  assert.equal(followup.take(), true);
  assert.equal(followup.take(), false);
});
