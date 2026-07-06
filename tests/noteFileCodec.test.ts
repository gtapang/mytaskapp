import { describe, expect, it } from 'vitest';
import {
  fmArray,
  fmBool,
  fmString,
  parseFrontMatter,
  serializeFrontMatter,
} from '../src/core/frontmatter';
import { decodeNoteFile, encodeNoteFile } from '../src/core/noteFileCodec';
import type { Note } from '../src/core/types';

describe('front matter', () => {
  it('round-trips all value kinds', () => {
    const doc =
      serializeFrontMatter([
        ['title', fmString('Plan: v1, launch [draft]')],
        ['pinned', fmBool(true)],
        ['archived', fmBool(false)],
        ['tags', fmArray(['deep-work', 'ph d', 'a,b'])],
        ['empty', fmArray([])],
      ]) + '\n\nBody text.';

    const { fields, body } = parseFrontMatter(doc);
    expect(body).toBe('Body text.');
    expect(fields?.get('title')).toEqual(fmString('Plan: v1, launch [draft]'));
    expect(fields?.get('pinned')).toEqual(fmBool(true));
    expect(fields?.get('archived')).toEqual(fmBool(false));
    expect(fields?.get('tags')).toEqual(fmArray(['deep-work', 'ph d', 'a,b']));
    expect(fields?.get('empty')).toEqual(fmArray([]));
  });

  it('passes documents without front matter through', () => {
    const { fields, body } = parseFrontMatter('just a note');
    expect(fields).toBeNull();
    expect(body).toBe('just a note');
  });
});

const baseNote: Note = {
  id: '4dbf25c9-2f5c-4a0e-9a15-1de1e0f7f6aa',
  title: 'Meeting notes: Q3 planning',
  markdown: '# Agenda\n\n- budget\n- hiring\n\n- [ ] send recap',
  createdAt: '2026-07-06T08:00:00.000Z',
  updatedAt: '2026-07-06T09:00:00.000Z',
  tags: ['work', 'planning'],
  folder: 'Work',
  notebook: '2026',
  project: 'Roadmap',
  pinned: true,
  archived: false,
  reminderAt: '2026-07-07T08:00:00.000Z',
};

describe('note file codec', () => {
  it('round-trips a full note', () => {
    const encoded = encodeNoteFile(baseNote, ['t1', 't2']);
    const decoded = decodeNoteFile(encoded);
    expect(decoded?.note).toEqual({ ...baseNote, tags: ['planning', 'work'] });
    expect(decoded?.linkedTaskIds).toEqual(['t1', 't2']);
  });

  it('round-trips a minimal note', () => {
    const minimal: Note = {
      id: 'aaaaaaaa-0000-0000-0000-000000000000',
      title: 'Untitled',
      markdown: '',
      createdAt: '2026-07-06T08:00:00.000Z',
      updatedAt: '2026-07-06T08:00:00.000Z',
      tags: [],
      pinned: false,
      archived: false,
    };
    const decoded = decodeNoteFile(encodeNoteFile(minimal));
    expect(decoded?.note).toEqual(minimal);
    expect(decoded?.linkedTaskIds).toEqual([]);
  });

  it('rejects documents without identity', () => {
    expect(decodeNoteFile('---\ntitle: x\n---\n\nbody')).toBeNull();
    expect(decodeNoteFile('plain markdown, no front matter')).toBeNull();
  });
});
