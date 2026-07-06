import { describe, expect, it } from 'vitest';
import { parseInline, parseMarkdown, plainTextPreview } from '../src/core/markdown';

describe('parseMarkdown', () => {
  it('parses headings, lists, and paragraphs', () => {
    const md = [
      '# Title',
      '',
      'Some intro text',
      'continued on a second line.',
      '',
      '## Section',
      '- first',
      '* second',
      '1. one',
      '2. two',
      '',
      '> a quiet quote',
      '',
      '---',
    ].join('\n');
    expect(parseMarkdown(md)).toEqual([
      { kind: 'heading', level: 1, text: 'Title' },
      { kind: 'paragraph', text: 'Some intro text continued on a second line.' },
      { kind: 'heading', level: 2, text: 'Section' },
      { kind: 'bullet', text: 'first' },
      { kind: 'bullet', text: 'second' },
      { kind: 'ordered', number: 1, text: 'one' },
      { kind: 'ordered', number: 2, text: 'two' },
      { kind: 'quote', text: 'a quiet quote' },
      { kind: 'hr' },
    ]);
  });

  it('parses task items', () => {
    expect(parseMarkdown('- [ ] call the bank\n- [x] send draft')).toEqual([
      { kind: 'task', done: false, text: 'call the bank' },
      { kind: 'task', done: true, text: 'send draft' },
    ]);
  });

  it('parses code fences', () => {
    expect(parseMarkdown('```swift\nlet x = 1\n```')).toEqual([
      { kind: 'code', language: 'swift', code: 'let x = 1' },
    ]);
  });

  it('keeps unterminated code fences', () => {
    expect(parseMarkdown('```\nabc')).toEqual([{ kind: 'code', language: undefined, code: 'abc' }]);
  });

  it('leaves 7-hash lines as paragraphs', () => {
    expect(parseMarkdown('####### seven hashes')).toEqual([
      { kind: 'paragraph', text: '####### seven hashes' },
    ]);
  });
});

describe('plainTextPreview', () => {
  it('strips heading markers and inline styles', () => {
    expect(plainTextPreview('# Big Title\n\nThis is **bold** and `code`.')).toBe('Big Title');
    expect(plainTextPreview('This is **bold** and `code`.')).toBe('This is bold and code.');
  });
});

describe('parseInline', () => {
  it('splits bold, italic, and code spans', () => {
    expect(parseInline('a **b** c `d` e *f*')).toEqual([
      { kind: 'text', text: 'a ' },
      { kind: 'bold', text: 'b' },
      { kind: 'text', text: ' c ' },
      { kind: 'code', text: 'd' },
      { kind: 'text', text: ' e ' },
      { kind: 'italic', text: 'f' },
    ]);
  });

  it('passes plain text through unchanged', () => {
    expect(parseInline('nothing special')).toEqual([{ kind: 'text', text: 'nothing special' }]);
  });
});
