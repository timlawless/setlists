import type { ChartLink } from './types';

const TRACKING = /^(utm_|fbclid$|gclid$|ved$|usg$|opi$|sa$|rct$|esrc$|cad$|uact$)/i;

/**
 * Turns whatever a member pastes into a clean link we are willing to store and open.
 * - Unwraps Google redirect links (google.com/url?...&url=TARGET), which people often copy from search results.
 * - Adds https:// when the scheme is missing and removes common tracking parameters.
 * - Only http and https links are allowed. Anything else (for example javascript:) returns ''.
 */
export function cleanLink(input: string): string {
  const raw = input.trim();
  if (!raw) return '';
  let u: URL;
  try {
    u = new URL(/^[a-z][a-z0-9+.-]*:\/\//i.test(raw) ? raw : `https://${raw}`);
  } catch {
    return '';
  }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') return '';
  const host = u.hostname.replace(/^www\./, '');
  if (/^google\.[a-z.]+$/.test(host) && u.pathname === '/url') {
    const target = u.searchParams.get('url') ?? u.searchParams.get('q');
    if (target) return cleanLink(target);
  }
  for (const k of [...u.searchParams.keys()]) if (TRACKING.test(k)) u.searchParams.delete(k);
  return u.toString();
}

/** A search link used as the starting value until the band pastes a specific page. */
export function searchLink(artist: string, title: string, suffix: string): string {
  return 'https://www.google.com/search?q=' + encodeURIComponent(`${artist} ${title} ${suffix}`.trim());
}

/**
 * Cleans a list of sheet music and tab links: every url goes through cleanLink, unusable ones are dropped,
 * and a missing label becomes the site name.
 */
export function cleanChartLinks(list: ChartLink[]): ChartLink[] {
  const out: ChartLink[] = [];
  for (const c of list) {
    const url = cleanLink(c.url);
    if (!url) continue;
    out.push({ label: c.label.trim() || new URL(url).hostname.replace(/^www\./, ''), url });
  }
  return out;
}
