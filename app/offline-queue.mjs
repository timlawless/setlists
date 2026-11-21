const DATABASE_NAME = 'setlists-offline-queue';
const DATABASE_VERSION = 2;
const OPERATION_STORE = 'operations';
const METADATA_STORE = 'metadata';
const ISSUE_STORE = 'issues';
const QUARANTINE_STORE = 'quarantine';
const VALID_STATUSES = new Set(['pending', 'inFlight', 'blocked']);
const VALID_TYPES = new Set(['song', 'songNew', 'songDel', 'slAdd', 'slPos', 'slRemove', 'linkAdd', 'linkDel']);
const VALID_USER_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

function validateStoredOwner(row, idField) {
  if (!row || typeof row !== 'object' || !VALID_USER_ID.test(row.userId || '') || typeof row[idField] !== 'string') {
    throw new OfflineQueueError('Stored queue record has malformed ownership metadata');
  }
}

function transactionResult(tx, work) {
  return new Promise((resolve, reject) => {
    let result, failure;
    tx.oncomplete = () => resolve(result);
    tx.onabort = () => reject(new OfflineQueueError(`IndexedDB transaction failed: ${failure?.message || tx.error?.message || 'aborted'}`, failure || tx.error));
    tx.onerror = () => { failure = failure || tx.error; };
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
      if (!database.objectStoreNames.contains(ISSUE_STORE)) {
        const issues = database.createObjectStore(ISSUE_STORE, { keyPath: 'issueId' });
        issues.createIndex('byUserSequence', ['userId', 'sequence'], { unique: true });
      }
      if (!database.objectStoreNames.contains(QUARANTINE_STORE)) {
        const quarantine = database.createObjectStore(QUARANTINE_STORE, { keyPath: 'quarantineId' });
        quarantine.createIndex('byUserCreated', ['userId', 'createdAt'], { unique: false });
      }
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
    async migrateLegacy(userId, { operations = [], issues = [], malformed = [] } = {}) {
      if (!Array.isArray(operations) || !Array.isArray(issues) || !Array.isArray(malformed)) throw new OfflineQueueError('Legacy queue data must be supplied as arrays');
      const validOperations = [], validIssues = [], invalid = [...malformed];
      for (const [index, operation] of operations.entries()) {
        try { validateOperation(operation, userId); validOperations.push({ operation, index }); }
        catch (error) { invalid.push({ source: 'queue', index, raw: operation, reason: error.message }); }
      }
      for (const [index, issue] of issues.entries()) {
        try { validateOperation(issue, userId); validIssues.push({ issue, index }); }
        catch (error) { invalid.push({ source: 'issues', index, raw: issue, reason: error.message }); }
      }
      const tx = db.transaction([OPERATION_STORE, METADATA_STORE, ISSUE_STORE, QUARANTINE_STORE], 'readwrite');
      let migrationResult;
      await transactionResult(tx, (abort) => {
        const opStore = tx.objectStore(OPERATION_STORE), metaStore = tx.objectStore(METADATA_STORE);
        const issueStore = tx.objectStore(ISSUE_STORE), quarantineStore = tx.objectStore(QUARANTINE_STORE);
        const requests = [opStore.getAll(), metaStore.getAll(), issueStore.getAll(), quarantineStore.getAll()];
        const data = new Array(requests.length); let remaining = requests.length, finished = false;
        const finish = () => {
          if (--remaining || finished) return;
          finished = true;
          try {
            const existingOps = new Map(data[0].map((row) => [row.operationId, row]));
            const metadata = new Map(data[1].map((row) => [row.key, row]));
            const existingIssues = new Map(data[2].map((row) => [row.issueId, row]));
            for (const row of existingOps.values()) validateStoredOwner(row, 'operationId');
            for (const row of existingIssues.values()) validateStoredOwner(row, 'issueId');
            for (const row of data[3]) validateStoredOwner(row, 'quarantineId');
            const existingQuarantine = new Map(data[3].filter((row) => row.userId === userId).map((row) => [row.quarantineId, row]));
            const legacyIssueById = new Map(validIssues.map(({ issue }) => [issue.qid, issue]));
            let sequence = Math.max(metadata.get('nextSequence')?.value || 0, ...[...existingOps.values()].map((row) => row.sequence || 0));
            let issueSequence = Math.max(metadata.get(`issueSequence:${userId}`)?.value || 0, ...[...existingIssues.values()].map((row) => row.sequence || 0));
            const mismatches = [], imported = [], importedIssues = [], quarantined = [], quarantineExpected = new Map();
            const putQuarantine = (source, index, raw, reason, stableId = '') => {
              const quarantineId = `legacy:${userId}:${stableId || `${source}:${index}`}`;
              if (!existingQuarantine.has(quarantineId)) {
                const row = { quarantineId, userId, source, index, raw, reason: String(reason || 'Malformed legacy record'), createdAt: new Date().toISOString() };
                quarantineStore.put(row); existingQuarantine.set(quarantineId, row);
              }
              quarantineExpected.set(quarantineId, raw);
              quarantined.push(quarantineId);
            };
            const canonicalLegacy = new Map();
            for (const item of validOperations) {
              const prior = canonicalLegacy.get(item.operation.qid);
              if (!prior) canonicalLegacy.set(item.operation.qid, item);
              else if (JSON.stringify(prior.operation) !== JSON.stringify(item.operation)) {
                putQuarantine('queue-mismatch', item.index, item.operation, 'Duplicate legacy operation ID has a different payload; first occurrence in the retained FIFO source is authoritative', `legacy-duplicate:${item.operation.qid}:${item.index}`);
                mismatches.push(item.operation.qid);
              }
            }
            const candidates = [];
            for (const { operation, index } of canonicalLegacy.values()) {
              const old = existingOps.get(operation.qid);
              if (old) {
                if (old.userId !== userId) {
                  putQuarantine('queue-mismatch', index, operation, 'Operation ID belongs to a different account; existing IndexedDB record was preserved', `cross-user:${operation.qid}`);
                  mismatches.push(operation.qid);
                } else if (JSON.stringify(old.operation) !== JSON.stringify(operation)) {
                  const mismatchId = `mismatch:${operation.qid}`;
                  putQuarantine('queue-mismatch', index, operation, 'IndexedDB operation is authoritative; legacy payload differs', mismatchId);
                  mismatches.push(operation.qid);
                }
                continue;
              }
              if (metadata.get(`ack:${operation.qid}`)?.userId === userId || metadata.get(`resolved:${operation.qid}`)?.userId === userId) continue;
              const relatedIssue = legacyIssueById.get(operation.qid);
              candidates.push({ operation, index, relatedIssue });
            }
            const validTime = (value) => { const time = Date.parse(value || ''); return Number.isFinite(time) ? time : null; };
            const allRows = [...existingOps.values()].filter((row) => row.userId === userId);
            const legacyRows = candidates.map(({ operation, index, relatedIssue }) => ({ operationId: operation.qid, userId, operation, status: relatedIssue ? 'blocked' : 'pending', attempts: 0, createdAt: operation.at || '', error: relatedIssue ? { fail: relatedIssue.fail, conflicts: relatedIssue.conflicts } : null, _legacyIndex: index, _legacy: true }));
            const nodes = [...allRows.map((row) => ({ ...row, _legacy: false })), ...legacyRows];
            const compareOrder = (a, b) => {
              const ta = validTime(a._legacy ? a.operation.at : a.createdAt), tb = validTime(b._legacy ? b.operation.at : b.createdAt);
              if (ta !== null && tb !== null && ta !== tb) return ta - tb;
              if (ta === null || tb === null) {
                if (a._legacy !== b._legacy) return a._legacy ? -1 : 1; // recoverable fallback: retained legacy FIFO precedes durable-only records
                return a._legacy ? a._legacyIndex - b._legacyIndex : a.sequence - b.sequence;
              }
              if (a._legacy && b._legacy) return a._legacyIndex - b._legacyIndex;
              if (!a._legacy && !b._legacy) return a.sequence - b.sequence;
              return a._legacy ? -1 : 1;
            };
            const predecessors = new Map(nodes.map((row) => [row.operationId, new Set()]));
            let fallbackOrder = 0;
            const sourceOrder = (a, b) => a._legacy === b._legacy && (a._legacy ? a._legacyIndex < b._legacyIndex : a.sequence < b.sequence);
            const creates = (a, b) => {
              const first = a.operation, next = b.operation;
              if (first.t === 'songNew') return (next.t === 'song' && next.sid === first.row.id) || (next.t === 'songDel' && next.sid === first.row.id) || (next.t === 'slAdd' && next.row.song_id === first.row.id) || (next.t === 'linkAdd' && next.row.song_id === first.row.id);
              if (first.t === 'slAdd') return (next.t === 'slPos' || next.t === 'slRemove') && next.id === first.row.id;
              if (first.t === 'linkAdd') return next.t === 'linkDel' && next.id === first.row.id;
              return false;
            };
            for (const a of nodes) for (const b of nodes) if (a !== b && ((sourceOrder(a, b) && !creates(b, a)) || creates(a, b))) predecessors.get(b.operationId).add(a.operationId);
            const ordered = [], emitted = new Set();
            while (ordered.length < nodes.length) {
              const ready = nodes.filter((row) => !emitted.has(row.operationId) && [...predecessors.get(row.operationId)].every((id) => emitted.has(id))).sort(compareOrder);
              if (!ready.length) {
                // Preserve access to every record even if corrupted references form an impossible dependency cycle.
                // Stable source/time order is the deterministic recovery choice; the original sources remain intact.
                fallbackOrder++;
                const remaining = nodes.filter((row) => !emitted.has(row.operationId)).sort(compareOrder);
                for (const row of remaining) { emitted.add(row.operationId); ordered.push(row); }
                break;
              }
              const row = ready[0]; emitted.add(row.operationId); ordered.push(row);
            }
            for (const legacy of legacyRows) for (const durable of allRows) {
              const a = validTime(legacy.operation.at), b = validTime(durable.createdAt);
              if (a === null || b === null || a === b) fallbackOrder++;
            }
            for (const orderedRow of ordered) {
              const sequenceValue = ++sequence;
              if (orderedRow._legacy) { const { _legacyIndex, _legacy, ...storedRow } = orderedRow; storedRow.sequence = sequenceValue; opStore.put(storedRow); imported.push(orderedRow.operationId); }
              else { const { _legacy, ...storedRow } = orderedRow; storedRow.sequence = sequenceValue; opStore.put(storedRow); }
            }
            for (const { issue, index } of validIssues) {
              if (metadata.get(`ack:${issue.qid}`)?.userId === userId || metadata.get(`resolved:${issue.qid}`)?.userId === userId) continue;
              const issueId = issue.qid;
              const old = existingIssues.get(issueId);
              if (old) {
                if (old.userId !== userId) {
                  putQuarantine('issue-mismatch', index, issue, 'Issue ID belongs to a different account; existing IndexedDB record was preserved', `cross-user-issue:${issueId}`);
                  mismatches.push(issueId);
                } else if (JSON.stringify(old.issue) !== JSON.stringify(issue)) {
                  putQuarantine('issue-mismatch', index, issue, 'IndexedDB issue is authoritative; legacy issue differs', `issue-mismatch:${issueId}`);
                  mismatches.push(issueId);
                }
                continue;
              }
              issueSequence += 1;
              const row = { issueId, userId, sequence: issueSequence, issue };
              issueStore.put(row); existingIssues.set(issueId, row); importedIssues.push(issueId);
            }
            for (const item of invalid) putQuarantine(item.source || 'legacy', item.index ?? 0, item.raw, item.reason);
            metaStore.put({ key: 'nextSequence', value: sequence });
            metaStore.put({ key: `issueSequence:${userId}`, value: issueSequence });
            metaStore.put({ key: `legacyMigration:${userId}`, state: 'verifying', updatedAt: new Date().toISOString() });
            migrationResult = { imported, importedIssues, mismatches: [...new Set(mismatches)], quarantined: [...new Set(quarantined)], quarantineExpected: [...quarantineExpected], fallbackOrder };
          } catch (error) { abort(error); }
        };
        requests.forEach((request, index) => {
          request.onsuccess = () => { data[index] = request.result || []; finish(); };
          request.onerror = () => abort(request.error || new Error('Could not read legacy migration state'));
        });
        return undefined;
      });

      const [storedOperations, storedIssues, storedQuarantine] = await Promise.all([
        this.list(userId), this.listIssues(userId), this.listQuarantine(userId)
      ]);
      const opById = new Map(storedOperations.map((row) => [row.operationId, row]));
      const issueById = new Map(storedIssues.map((row) => [row.issueId, row]));
      const quarantineById = new Map(storedQuarantine.map((row) => [row.quarantineId, row]));
      const canonical = new Map();
      for (const { operation } of validOperations) if (!canonical.has(operation.qid)) canonical.set(operation.qid, operation);
      for (const [operationId, operation] of canonical) {
        if (await this.isAcknowledged(userId, operation.qid) || await this.isResolved(userId, operation.qid)) continue;
        const row = opById.get(operation.qid);
        if (!row && migrationResult.mismatches.includes(operation.qid)) continue;
        if (!row || (migrationResult.imported.includes(operation.qid) && JSON.stringify(row.operation) !== JSON.stringify(operation))) throw new OfflineQueueError('Legacy operation verification failed');
      }
      for (const { issue } of validIssues) {
        if (!(await this.isAcknowledged(userId, issue.qid)) && !(await this.isResolved(userId, issue.qid)) && !issueById.has(issue.qid) && !migrationResult.mismatches.includes(issue.qid)) throw new OfflineQueueError('Legacy issue verification failed');
      }
      for (const [id, raw] of migrationResult.quarantineExpected) {
        const stored = quarantineById.get(id);
        if (!stored || JSON.stringify(stored.raw) !== JSON.stringify(raw)) throw new OfflineQueueError('Quarantined record verification failed');
      }
      const markerTx = db.transaction(METADATA_STORE, 'readwrite');
      await transactionResult(markerTx, () => markerTx.objectStore(METADATA_STORE).put({ key: `legacyMigration:${userId}`, state: 'complete', completedAt: new Date().toISOString() }));
      const marker = await this.getMetadata(`legacyMigration:${userId}`);
      if (marker?.state !== 'complete') throw new OfflineQueueError('Legacy migration completion could not be verified');
      return { ...migrationResult, quarantineExpected: undefined, completed: true, operationCount: storedOperations.length, issueCount: storedIssues.length, quarantinedCount: storedQuarantine.length };
    },
    async listIssues(userId) {
      const tx = db.transaction(ISSUE_STORE, 'readonly');
      return new Promise((resolve, reject) => {
        let rows = [], failure;
        tx.oncomplete = () => {
          try {
            for (const row of rows) validateStoredOwner(row, 'issueId');
            const mine = rows.filter((row) => row.userId === userId);
            for (const row of mine) { validateOperation(row.issue, userId); if (row.issueId !== row.issue.qid || !Number.isSafeInteger(row.sequence) || row.sequence < 1) throw new OfflineQueueError('Stored issue metadata is malformed'); }
            resolve(mine.sort((a, b) => a.sequence - b.sequence));
          } catch (error) { reject(new OfflineQueueError('Saved sync issue data is malformed', error)); }
        };
        tx.onerror = () => { failure = tx.error || failure; };
        tx.onabort = () => reject(new OfflineQueueError('Could not read saved sync issues', failure || tx.error));
        const request = tx.objectStore(ISSUE_STORE).getAll();
        request.onsuccess = () => { rows = request.result || []; };
        request.onerror = () => { failure = request.error || failure; try { tx.abort(); } catch {} };
      });
    },
    async listQuarantine(userId) {
      const tx = db.transaction(QUARANTINE_STORE, 'readonly');
      return new Promise((resolve, reject) => {
        let rows = [], failure;
        tx.oncomplete = () => {
          try {
            for (const row of rows) validateStoredOwner(row, 'quarantineId');
            const mine = rows.filter((row) => row.userId === userId);
            for (const row of mine) if (typeof row.quarantineId !== 'string' || typeof row.createdAt !== 'string' || typeof row.reason !== 'string') throw new OfflineQueueError('Quarantine metadata is malformed');
            resolve(mine.sort((a, b) => a.createdAt.localeCompare(b.createdAt)));
          } catch (error) { reject(new OfflineQueueError('Saved quarantine data is malformed', error)); }
        };
        tx.onerror = () => { failure = tx.error || failure; };
        tx.onabort = () => reject(new OfflineQueueError('Could not read quarantined offline records', failure || tx.error));
        const request = tx.objectStore(QUARANTINE_STORE).getAll();
        request.onsuccess = () => { rows = request.result || []; };
        request.onerror = () => { failure = request.error || failure; try { tx.abort(); } catch {} };
      });
    },
    async getMetadata(key) {
      const tx = db.transaction(METADATA_STORE, 'readonly');
      return new Promise((resolve, reject) => {
        let row = null, failure;
        tx.oncomplete = () => resolve(row);
        tx.onerror = () => { failure = tx.error || failure; };
        tx.onabort = () => reject(new OfflineQueueError('Could not read queue migration state', failure || tx.error));
        const request = tx.objectStore(METADATA_STORE).get(key);
        request.onsuccess = () => { row = request.result || null; };
        request.onerror = () => { failure = request.error || failure; try { tx.abort(); } catch {} };
      });
    },
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
        tx.oncomplete = () => {
          try {
            for (const row of rows) validateStoredOwner(row, 'operationId');
            const mine = rows.filter((row) => row.userId === userId);
            for (const row of mine) {
              if (row.operationId !== row.operation?.qid || !Number.isSafeInteger(row.sequence) || row.sequence < 1 || !VALID_STATUSES.has(row.status)) throw new OfflineQueueError('Stored operation metadata is malformed');
              validateOperation(row.operation, userId);
            }
            resolve(mine.sort((a, b) => a.sequence - b.sequence));
          } catch (error) { reject(new OfflineQueueError('Saved operation data is malformed; synchronization is paused', error)); }
        };
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
      const tx = db.transaction([OPERATION_STORE, METADATA_STORE, ISSUE_STORE], 'readwrite');
      return transactionResult(tx, (abort) => {
        const store = tx.objectStore(OPERATION_STORE), meta = tx.objectStore(METADATA_STORE), issueStore = tx.objectStore(ISSUE_STORE), get = store.get(operationId);
        get.onsuccess = () => {
          if (get.result && get.result.userId !== userId) { abort(new OfflineQueueError('Queued operation belongs to another user')); return; }
          if (get.result) store.delete(operationId);
          const issueGet = issueStore.get(operationId);
          issueGet.onsuccess = () => {
            if (issueGet.result && issueGet.result.userId !== userId) { abort(new OfflineQueueError('Saved issue belongs to another user')); return; }
            if (issueGet.result) issueStore.delete(operationId);
            meta.put({ key: `resolved:${operationId}`, userId, resolvedAt: new Date().toISOString() });
          };
          issueGet.onerror = () => abort(issueGet.error || new Error('Could not remove saved issue'));
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
