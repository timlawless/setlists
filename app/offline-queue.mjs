const DATABASE_NAME = 'setlists-offline-queue';
const DATABASE_VERSION = 1;
const OPERATION_STORE = 'operations';
const METADATA_STORE = 'metadata';
const VALID_STATUSES = new Set(['pending', 'inFlight', 'blocked']);
const VALID_TYPES = new Set(['song', 'songNew', 'songDel', 'slAdd', 'slPos', 'slRemove', 'linkAdd', 'linkDel']);

export class OfflineQueueError extends Error {
  constructor(message, cause) {
    super(message, cause ? { cause } : undefined);
    this.name = 'OfflineQueueError';
  }
}

export function validateOperation(operation, userId) {
  if (!operation || typeof operation !== 'object' || Array.isArray(operation)) throw new OfflineQueueError('Invalid offline operation');
  if (typeof userId !== 'string' || !userId.trim()) throw new OfflineQueueError('A signed-in user is required to queue an operation');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(operation.qid || '')) throw new OfflineQueueError('Operation ID must be a UUID');
  if (!VALID_TYPES.has(operation.t)) throw new OfflineQueueError(`Unsupported offline operation: ${String(operation.t)}`);
  const has = (value) => typeof value === 'string' && value.trim().length > 0;
  const object = (value) => value && typeof value === 'object' && !Array.isArray(value);
  switch (operation.t) {
    case 'song':
      if (!has(operation.sid) || !object(operation.set) || !Object.keys(operation.set).length || !object(operation.base)) throw new OfflineQueueError('Song edits need an ID, changed fields, and base values');
      break;
    case 'songNew':
      if (!object(operation.row) || !has(operation.row.id) || !has(operation.row.band_id)) throw new OfflineQueueError('New songs need their device ID and band ID');
      break;
    case 'slAdd':
      if (!object(operation.row) || !has(operation.row.id) || !has(operation.row.setlist_id) || !has(operation.row.song_id)) throw new OfflineQueueError('Setlist entries need their existing IDs and relationships');
      break;
    case 'linkAdd':
      if (!object(operation.row) || !has(operation.row.id) || !has(operation.row.song_id)) throw new OfflineQueueError('Links need their device ID and song ID');
      break;
    case 'slPos':
      if (!has(operation.id) || !Number.isFinite(operation.position)) throw new OfflineQueueError('Setlist moves need an entry ID and position');
      break;
    case 'slRemove': case 'linkDel':
      if (!has(operation.id)) throw new OfflineQueueError('Delete operations need a row ID');
      break;
    case 'songDel':
      if (!has(operation.sid)) throw new OfflineQueueError('Song deletes need a song ID');
      break;
  }
  return operation;
}

function transactionResult(tx, work) {
  return new Promise((resolve, reject) => {
    let result, failure;
    tx.oncomplete = () => resolve(result);
    tx.onabort = () => reject(new OfflineQueueError('IndexedDB transaction was aborted', failure || tx.error));
    tx.onerror = () => { failure = tx.error || failure; };
    try {
      result = work((error) => { failure = error; try { tx.abort(); } catch {} });
    } catch (error) {
      failure = error;
      try { tx.abort(); } catch { reject(new OfflineQueueError('IndexedDB transaction failed', error)); }
    }
  });
}

export async function openOfflineQueue({ indexedDB = globalThis.indexedDB, name = DATABASE_NAME } = {}) {
  if (!indexedDB?.open) throw new OfflineQueueError('IndexedDB is unavailable in this browser');
  const db = await new Promise((resolve, reject) => {
    let settled = false;
    let request;
    try { request = indexedDB.open(name, DATABASE_VERSION); }
    catch (error) { reject(new OfflineQueueError('Could not open the offline queue database', error)); return; }
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(OPERATION_STORE)) {
        const store = database.createObjectStore(OPERATION_STORE, { keyPath: 'operationId' });
        store.createIndex('byUserSequence', ['userId', 'sequence'], { unique: true });
        store.createIndex('byUserStatusSequence', ['userId', 'status', 'sequence'], { unique: false });
      }
      if (!database.objectStoreNames.contains(METADATA_STORE)) database.createObjectStore(METADATA_STORE, { keyPath: 'key' });
    };
    request.onblocked = () => {
      if (!settled) { settled = true; reject(new OfflineQueueError('Offline queue upgrade is blocked by another open app tab')); }
    };
    request.onerror = () => {
      if (!settled) { settled = true; reject(new OfflineQueueError('Could not open the offline queue database', request.error)); }
    };
    request.onsuccess = () => {
      if (settled) { request.result.close(); return; }
      settled = true;
      request.result.onversionchange = () => request.result.close();
      resolve(request.result);
    };
  });

  return {
    async enqueueMany(operations, userId) {
      if (!Array.isArray(operations) || !operations.length) throw new OfflineQueueError('At least one operation is required');
      operations.forEach((op) => validateOperation(op, userId));
      const seen = new Map(), uniqueOperations = [];
      operations.forEach((op) => {
        const value = JSON.stringify(op);
        if (seen.has(op.qid) && seen.get(op.qid) !== value) throw new OfflineQueueError('A batch contains duplicate operation IDs with different payloads');
        if (!seen.has(op.qid)) uniqueOperations.push(op);
        seen.set(op.qid, value);
      });
      const tx = db.transaction([OPERATION_STORE, METADATA_STORE], 'readwrite');
      return transactionResult(tx, (abort) => {
        const ops = tx.objectStore(OPERATION_STORE), meta = tx.objectStore(METADATA_STORE);
        const rows = new Map();
        let remaining = uniqueOperations.length + 1, nextSequence = 0, finished = false;
        const completeRead = () => {
          if (--remaining || finished) return;
          finished = true;
          try {
            let sequence = nextSequence;
            for (const op of uniqueOperations) {
              const old = rows.get(op.qid);
              if (old) {
                if (old.userId !== userId || JSON.stringify(old.operation) !== JSON.stringify(op)) throw new OfflineQueueError('Operation ID already exists with different data');
                continue;
              }
              sequence += 1;
              ops.put({ operationId: op.qid, userId, sequence, operation: op, status: 'pending', attempts: 0, createdAt: op.at || new Date().toISOString(), error: null });
            }
            meta.put({ key: 'nextSequence', value: sequence });
          } catch (error) { abort(error); }
        };
        const sequenceRequest = meta.get('nextSequence');
        sequenceRequest.onsuccess = () => { nextSequence = sequenceRequest.result?.value || 0; completeRead(); };
        sequenceRequest.onerror = () => abort(sequenceRequest.error || new Error('Could not allocate queue order'));
        uniqueOperations.forEach((op) => {
          const get = ops.get(op.qid);
          get.onsuccess = () => { rows.set(op.qid, get.result || null); completeRead(); };
          get.onerror = () => abort(get.error || new Error('Could not check operation ID'));
        });
        return undefined;
      });
    },
    async list(userId) {
      const tx = db.transaction(OPERATION_STORE, 'readonly');
      return new Promise((resolve, reject) => {
        let rows = [], failure;
        tx.oncomplete = () => resolve(rows.filter((row) => row.userId === userId && VALID_STATUSES.has(row.status)).sort((a, b) => a.sequence - b.sequence));
        tx.onerror = () => { failure = tx.error || failure; };
        tx.onabort = () => reject(new OfflineQueueError('Could not read the offline queue', failure || tx.error));
        const request = tx.objectStore(OPERATION_STORE).getAll();
        request.onsuccess = () => { rows = request.result || []; };
        request.onerror = () => { failure = request.error || failure; try { tx.abort(); } catch {} };
      });
    },
    async setStatus(userId, operationId, status, error = null) {
      if (!VALID_STATUSES.has(status)) throw new OfflineQueueError('Invalid operation status');
      const tx = db.transaction(OPERATION_STORE, 'readwrite');
      return transactionResult(tx, (abort) => {
        const store = tx.objectStore(OPERATION_STORE), get = store.get(operationId);
        get.onsuccess = () => {
          if (!get.result || get.result.userId !== userId) { abort(new OfflineQueueError('Queued operation was not found for this user')); return; }
          store.put({ ...get.result, status, attempts: (get.result.attempts || 0) + (status === 'inFlight' ? 1 : 0), error });
        };
        get.onerror = () => abort(get.error || new Error('Could not update operation status'));
      });
    },
    async remove(userId, operationId) {
      const tx = db.transaction([OPERATION_STORE, METADATA_STORE], 'readwrite');
      return transactionResult(tx, (abort) => {
        const store = tx.objectStore(OPERATION_STORE), meta = tx.objectStore(METADATA_STORE), get = store.get(operationId);
        get.onsuccess = () => {
          if (get.result && get.result.userId !== userId) { abort(new OfflineQueueError('Queued operation belongs to another user')); return; }
          if (get.result) store.delete(operationId);
          meta.put({ key: `resolved:${operationId}`, userId, resolvedAt: new Date().toISOString() });
        };
        get.onerror = () => abort(get.error || new Error('Could not remove acknowledged operation'));
      });
    },
    async acknowledge(userId, operationId) {
      const tx = db.transaction([OPERATION_STORE, METADATA_STORE], 'readwrite');
      return transactionResult(tx, (abort) => {
        const store = tx.objectStore(OPERATION_STORE), meta = tx.objectStore(METADATA_STORE), get = store.get(operationId);
        get.onsuccess = () => {
          if (get.result && get.result.userId !== userId) { abort(new OfflineQueueError('Queued operation belongs to another user')); return; }
          if (get.result) store.delete(operationId);
          meta.put({ key: `ack:${operationId}`, userId, acknowledgedAt: new Date().toISOString() });
        };
        get.onerror = () => abort(get.error || new Error('Could not record operation acknowledgement'));
      });
    },
    async isAcknowledged(userId, operationId) {
      const tx = db.transaction(METADATA_STORE, 'readonly');
      return new Promise((resolve, reject) => {
        let row = null, failure;
        tx.oncomplete = () => resolve(row?.userId === userId);
        tx.onerror = () => { failure = tx.error || failure; };
        tx.onabort = () => reject(new OfflineQueueError('Could not read the operation acknowledgement', failure || tx.error));
        const request = tx.objectStore(METADATA_STORE).get(`ack:${operationId}`);
        request.onsuccess = () => { row = request.result || null; };
        request.onerror = () => { failure = request.error || failure; try { tx.abort(); } catch {} };
      });
    },
    async isResolved(userId, operationId) {
      const tx = db.transaction(METADATA_STORE, 'readonly');
      return new Promise((resolve, reject) => {
        let row = null, failure;
        tx.oncomplete = () => resolve(row?.userId === userId);
        tx.onerror = () => { failure = tx.error || failure; };
        tx.onabort = () => reject(new OfflineQueueError('Could not read the operation resolution', failure || tx.error));
        const request = tx.objectStore(METADATA_STORE).get(`resolved:${operationId}`);
        request.onsuccess = () => { row = request.result || null; };
        request.onerror = () => { failure = request.error || failure; try { tx.abort(); } catch {} };
      });
    },
    close() { db.close(); }
  };
}
