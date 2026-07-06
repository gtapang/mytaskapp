import {
  fmArray,
  fmBool,
  fmString,
  parseFrontMatter,
  serializeFrontMatter,
  type FrontMatterValue,
} from './frontmatter';
import type { Note } from './types';

/**
 * Encodes a Note as a human-readable markdown file with YAML front matter,
 * and decodes it back. This is the on-disk format of the `~/Desktop/M`
 * mirror and the payload format for Hermes wiki routing.
 * `linkedTaskIds` is passed separately because task linkage lives on tasks.
 */
export function encodeNoteFile(note: Note, linkedTaskIds: string[] = []): string {
  const fields: Array<[string, FrontMatterValue]> = [
    ['id', fmString(note.id)],
    ['title', fmString(note.title.length > 0 ? note.title : 'Untitled')],
    ['created', fmString(note.createdAt)],
    ['updated', fmString(note.updatedAt)],
    ['tags', fmArray([...note.tags].sort())],
  ];
  if (note.folder) fields.push(['folder', fmString(note.folder)]);
  if (note.notebook) fields.push(['notebook', fmString(note.notebook)]);
  if (note.project) fields.push(['project', fmString(note.project)]);
  fields.push(['pinned', fmBool(note.pinned)]);
  fields.push(['archived', fmBool(note.archived)]);
  if (linkedTaskIds.length > 0) fields.push(['tasks', fmArray(linkedTaskIds)]);
  if (note.reminderAt) fields.push(['reminder', fmString(note.reminderAt)]);

  return serializeFrontMatter(fields) + '\n\n' + note.markdown + '\n';
}

export interface DecodedNoteFile {
  note: Note;
  linkedTaskIds: string[];
}

export function decodeNoteFile(document: string): DecodedNoteFile | null {
  const { fields, body } = parseFrontMatter(document);
  if (!fields) return null;

  const str = (key: string): string | undefined => {
    const v = fields.get(key);
    return v?.kind === 'string' ? v.value : undefined;
  };
  const bool = (key: string): boolean | undefined => {
    const v = fields.get(key);
    return v?.kind === 'bool' ? v.value : undefined;
  };
  const arr = (key: string): string[] | undefined => {
    const v = fields.get(key);
    return v?.kind === 'array' ? v.value : undefined;
  };

  const id = str('id');
  const title = str('title');
  const created = str('created');
  const updated = str('updated');
  if (!id || title === undefined || !created || !updated) return null;

  const note: Note = {
    id,
    title,
    markdown: body,
    createdAt: created,
    updatedAt: updated,
    tags: arr('tags') ?? [],
    folder: str('folder'),
    notebook: str('notebook'),
    project: str('project'),
    pinned: bool('pinned') ?? false,
    archived: bool('archived') ?? false,
    reminderAt: str('reminder'),
  };
  return { note, linkedTaskIds: arr('tasks') ?? [] };
}
