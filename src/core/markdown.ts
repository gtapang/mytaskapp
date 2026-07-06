/**
 * Block-level markdown model for v1. Deliberately simple: enough structure
 * for a calm, readable preview and for task extraction, with no wiki-links,
 * tables, or nesting beyond one list level.
 */

export type MarkdownBlock =
  | { kind: 'heading'; level: number; text: string }
  | { kind: 'paragraph'; text: string }
  | { kind: 'bullet'; text: string }
  | { kind: 'ordered'; number: number; text: string }
  | { kind: 'task'; done: boolean; text: string }
  | { kind: 'quote'; text: string }
  | { kind: 'code'; language?: string; code: string }
  | { kind: 'hr' };

export function parseMarkdown(markdown: string): MarkdownBlock[] {
  const blocks: MarkdownBlock[] = [];
  let paragraph: string[] = [];
  let code: string[] = [];
  let codeLanguage: string | undefined;
  let inCode = false;

  const flushParagraph = () => {
    if (paragraph.length > 0) {
      blocks.push({ kind: 'paragraph', text: paragraph.join(' ') });
      paragraph = [];
    }
  };

  for (const rawLine of markdown.split('\n')) {
    const trimmed = rawLine.trim();

    if (inCode) {
      if (trimmed.startsWith('```')) {
        blocks.push({ kind: 'code', language: codeLanguage, code: code.join('\n') });
        code = [];
        codeLanguage = undefined;
        inCode = false;
      } else {
        code.push(rawLine);
      }
      continue;
    }

    if (trimmed.startsWith('```')) {
      flushParagraph();
      const lang = trimmed.slice(3).trim();
      codeLanguage = lang.length > 0 ? lang : undefined;
      inCode = true;
      continue;
    }

    if (trimmed.length === 0) {
      flushParagraph();
      continue;
    }

    if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
      flushParagraph();
      blocks.push({ kind: 'hr' });
      continue;
    }

    const headingMatch = /^(#{1,6})\s+(.+)$/.exec(trimmed);
    if (headingMatch) {
      flushParagraph();
      blocks.push({ kind: 'heading', level: headingMatch[1].length, text: headingMatch[2].trim() });
      continue;
    }

    const taskMatch = /^- \[([ xX])\]\s+(.+)$/.exec(trimmed);
    if (taskMatch) {
      flushParagraph();
      blocks.push({ kind: 'task', done: taskMatch[1] !== ' ', text: taskMatch[2].trim() });
      continue;
    }

    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      flushParagraph();
      blocks.push({ kind: 'bullet', text: trimmed.slice(2).trim() });
      continue;
    }

    const orderedMatch = /^(\d+)\.\s+(.+)$/.exec(trimmed);
    if (orderedMatch) {
      flushParagraph();
      blocks.push({ kind: 'ordered', number: parseInt(orderedMatch[1], 10), text: orderedMatch[2].trim() });
      continue;
    }

    if (trimmed.startsWith('>')) {
      flushParagraph();
      blocks.push({ kind: 'quote', text: trimmed.slice(1).trim() });
      continue;
    }

    paragraph.push(trimmed);
  }

  if (inCode) {
    // Unterminated fence: keep the content rather than losing it.
    blocks.push({ kind: 'code', language: codeLanguage, code: code.join('\n') });
  }
  flushParagraph();
  return blocks;
}

/** Removes **, __, *, _ and backtick markers for plain-text contexts. */
export function stripInlineMarkers(text: string): string {
  let out = text;
  for (const marker of ['**', '__', '*', '_', '`']) {
    out = out.split(marker).join('');
  }
  return out.trim();
}

/** One-line plain-text preview for list rows. */
export function plainTextPreview(markdown: string, maxLength = 140): string {
  for (const block of parseMarkdown(markdown)) {
    let text: string | undefined;
    switch (block.kind) {
      case 'paragraph':
      case 'bullet':
      case 'quote':
      case 'task':
      case 'heading':
      case 'ordered':
        text = block.text;
        break;
      default:
        continue;
    }
    const stripped = stripInlineMarkers(text);
    if (stripped.length > 0) return stripped.slice(0, maxLength);
  }
  return '';
}

/**
 * Inline spans for rendering: minimal bold / italic / code, everything else
 * plain. Enough for a pleasant preview without a markdown dependency.
 */
export type InlineSpan =
  | { kind: 'text'; text: string }
  | { kind: 'bold'; text: string }
  | { kind: 'italic'; text: string }
  | { kind: 'code'; text: string };

export function parseInline(text: string): InlineSpan[] {
  const spans: InlineSpan[] = [];
  // Order matters: code first (its content is verbatim), then bold, then italic.
  const pattern = /(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(_[^_]+_)/g;
  let last = 0;
  for (let match = pattern.exec(text); match !== null; match = pattern.exec(text)) {
    if (match.index > last) {
      spans.push({ kind: 'text', text: text.slice(last, match.index) });
    }
    const token = match[0];
    if (token.startsWith('`')) {
      spans.push({ kind: 'code', text: token.slice(1, -1) });
    } else if (token.startsWith('**')) {
      spans.push({ kind: 'bold', text: token.slice(2, -2) });
    } else {
      spans.push({ kind: 'italic', text: token.slice(1, -1) });
    }
    last = match.index + token.length;
  }
  if (last < text.length) {
    spans.push({ kind: 'text', text: text.slice(last) });
  }
  return spans;
}
