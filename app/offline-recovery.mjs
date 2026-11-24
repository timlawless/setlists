// Keep cached identity separate from server-confirmed authentication.
export function restoreCachedStartup(savedUser, currentUser, { setIdentity, restoreCache, loadQueue, isCurrent }) {
  if (!savedUser?.id || (currentUser?.id && currentUser.id !== savedUser.id)) return false;
  const identity = currentUser || savedUser;
  const provisional = !currentUser;
  setIdentity(identity, provisional);
  restoreCache();
  void Promise.resolve().then(loadQueue).then(() => {
    if (isCurrent(identity.id, provisional)) restoreCache();
  }).catch(() => {});
  return true;
}

export function createSyncFollowupLatch() {
  let requested = false;
  return {
    request() { requested = true; },
    take() { const value = requested; requested = false; return value; }
  };
}

export function createAuthRecovery({
  check,
  isOnline,
  onConfirmed = () => {},
  onRejected = () => {},
  onUnavailable = () => {},
  delayForAttempt = (attempt) => Math.min(300000, 2000 * (2 ** Math.min(attempt - 1, 7))),
  timeoutMs = 1500,
  setTimer = setTimeout,
  clearTimer = clearTimeout
}) {
  let userId = null, generation = 0, attempt = 0, active = null, retryTimer = null;

  function clearRetry() {
    if (retryTimer !== null) clearTimer(retryTimer);
    retryTimer = null;
  }

  function setUser(nextUserId) {
    const next = nextUserId || null;
    if (next === userId) return;
    generation++;
    clearRetry();
    attempt = 0;
    if (active) active.cancel();
    active = null;
    userId = next;
  }

  function scheduleRetry(uid, token) {
    if (retryTimer !== null || uid !== userId || token !== generation || !isOnline()) return;
    attempt++;
    retryTimer = setTimer(() => {
      retryTimer = null;
      void request(uid);
    }, Math.max(0, delayForAttempt(attempt)));
  }

  function request(uid = userId, { force = false } = {}) {
    if (uid !== userId) setUser(uid);
    if (!uid || !isOnline()) return Promise.resolve(false);
    if (active?.uid === uid) return active.promise;
    if (retryTimer !== null && !force) return Promise.resolve(false);
    if (force) clearRetry();

    const token = generation, controller = new AbortController();
    let timeoutId;
    let resolveTimeout;
    const timedOut = new Promise((resolve) => {
      resolveTimeout = resolve;
      timeoutId = setTimer(() => {
        controller.abort();
        resolve({ status: 'unavailable', timeout: true });
      }, timeoutMs);
    });
    const work = Promise.resolve().then(() => check(uid, controller.signal));
    const promise = Promise.race([work, timedOut]).then((result) => {
      if (token !== generation || uid !== userId || !isOnline()) return false;
      if (result?.status === 'authenticated') {
        clearRetry(); attempt = 0; onConfirmed(uid, { immediateSync: true }); return true;
      }
      if (result?.status === 'rejected') {
        clearRetry(); attempt = 0; onRejected(uid, result); return false;
      }
      onUnavailable(uid, result);
      scheduleRetry(uid, token);
      return false;
    }).catch((error) => {
      if (token !== generation || uid !== userId || !isOnline()) return false;
      onUnavailable(uid, { status: 'unavailable', error });
      scheduleRetry(uid, token);
      return false;
    }).finally(() => {
      clearTimer(timeoutId);
      if (active?.promise === promise) active = null;
    });
    active = { uid, controller, timeoutId, promise, cancel() { clearTimer(timeoutId); controller.abort(); resolveTimeout({ status: 'cancelled' }); } };
    return promise;
  }

  function online(uid = userId) {
    if (uid !== userId) setUser(uid);
    if (!uid) return Promise.resolve(false);
    clearRetry();
    attempt = 0;
    return request(uid, { force: true });
  }

  function offline() {
    generation++;
    clearRetry();
    attempt = 0;
    if (active) active.cancel();
    active = null;
  }

  return { setUser, request, online, offline };
}
