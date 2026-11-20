import test from 'node:test';
import assert from 'node:assert/strict';
import { createOfflineState, reduceOfflineState } from '../app/offline-state.mjs';

const apply = (state, ...events) => events.reduce(reduceOfflineState, state);

test('online startup stays unknown until an existing Supabase request responds', () => {
  const state = createOfflineState(true);
  assert.equal(state.supabaseReachability, 'unknown');
  assert.equal(state.authenticatedAccess, 'unknown');
  assert.equal(reduceOfflineState(state, { type: 'supabase-response', status: 200 }).supabaseReachability, 'available');
});

test('offline startup distinguishes cached from uncached data without asserting authentication', () => {
  const initial = createOfflineState(false);
  const cached = apply(initial, { type: 'cache-scan', available: true });
  const empty = apply(initial, { type: 'cache-scan', available: false });
  assert.equal(cached.cachedAccess, 'available');
  assert.equal(empty.cachedAccess, 'unavailable');
  assert.equal(cached.authenticatedAccess, 'unknown');
  assert.equal(cached.supabaseReachability, 'unavailable');
});

test('browser online does not imply Supabase availability', () => {
  const state = reduceOfflineState(createOfflineState(false), { type: 'browser-online' });
  assert.equal(state.browserOnline, true);
  assert.equal(state.supabaseReachability, 'unknown');
});

test('Supabase transport failure and server failure are unavailable; HTTP application responses prove reachability', () => {
  const initial = createOfflineState(true);
  assert.equal(reduceOfflineState(initial, { type: 'supabase-failure' }).supabaseReachability, 'unavailable');
  assert.equal(reduceOfflineState(initial, { type: 'supabase-response', status: 503 }).supabaseReachability, 'unavailable');
  assert.equal(reduceOfflineState(initial, { type: 'supabase-response', status: 401 }).supabaseReachability, 'available');
});

test('losing connectivity invalidates current reachability and authentication evidence but keeps cached access', () => {
  const state = apply(createOfflineState(true),
    { type: 'cache-found' }, { type: 'supabase-response', status: 200 }, { type: 'auth-confirmed' },
    { type: 'browser-offline' });
  assert.equal(state.browserOnline, false);
  assert.equal(state.supabaseReachability, 'unavailable');
  assert.equal(state.authenticatedAccess, 'unknown');
  assert.equal(state.cachedAccess, 'available');
});

test('reconnection returns reachability and authentication to unknown until checked again', () => {
  const state = apply(createOfflineState(false), { type: 'cache-found' }, { type: 'browser-online' });
  assert.equal(state.browserOnline, true);
  assert.equal(state.supabaseReachability, 'unknown');
  assert.equal(state.authenticatedAccess, 'unknown');
  assert.equal(state.cachedAccess, 'available');
});

test('cached data does not authenticate a user, while server confirmation does', () => {
  const state = apply(createOfflineState(false), { type: 'cache-found' }, { type: 'browser-online' });
  assert.equal(state.authenticatedAccess, 'unknown');
  assert.equal(reduceOfflineState(state, { type: 'auth-confirmed' }).authenticatedAccess, 'authenticated');
  assert.equal(reduceOfflineState(state, { type: 'auth-rejected' }).authenticatedAccess, 'unauthenticated');
});

test('auth failure does not clear cached access', () => {
  const state = apply(createOfflineState(true), { type: 'cache-found' }, { type: 'auth-rejected' });
  assert.equal(state.authenticatedAccess, 'unauthenticated');
  assert.equal(state.cachedAccess, 'available');
});

test('a previously offline cached user becomes authenticated only after server confirmation', () => {
  const offline = apply(createOfflineState(false), { type: 'cache-found' }, { type: 'browser-online' });
  assert.equal(offline.authenticatedAccess, 'unknown');
  const checked = apply(offline, { type: 'supabase-response', status: 200 }, { type: 'auth-confirmed' });
  assert.equal(checked.supabaseReachability, 'available');
  assert.equal(checked.authenticatedAccess, 'authenticated');
  assert.equal(checked.cachedAccess, 'available');
});

test('late request results cannot restore reachability or authentication after connectivity is lost', () => {
  const offline = apply(createOfflineState(true), { type: 'browser-offline' });
  const late = apply(offline, { type: 'supabase-response', status: 200 }, { type: 'auth-confirmed' });
  assert.equal(late.supabaseReachability, 'unavailable');
  assert.equal(late.authenticatedAccess, 'unknown');
});
