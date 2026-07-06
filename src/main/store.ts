import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import type { AppData, Settings } from '../core/types';

/**
 * Single-user JSON store: the operational source of truth for app state.
 * Plain file, atomic writes, no native dependencies. The markdown mirror
 * under the preferred directory is the durable human-readable copy.
 */
export class JsonStore {
  private data: AppData;

  constructor(private readonly filePath: string) {
    this.data = load(filePath);
  }

  get(): AppData {
    return this.data;
  }

  update(mutate: (data: AppData) => void): AppData {
    mutate(this.data);
    this.persist();
    return this.data;
  }

  private persist(): void {
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    const tmp = this.filePath + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(this.data, null, 2), 'utf8');
    fs.renameSync(tmp, this.filePath);
  }
}

export function defaultSettings(): Settings {
  return {
    hermesBaseUrl: '',
    hermesToken: '',
    mirrorDir: path.join(os.homedir(), 'Desktop', 'M', 'HermesNotes'),
    ollamaUrl: 'http://localhost:11434',
    ollamaModel: '',
    icsFeeds: [],
  };
}

function emptyData(): AppData {
  return {
    notes: [],
    tasks: [],
    projects: [],
    inbox: [],
    hermesContext: [],
    settings: defaultSettings(),
  };
}

function load(filePath: string): AppData {
  try {
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf8')) as Partial<AppData>;
    const empty = emptyData();
    // Field-wise merge so adding fields never breaks older stores.
    return {
      ...empty,
      ...raw,
      settings: { ...empty.settings, ...(raw.settings ?? {}) },
    };
  } catch {
    return emptyData();
  }
}
