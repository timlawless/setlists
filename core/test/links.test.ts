import { describe, expect, it } from 'vitest';
import { cleanLink, searchLink } from '../src/links';

describe('cleanLink', () => {
  it('unwraps a pasted Google redirect link to the real site', () => {
    const pasted = 'https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwjC8cPb&url=https%3A%2F%2Fwww.ultimate-guitar.com%2F&usg=AOvVaw0mMIwY&opi=89978449';
    expect(cleanLink(pasted)).toBe('https://www.ultimate-guitar.com/');
  });
  it('removes tracking parameters but keeps the ones that matter', () => {
    expect(cleanLink('https://example.com/song?id=7&utm_source=x&fbclid=abc')).toBe('https://example.com/song?id=7');
  });
  it('adds https when the scheme is missing', () => {
    expect(cleanLink('example.com/lyrics')).toBe('https://example.com/lyrics');
  });
  it('rejects anything that is not http or https', () => {
    expect(cleanLink('javascript:alert(1)')).toBe('');
    expect(cleanLink('data:text/html,hi')).toBe('');
    expect(cleanLink('ftp://example.com/x')).toBe('');
  });
  it('returns an empty string for empty or unusable input', () => {
    expect(cleanLink('   ')).toBe('');
    expect(cleanLink('not a link at all')).toBe('');
  });
});

describe('searchLink', () => {
  it('builds an encoded search link', () => {
    expect(searchLink('Aerosmith', 'Walk This Way', 'lyrics')).toBe('https://www.google.com/search?q=Aerosmith%20Walk%20This%20Way%20lyrics');
  });
});

import { cleanChartLinks } from '../src/links';

describe('cleanChartLinks', () => {
  it('cleans each link, fills in a missing label, and drops unusable links', () => {
    const out = cleanChartLinks([
      { label: 'Guitar tab', url: 'https://www.google.com/url?q=https%3A%2F%2Fexample.com%2Ftab&ved=abc' },
      { label: '  ', url: 'example.org/sheet?utm_source=x' },
      { label: 'Bad', url: 'javascript:alert(1)' },
      { label: 'Empty', url: '' },
    ]);
    expect(out).toEqual([
      { label: 'Guitar tab', url: 'https://example.com/tab' },
      { label: 'example.org', url: 'https://example.org/sheet' },
    ]);
  });
});
