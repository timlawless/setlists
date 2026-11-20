import test from 'node:test';
import assert from 'node:assert/strict';
import { openOfflineQueue, OfflineQueueError } from '../app/offline-queue.mjs';

class FakeRequest {}
class FakeStore {
  constructor(transaction, name) { this.transaction = transaction; this.name = name; }
  createIndex(name, keyPath, options) { this.transaction.db.indexes.get(this.name).push({ name, keyPath, unique: !!options?.unique }); }
  get(key) { return this.transaction.request(() => this.transaction.rows(this.name).get(key)); }
  getAll() { return this.transaction.request(() => [...this.transaction.rows(this.name).values()].map((row) => structuredClone(row))); }
  put(value) {
    return this.transaction.request(() => {
      const db = this.transaction.db;
      if (db.failNextWrite) { db.failNextWrite = false; throw new Error('simulated quota failure'); }
      if (db.failOnWriteNumber) {
        db.writeCount++;
        if (db.writeCount === db.failOnWriteNumber) throw new Error('simulated quota failure during batch');
      }
      const key = value[this.transaction.db.keyPaths.get(this.name)];
      this.transaction.rows(this.name).set(key, structuredClone(value));
      return key;
    });
  }
  delete(key) { return this.transaction.request(() => this.transaction.rows(this.name).delete(key)); }
}
class FakeTransaction {
  constructor(db, names, mode) {
    this.db = db; this.mode = mode; this.pending = 0; this.aborted = false; this.completionScheduled = false;
    this.snapshots = new Map(names.map((name) => [name, new Map([...db.stores.get(name)].map(([key, row]) => [key, structuredClone(row)]))]));
    if (db.abortNextTransaction) { db.abortNextTransaction = false; queueMicrotask(() => this.abort(new Error('simulated transaction abort'))); }
  }
  objectStore(name) { if (!this.snapshots.has(name)) throw new Error(`Store not in transaction: ${name}`); return new FakeStore(this, name); }
  rows(name) { return this.snapshots.get(name); }
  request(run) {
    const req = new FakeRequest(); this.pending++;
    queueMicrotask(() => {
      if (this.aborted) return;
      try { req.result = run(); req.onsuccess?.({ target: req }); }
      catch (error) {
        req.error = error; req.onerror?.({ target: req }); this.onerror?.({ target: this }); this.abort(error);
      }
      finally { this.pending--; this.scheduleCompletion(); }
    });
    return req;
  }
  scheduleCompletion() {
    if (this.pending || this.aborted || this.completionScheduled) return;
    this.completionScheduled = true;
    setTimeout(() => {
      this.completionScheduled = false;
      if (this.pending || this.aborted) return;
      for (const [name, rows] of this.snapshots) this.db.stores.set(name, rows);
      this.oncomplete?.({ target: this });
    }, 0);
  }
  abort(error = new Error('transaction aborted')) {
    if (this.aborted) return;
    this.aborted = true; this.error = error;
    setTimeout(() => this.onabort?.({ target: this }), 0);
  }
}
class FakeDatabase {
  constructor(name) {
    this.name = name; this.stores = new Map(); this.keyPaths = new Map(); this.indexes = new Map(); this.writeCount = 0;
    this.objectStoreNames = { contains: (store) => this.stores.has(store) };
  }
  createObjectStore(name, { keyPath }) { this.stores.set(name, new Map()); this.keyPaths.set(name, keyPath); this.indexes.set(name, []); return new FakeStore({ db: this }, name); }
  transaction(names, mode) { return new FakeTransaction(this, Array.isArray(names) ? names : [names], mode); }
  close() {}
}
class FakeIndexedDB {
  constructor() { this.databases = new Map(); }
  open(name, version) {
    const request = new FakeRequest();
    setTimeout(() => {
      let db = this.databases.get(name);
      if (!db) {
        db = new FakeDatabase(name); this.databases.set(name, db); request.result = db; request.onupgradeneeded?.({ target: request, oldVersion: 0, newVersion: version });
      } else request.result = db;
      request.onsuccess?.({ target: request });
    }, 0);
    return request;
  }
}

const userId = '11111111-1111-4111-8111-111111111111';
const id = (last) => `00000000-0000-4000-8000-${String(last).padStart(12, '0')}`;
const edit = (n, set = { bpm: 120 }) => ({ qid: id(n), t: 'song', sid: id(100), label: 'Song', at: `2026-11-20T00:00:0${n}.000Z`, offline: true, base: { bpm: 100 }, set });

test('opens and initializes the versioned stores and indexes', async () => {
  const indexedDB = new FakeIndexedDB(), queue = await openOfflineQueue({ indexedDB, name: 'open-test' });
  const db = indexedDB.databases.get('open-test');
  assert.ok(db.stores.has('operations'));
  assert.ok(db.stores.has('metadata'));
  assert.equal(db.keyPaths.get('operations'), 'operationId');
  assert.equal(db.keyPaths.get('metadata'), 'key');
  assert.deepEqual(db.indexes.get('operations').map((index) => index.name), ['byUserSequence', 'byUserStatusSequence']);
  queue.close();
});

test('reports IndexedDB open failures clearly', async () => {
  await assert.rejects(openOfflineQueue({ indexedDB: { open() { throw new Error('blocked'); } } }), /Could not open the offline queue database/);
});

test('enqueues individual operations and returns them in FIFO sequence', async () => {
  const indexedDB = new FakeIndexedDB(), queue = await openOfflineQueue({ indexedDB, name: 'fifo-test' });
  await queue.enqueueMany([edit(1), edit(2), edit(3)], userId);
  const rows = await queue.list(userId);
  assert.deepEqual(rows.map((row) => row.operation.qid), [id(1), id(2), id(3)]);
  assert.deepEqual(rows.map((row) => row.sequence), [1, 2, 3]);
  assert.deepEqual(rows.map((row) => row.status), ['pending', 'pending', 'pending']);
});

test('operation IDs are unique and same-payload duplicates are idempotent locally', async () => {
  const queue = await openOfflineQueue({ indexedDB: new FakeIndexedDB(), name: 'duplicate-test' });
  await queue.enqueueMany([edit(1)], userId);
  await queue.enqueueMany([edit(1)], userId);
  await queue.enqueueMany([edit(2), edit(2)], userId);
  assert.equal((await queue.list(userId)).length, 2);
  await assert.rejects(queue.enqueueMany([edit(1, { bpm: 130 })], userId), OfflineQueueError);
  assert.equal((await queue.list(userId)).length, 2);
});

test('batch enqueue is all-or-nothing when a write fails', async () => {
  const indexedDB = new FakeIndexedDB(), queue = await openOfflineQueue({ indexedDB, name: 'batch-test' });
  indexedDB.databases.get('batch-test').failOnWriteNumber = 2;
  await assert.rejects(queue.enqueueMany([edit(1), edit(2)], userId), OfflineQueueError);
  assert.deepEqual(await queue.list(userId), []);
});

test('an aborted transaction leaves no partial batch', async () => {
  const indexedDB = new FakeIndexedDB(), queue = await openOfflineQueue({ indexedDB, name: 'abort-test' });
  indexedDB.databases.get('abort-test').abortNextTransaction = true;
  await assert.rejects(queue.enqueueMany([edit(1), edit(2)], userId), OfflineQueueError);
  assert.deepEqual(await queue.list(userId), []);
});

test('rejects invalid operations without writing them', async () => {
  const queue = await openOfflineQueue({ indexedDB: new FakeIndexedDB(), name: 'invalid-test' });
  await assert.rejects(queue.enqueueMany([{ ...edit(1), t: 'unknown' }], userId), OfflineQueueError);
  await assert.rejects(queue.enqueueMany([{ ...edit(2), set: {} }], userId), OfflineQueueError);
  assert.deepEqual(await queue.list(userId), []);
});

test('preserves the current song, setlist, order, deletion, and link operation payloads', async () => {
  const queue = await openOfflineQueue({ indexedDB: new FakeIndexedDB(), name: 'operation-shapes-test' });
  const operations = [
    { qid: id(1), t: 'songNew', row: { id: id(101), band_id: id(201), title: 'Song', created_by: userId } },
    { qid: id(2), t: 'slAdd', row: { id: id(102), setlist_id: id(202), song_id: id(101), position: 1 } },
    { qid: id(3), t: 'slPos', id: id(102), position: 2 },
    { qid: id(4), t: 'slRemove', id: id(102) },
    { qid: id(5), t: 'linkAdd', row: { id: id(103), song_id: id(101), kind: 'tab', label: 'Tab', url: 'https://example.invalid' } },
    { qid: id(6), t: 'linkDel', id: id(103) },
    { qid: id(7), t: 'songDel', sid: id(101) },
    { ...edit(8), qid: id(8) }
  ].map((op, index) => ({ offline: true, at: `2026-11-20T00:00:0${index}.000Z`, ...op }));
  await queue.enqueueMany(operations, userId);
  assert.deepEqual((await queue.list(userId)).map((row) => row.operation), operations);
});

test('committed operations and payloads survive a fresh queue instance', async () => {
  const indexedDB = new FakeIndexedDB();
  const first = await openOfflineQueue({ indexedDB, name: 'restart-test' });
  const operation = { ...edit(1), base: { bpm: 100, chords: null }, set: { bpm: 120, chords: 'Am D' }, note: 'Offline edit' };
  await first.enqueueMany([operation], userId);
  const second = await openOfflineQueue({ indexedDB, name: 'restart-test' });
  const rows = await second.list(userId);
  assert.equal(rows.length, 1);
  assert.deepEqual(rows[0].operation, operation);
});

test('status can be recovered and acknowledged operations do not remain pending', async () => {
  const queue = await openOfflineQueue({ indexedDB: new FakeIndexedDB(), name: 'status-test' });
  await queue.enqueueMany([edit(1)], userId);
  await queue.setStatus(userId, id(1), 'inFlight');
  assert.equal((await queue.list(userId))[0].status, 'inFlight');
  assert.equal((await queue.list(userId))[0].attempts, 1);
  await queue.acknowledge(userId, id(1));
  assert.deepEqual(await queue.list(userId), []);
  assert.equal(await queue.isAcknowledged(userId, id(1)), true);
  await queue.enqueueMany([edit(2)], userId);
  await queue.remove(userId, id(2));
  assert.equal(await queue.isResolved(userId, id(2)), true);
});
