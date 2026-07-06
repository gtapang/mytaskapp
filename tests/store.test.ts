import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { JsonStore } from '../src/main/store';

let dir: string;
let file: string;

beforeEach(() => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hermes-store-'));
  file = path.join(dir, 'data.json');
});

afterEach(() => {
  fs.rmSync(dir, { recursive: true, force: true });
});

describe('JsonStore', () => {
  it('starts empty with default settings', () => {
    const store = new JsonStore(file);
    const data = store.get();
    expect(data.notes).toEqual([]);
    expect(data.settings.mirrorDir).toContain(path.join('Desktop', 'M'));
    expect(data.settings.ollamaUrl).toBe('http://localhost:11434');
  });

  it('persists updates atomically and reloads', () => {
    const store = new JsonStore(file);
    store.update((data) => {
      data.notes.push({
        id: 'n1',
        title: 'Hello',
        markdown: 'World',
        createdAt: '2026-07-06T08:00:00.000Z',
        updatedAt: '2026-07-06T08:00:00.000Z',
        tags: [],
        pinned: false,
        archived: false,
      });
    });

    const reloaded = new JsonStore(file);
    expect(reloaded.get().notes).toHaveLength(1);
    expect(reloaded.get().notes[0].title).toBe('Hello');
    expect(fs.existsSync(file + '.tmp')).toBe(false);
  });

  it('merges older stores field-wise so new settings never break loads', () => {
    fs.writeFileSync(file, JSON.stringify({ notes: [], settings: { hermesBaseUrl: 'https://h' } }));
    const store = new JsonStore(file);
    expect(store.get().settings.hermesBaseUrl).toBe('https://h');
    expect(store.get().settings.ollamaUrl).toBe('http://localhost:11434'); // default filled in
    expect(store.get().tasks).toEqual([]);
  });

  it('survives a corrupt file by starting fresh', () => {
    fs.writeFileSync(file, '{not json');
    const store = new JsonStore(file);
    expect(store.get().notes).toEqual([]);
  });
});
