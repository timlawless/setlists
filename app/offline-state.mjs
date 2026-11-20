// Track independent evidence about connectivity, cached data and server authentication.
export function createOfflineState(browserOnline = true) {
  const online = Boolean(browserOnline);
  return {
    browserOnline: online,
    supabaseReachability: online ? 'unknown' : 'unavailable',
    cachedAccess: 'unknown',
    authenticatedAccess: 'unknown'
  };
}

export function reduceOfflineState(state, event) {
  switch (event.type) {
    case 'browser-online':
      return { ...state, browserOnline: true, supabaseReachability: 'unknown', authenticatedAccess: 'unknown' };
    case 'browser-offline':
      return { ...state, browserOnline: false, supabaseReachability: 'unavailable', authenticatedAccess: 'unknown' };
    case 'supabase-response':
      return { ...state, supabaseReachability: !state.browserOnline || event.status >= 500 ? 'unavailable' : 'available' };
    case 'supabase-failure':
      return { ...state, supabaseReachability: 'unavailable' };
    case 'cache-scan':
      return { ...state, cachedAccess: event.available ? 'available' : 'unavailable' };
    case 'cache-found':
      return { ...state, cachedAccess: 'available' };
    case 'auth-confirmed':
      return { ...state, authenticatedAccess: state.browserOnline ? 'authenticated' : 'unknown' };
    case 'auth-rejected':
      return { ...state, authenticatedAccess: 'unauthenticated' };
    case 'auth-unknown':
      return { ...state, authenticatedAccess: 'unknown' };
    default:
      return state;
  }
}
