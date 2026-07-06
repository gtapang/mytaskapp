import * as fs from 'fs';
import * as path from 'path';
import { decodeNoteFile, encodeNoteFile } from './noteFileCodec';
import { makeSlug, shortId } from './slug';
import type { Note } from './types';

/**
 * Write-through markdown mirror of notes under the preferred directory
 * (default `~/Desktop/M/HermesNotes`).
 *
 * Layout: `<root>/Notes/<notebook|folder|"Unfiled">/<slug>-<id8>.md`
 * Archived notes move to `<root>/Archive/`.
 *
 * The JSON store is the operational source of truth; this mirror is the
 * durable, human-readable, Hermes-wiki-aligned representation.
 */
export class MarkdownMirror {
  constructor(public readonly rootDir: string) {}

  filePathFor(note: Note): string {
    const group = note.archived
      ? 'Archive'
      : path.join('Notes', sanitizeGroup(note.notebook ?? note.folder));
    const name = `${makeSlug(note.title.length > 0 ? note.title : 'Untitled')}-${shortId(note.id)}.md`;
    return path.join(this.rootDir, group, name);
  }

  /**
   * Writes (or rewrites) a note's mirror file, moving it if its grouping,
   * title, or archived state changed. Returns the file path written.
   */
  write(note: Note, linkedTaskIds: string[] = []): string {
    const destination = this.filePathFor(note);
    fs.mkdirSync(path.dirname(destination), { recursive: true });

    const existing = this.existingFileFor(note.id);
    if (existing && existing !== destination) {
      try {
        fs.rmSync(existing);
      } catch {
        // best effort — a stray copy is harmless and heals on next write
      }
    }

    const text = encodeNoteFile(note, linkedTaskIds);
    const tmp = destination + '.tmp';
    fs.writeFileSync(tmp, text, 'utf8');
    fs.renameSync(tmp, destination);
    return destination;
  }

  delete(noteId: string): void {
    const existing = this.existingFileFor(noteId);
    if (existing) fs.rmSync(existing);
  }

  /**
   * Reads every note mirror file under the root. Files that fail to decode
   * are skipped (the mirror is tolerant of stray files in the directory).
   */
  readAll(): Note[] {
    if (!fs.existsSync(this.rootDir)) return [];
    const notes: Note[] = [];
    for (const file of this.markdownFiles(this.rootDir)) {
      try {
        const decoded = decodeNoteFile(fs.readFileSync(file, 'utf8'));
        if (decoded) notes.push(decoded.note);
      } catch {
        // skip unreadable files
      }
    }
    return notes;
  }

  private existingFileFor(noteId: string): string | null {
    if (!fs.existsSync(this.rootDir)) return null;
    const suffix = `-${shortId(noteId)}.md`;
    for (const file of this.markdownFiles(this.rootDir)) {
      if (path.basename(file).endsWith(suffix)) return file;
    }
    return null;
  }

  private markdownFiles(root: string): string[] {
    const out: string[] = [];
    const walk = (dir: string) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.isFile() && entry.name.endsWith('.md')) out.push(full);
      }
    };
    walk(root);
    return out;
  }
}

function sanitizeGroup(group: string | undefined): string {
  if (!group || group.length === 0) return 'Unfiled';
  return group.replace(/\//g, '-').replace(/:/g, '-');
}
