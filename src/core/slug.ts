/**
 * Filesystem-safe slug for markdown file names: lowercased, alphanumerics
 * kept, everything else collapsed to single hyphens, capped in length so
 * paths stay readable.
 */
export function makeSlug(text: string, maxLength = 60): string {
  let out = '';
  let lastWasHyphen = true; // suppress leading hyphen
  for (const ch of text.toLowerCase()) {
    if (/[a-z0-9]/.test(ch)) {
      out += ch;
      lastWasHyphen = false;
    } else if (!lastWasHyphen) {
      out += '-';
      lastWasHyphen = true;
    }
    if (out.length >= maxLength) break;
  }
  out = out.replace(/-+$/, '');
  return out.length > 0 ? out : 'untitled';
}

/** Short stable suffix from a UUID so slugs never collide. */
export function shortId(id: string): string {
  return id.replace(/-/g, '').slice(0, 8).toLowerCase();
}
