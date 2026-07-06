/**
 * Minimal YAML-subset front matter used by the markdown file mirror.
 * Supports exactly what the note codec writes: scalar strings, bools, and
 * inline string arrays (`tags: [a, b]`). Not a general YAML parser; only
 * guaranteed to round-trip its own output, though it stays tolerant of hand
 * edits to values it understands.
 */

export type FrontMatterValue =
  | { kind: 'string'; value: string }
  | { kind: 'bool'; value: boolean }
  | { kind: 'array'; value: string[] };

export const fmString = (value: string): FrontMatterValue => ({ kind: 'string', value });
export const fmBool = (value: boolean): FrontMatterValue => ({ kind: 'bool', value });
export const fmArray = (value: string[]): FrontMatterValue => ({ kind: 'array', value });

export function serializeFrontMatter(fields: Array<[string, FrontMatterValue]>): string {
  const lines = ['---'];
  for (const [key, value] of fields) {
    switch (value.kind) {
      case 'string':
        lines.push(`${key}: ${quoteIfNeeded(value.value)}`);
        break;
      case 'bool':
        lines.push(`${key}: ${value.value}`);
        break;
      case 'array':
        lines.push(`${key}: [${value.value.map(quoteIfNeeded).join(', ')}]`);
        break;
    }
  }
  lines.push('---');
  return lines.join('\n');
}

/**
 * Splits a document into parsed front matter fields and the remaining
 * markdown body. Fields are null if the document has no front matter.
 */
export function parseFrontMatter(document: string): {
  fields: Map<string, FrontMatterValue> | null;
  body: string;
} {
  const lines = document.split('\n');
  if (lines[0] !== '---') return { fields: null, body: document };
  const closeIndex = lines.indexOf('---', 1);
  if (closeIndex === -1) return { fields: null, body: document };

  const fields = new Map<string, FrontMatterValue>();
  for (const line of lines.slice(1, closeIndex)) {
    const colon = line.indexOf(':');
    if (colon <= 0) continue;
    const key = line.slice(0, colon).trim();
    const raw = line.slice(colon + 1).trim();
    if (key.length === 0) continue;
    fields.set(key, parseValue(raw));
  }

  const body = lines
    .slice(closeIndex + 1)
    .join('\n')
    .replace(/^\n+/, '')
    .replace(/\n+$/, '');
  return { fields, body };
}

function parseValue(raw: string): FrontMatterValue {
  if (raw === 'true') return fmBool(true);
  if (raw === 'false') return fmBool(false);
  if (raw.startsWith('[') && raw.endsWith(']')) {
    const inner = raw.slice(1, -1);
    if (inner.trim().length === 0) return fmArray([]);
    return fmArray(splitTopLevel(inner).map((item) => unquote(item.trim())));
  }
  return fmString(unquote(raw));
}

/** Splits on commas while respecting double-quoted segments. */
function splitTopLevel(text: string): string[] {
  const items: string[] = [];
  let current = '';
  let inQuotes = false;
  let previous = '';
  for (const ch of text) {
    if (ch === '"' && previous !== '\\') inQuotes = !inQuotes;
    if (ch === ',' && !inQuotes) {
      items.push(current);
      current = '';
    } else {
      current += ch;
    }
    previous = ch;
  }
  if (current.trim().length > 0 || items.length > 0) items.push(current);
  return items;
}

function quoteIfNeeded(s: string): string {
  const needsQuoting =
    s.length === 0 ||
    /[:,#[\]{}"\n]/.test(s) ||
    s !== s.trim() ||
    s === 'true' ||
    s === 'false';
  if (!needsQuoting) return s;
  const escaped = s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
  return `"${escaped}"`;
}

function unquote(s: string): string {
  if (!(s.startsWith('"') && s.endsWith('"') && s.length >= 2)) return s;
  return s
    .slice(1, -1)
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\');
}
