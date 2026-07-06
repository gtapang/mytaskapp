import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MarkdownMirror } from '../src/core/mirror';
import type { Note } from '../src/core/types';

let root: string;
let mirror: MarkdownMirror;

const makeNote = (overrides: Partial<Note> = {}): Note => ({
  id: 'bbbbbbbb-1111-2222-3333-444444444444',
  title: 'Test note',
  markdown: 'Hello.',
  createdAt: '2026-07-06T08:00:00.000Z',
  updatedAt: '2026-07-06T08:00:00.000Z',
  tags: [],
  pinned: false,
  archived: false,
  ...overrides,
});

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'hermes-mirror-'));
  mirror = new MarkdownMirror(root);
});

afterEach(() => {
  fs.rmSync(root, { recursive: true, force: true });
});

describe('MarkdownMirror', () => {
  it('writes under the notebook group and reads back', () => {
    const note = makeNote({ title: 'Café plans!', notebook: 'Personal' });
    const file = mirror.write(note);
    expect(file).toContain(path.join('Notes', 'Personal'));
    expect(path.basename(file)).toMatch(/^caf-plans-|^cafe-plans-/);
    expect(mirror.readAll()).toEqual([note]);
  });

  it('moves the file when notebook or archive state changes', () => {
    const note = makeNote({ notebook: 'Personal' });
    mirror.write(note);

    const moved = mirror.write({ ...note, notebook: 'Work' });
    expect(moved).toContain(path.join('Notes', 'Work'));
    expect(mirror.readAll()).toHaveLength(1);

    const archived = mirror.write({ ...note, notebook: 'Work', archived: true });
    expect(archived).toContain('Archive');
    expect(mirror.readAll()).toHaveLength(1);
  });

  it('deletes the mirror file', () => {
    const note = makeNote();
    mirror.write(note);
    mirror.delete(note.id);
    expect(mirror.readAll()).toEqual([]);
  });

  it('skips foreign markdown files on readAll', () => {
    mirror.write(makeNote());
    fs.writeFileSync(path.join(root, 'Notes', 'stray.md'), 'no front matter here');
    expect(mirror.readAll()).toHaveLength(1);
  });
});
