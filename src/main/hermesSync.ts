import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import {
  HermesClient,
  HermesOutbox,
  type OutboxAction,
  type OutboxStorage,
  type TelegramPushPayload,
  type WikiRoutePayload,
} from '../core/hermes';
import { encodeNoteFile } from '../core/noteFileCodec';
import type { HermesStatus } from '../shared/api';
import type { JsonStore } from './store';

class FileOutboxStorage implements OutboxStorage {
  constructor(private readonly filePath: string) {}

  load(): OutboxAction[] {
    try {
      return JSON.parse(fs.readFileSync(this.filePath, 'utf8')) as OutboxAction[];
    } catch {
      return [];
    }
  }

  save(actions: OutboxAction[]): void {
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    const tmp = this.filePath + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(actions), 'utf8');
    fs.renameSync(tmp, this.filePath);
  }
}

/**
 * Owns the Hermes connection: opportunistic sync of important context and
 * Telegram captures into the store, plus the durable offline outbox for
 * writes. Never blocks the UI and never breaks offline use — a failed sync
 * just means Hermes context is stale.
 */
export class HermesSyncService {
  private readonly outbox: HermesOutbox;
  private lastError: string | undefined;
  private syncing = false;

  constructor(
    private readonly store: JsonStore,
    outboxPath: string
  ) {
    this.outbox = new HermesOutbox(new FileOutboxStorage(outboxPath));
  }

  private client(): HermesClient | null {
    const { hermesBaseUrl, hermesToken } = this.store.get().settings;
    if (hermesBaseUrl.length === 0 || hermesToken.length === 0) return null;
    return new HermesClient({ baseUrl: hermesBaseUrl, bearerToken: hermesToken });
  }

  status(): HermesStatus {
    return {
      configured: this.client() !== null,
      lastSyncAt: this.store.get().lastHermesSyncAt,
      lastError: this.lastError,
      pendingOutbox: this.outbox.pendingCount,
    };
  }

  /** Pull important context + Telegram captures, then drain the outbox. */
  async sync(): Promise<HermesStatus> {
    const client = this.client();
    if (!client || this.syncing) return this.status();
    this.syncing = true;
    try {
      const since = this.store.get().lastHermesSyncAt;

      const contextItems = await client.importantContext(since);
      const captures = await client.telegramCaptures(since);
      const nowISO = new Date().toISOString();

      this.store.update((data) => {
        for (const payload of contextItems) {
          const existing = data.hermesContext.find((c) => c.sourceId === payload.id);
          if (existing) {
            existing.title = payload.title;
            existing.summary = payload.summary;
            existing.importance = payload.importance;
            existing.ruleHit = payload.ruleHit;
            existing.occursAt = payload.occursAt;
            existing.fetchedAt = nowISO;
          } else {
            data.hermesContext.push({
              sourceId: payload.id,
              kind: payload.kind,
              title: payload.title,
              summary: payload.summary,
              importance: payload.importance,
              ruleHit: payload.ruleHit,
              sourceMetadata: payload.sourceMetadata ?? {},
              occursAt: payload.occursAt,
              fetchedAt: nowISO,
              dismissed: false,
            });
          }
        }
        for (const capture of captures) {
          // Dedupe repeated syncs by the Telegram capture id.
          if (data.inbox.some((i) => i.sourceId === capture.id)) continue;
          data.inbox.push({
            id: randomUUID(),
            source: 'telegram',
            sourceId: capture.id,
            rawContent: capture.text,
            createdAt: capture.capturedAt,
            processed: false,
            suggestedKind: 'unknown',
          });
        }
        data.lastHermesSyncAt = nowISO;
      });

      await this.outbox.drain(client);
      this.lastError = undefined;
    } catch (error) {
      this.lastError = error instanceof Error ? error.message : String(error);
    } finally {
      this.syncing = false;
    }
    return this.status();
  }

  /** Routes a note into the Hermes markdown wiki workflow (via the outbox). */
  async routeToWiki(noteId: string): Promise<void> {
    const data = this.store.get();
    const note = data.notes.find((n) => n.id === noteId);
    if (!note) return;
    const linkedTaskIds = data.tasks.filter((t) => t.noteId === noteId).map((t) => t.id);
    const payload: WikiRoutePayload = {
      noteID: note.id,
      title: note.title.length > 0 ? note.title : 'Untitled',
      document: encodeNoteFile(note, linkedTaskIds),
      tags: note.tags,
    };
    await this.enqueue('/v1/wiki/route', JSON.stringify(payload));
  }

  /** Pushes a structured response back out through Hermes Telegram (via the outbox). */
  async pushToTelegram(text: string, replyToCaptureID?: string): Promise<void> {
    const payload: TelegramPushPayload = { text, replyToCaptureID };
    await this.enqueue('/v1/telegram/push', JSON.stringify(payload));
  }

  private async enqueue(apiPath: string, body: string): Promise<void> {
    this.outbox.enqueue(apiPath, body, new Date().toISOString(), randomUUID());
    // Opportunistic immediate drain; failures simply wait for the next sync.
    const client = this.client();
    if (client) await this.outbox.drain(client);
  }
}
