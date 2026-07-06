import type { HermesContextKind } from './types';

/**
 * Client + durable offline outbox for the Hermes orchestration API. Hermes
 * remains the higher-order backend: email/calendar importance, Telegram
 * capture and pushback, wiki routing, cross-system workflows. The app never
 * blocks on these calls: reads populate local state when a sync succeeds;
 * writes go through the outbox, which persists actions and drains them with
 * retry whenever the app comes to the foreground or a call succeeds.
 *
 * API contract (v1):
 *   GET  /v1/context/important?since=<iso8601>  → HermesContextPayload[]
 *   GET  /v1/capture/telegram?since=<iso8601>   → TelegramCapturePayload[]
 *   POST /v1/wiki/route     {noteID, title, document, tags}
 *   POST /v1/telegram/push  {text, replyToCaptureID?}
 */

export interface HermesContextPayload {
  id: string;
  kind: HermesContextKind;
  title: string;
  summary: string;
  importance: number;
  ruleHit?: string;
  sourceMetadata?: Record<string, string>;
  occursAt?: string;
}

export interface TelegramCapturePayload {
  id: string;
  text: string;
  capturedAt: string;
}

export interface WikiRoutePayload {
  noteID: string;
  title: string;
  /** Full mirror-format document (front matter + body). */
  document: string;
  tags: string[];
}

export interface TelegramPushPayload {
  text: string;
  replyToCaptureID?: string;
}

export interface HermesConfig {
  baseUrl: string;
  bearerToken: string;
}

/** Transport abstraction so the client is fully testable without a server. */
export type HermesTransport = (
  url: string,
  init: { method: string; headers: Record<string, string>; body?: string }
) => Promise<{ status: number; text: string }>;

export const fetchTransport: HermesTransport = async (url, init) => {
  const response = await fetch(url, init);
  return { status: response.status, text: await response.text() };
};

export class HermesError extends Error {
  constructor(public readonly status: number) {
    super(`Hermes HTTP ${status}`);
  }
}

export class HermesClient {
  constructor(
    private readonly config: HermesConfig,
    private readonly transport: HermesTransport = fetchTransport
  ) {}

  async importantContext(sinceISO?: string): Promise<HermesContextPayload[]> {
    return this.get('/v1/context/important', sinceISO);
  }

  async telegramCaptures(sinceISO?: string): Promise<TelegramCapturePayload[]> {
    return this.get('/v1/capture/telegram', sinceISO);
  }

  async routeToWiki(payload: WikiRoutePayload): Promise<void> {
    await this.post('/v1/wiki/route', JSON.stringify(payload));
  }

  async pushToTelegram(payload: TelegramPushPayload): Promise<void> {
    await this.post('/v1/telegram/push', JSON.stringify(payload));
  }

  /** Generic raw POST used by the outbox to replay persisted actions. */
  async post(path: string, body: string): Promise<void> {
    const { status } = await this.transport(this.url(path), {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.config.bearerToken}`,
        'Content-Type': 'application/json',
      },
      body,
    });
    if (status < 200 || status >= 300) throw new HermesError(status);
  }

  private async get<T>(path: string, sinceISO?: string): Promise<T[]> {
    const query = sinceISO ? `?since=${encodeURIComponent(sinceISO)}` : '';
    const { status, text } = await this.transport(this.url(path) + query, {
      method: 'GET',
      headers: { Authorization: `Bearer ${this.config.bearerToken}` },
    });
    if (status < 200 || status >= 300) throw new HermesError(status);
    return JSON.parse(text) as T[];
  }

  private url(path: string): string {
    return this.config.baseUrl.replace(/\/+$/, '') + path;
  }
}

// ---------------------------------------------------------------------------
// Outbox
// ---------------------------------------------------------------------------

export interface OutboxAction {
  id: string;
  /** API path the action replays against, e.g. "/v1/wiki/route". */
  path: string;
  body: string;
  createdAt: string;
  attempts: number;
}

export interface OutboxStorage {
  load(): OutboxAction[];
  save(actions: OutboxAction[]): void;
}

/**
 * Durable FIFO queue for Hermes writes. Enqueue is always local and instant;
 * `drain` is called opportunistically and stops at the first failure so
 * ordering is preserved and offline periods cost nothing. A poisoned action
 * is dropped after MAX_ATTEMPTS so it can never block the queue forever.
 */
export class HermesOutbox {
  static readonly MAX_ATTEMPTS = 8;

  private actions: OutboxAction[];

  constructor(private readonly storage: OutboxStorage) {
    this.actions = storage.load();
  }

  get pendingCount(): number {
    return this.actions.length;
  }

  get pending(): readonly OutboxAction[] {
    return this.actions;
  }

  enqueue(path: string, body: string, nowISO: string, id: string): void {
    this.actions.push({ id, path, body, createdAt: nowISO, attempts: 0 });
    this.storage.save(this.actions);
  }

  /** Replays pending actions in order. Returns the number delivered. */
  async drain(client: HermesClient): Promise<number> {
    let delivered = 0;
    while (this.actions.length > 0) {
      const next = this.actions[0];
      try {
        await client.post(next.path, next.body);
        this.actions.shift();
        delivered += 1;
      } catch {
        next.attempts += 1;
        if (next.attempts >= HermesOutbox.MAX_ATTEMPTS) {
          this.actions.shift();
        }
        break;
      }
    }
    this.storage.save(this.actions);
    return delivered;
  }
}
