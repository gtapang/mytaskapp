import { describe, expect, it } from 'vitest';
import {
  HermesClient,
  HermesError,
  HermesOutbox,
  type HermesTransport,
  type OutboxAction,
  type OutboxStorage,
} from '../src/core/hermes';

interface Call {
  url: string;
  method: string;
  body?: string;
}

function makeTransport(options: { failures?: number; responseBody?: string } = {}) {
  const calls: Call[] = [];
  let failures = options.failures ?? 0;
  const transport: HermesTransport = async (url, init) => {
    calls.push({ url, method: init.method, body: init.body });
    if (failures > 0) {
      failures -= 1;
      return { status: 503, text: '' };
    }
    return { status: 200, text: options.responseBody ?? '[]' };
  };
  return { transport, calls };
}

const makeClient = (transport: HermesTransport) =>
  new HermesClient({ baseUrl: 'https://hermes.example.com', bearerToken: 'test-token' }, transport);

class MemoryStorage implements OutboxStorage {
  saved: OutboxAction[] = [];
  constructor(private initial: OutboxAction[] = []) {}
  load() {
    return this.initial;
  }
  save(actions: OutboxAction[]) {
    this.saved = JSON.parse(JSON.stringify(actions));
  }
}

describe('HermesClient', () => {
  it('decodes important context', async () => {
    const json = JSON.stringify([
      {
        id: 'e1',
        kind: 'email',
        title: 'Grant deadline',
        summary: 'NSF due Friday',
        importance: 0.92,
        ruleHit: 'vip-sender',
        sourceMetadata: { messageId: 'm-1' },
        occursAt: '2026-07-06T09:00:00Z',
      },
    ]);
    const { transport, calls } = makeTransport({ responseBody: json });
    const items = await makeClient(transport).importantContext('2026-07-05T00:00:00Z');
    expect(items).toHaveLength(1);
    expect(items[0].kind).toBe('email');
    expect(items[0].importance).toBe(0.92);
    expect(calls[0].url).toContain('/v1/context/important?since=');
  });

  it('surfaces HTTP failures as errors', async () => {
    const { transport } = makeTransport({ failures: 1 });
    await expect(makeClient(transport).pushToTelegram({ text: 'hi' })).rejects.toThrow(HermesError);
  });
});

describe('HermesOutbox', () => {
  const now = '2026-07-06T08:00:00.000Z';

  it('drains in order and empties the queue', async () => {
    const outbox = new HermesOutbox(new MemoryStorage());
    outbox.enqueue('/v1/telegram/push', '{"text":"one"}', now, 'a1');
    outbox.enqueue('/v1/wiki/route', '{"text":"two"}', now, 'a2');

    const { transport, calls } = makeTransport();
    const delivered = await outbox.drain(makeClient(transport));
    expect(delivered).toBe(2);
    expect(outbox.pendingCount).toBe(0);
    expect(calls.map((c) => c.url)).toEqual([
      'https://hermes.example.com/v1/telegram/push',
      'https://hermes.example.com/v1/wiki/route',
    ]);
  });

  it('stops at the first failure and retains the action', async () => {
    const outbox = new HermesOutbox(new MemoryStorage());
    outbox.enqueue('/v1/telegram/push', '{"text":"one"}', now, 'a1');
    outbox.enqueue('/v1/telegram/push', '{"text":"two"}', now, 'a2');

    const failing = makeTransport({ failures: 1 });
    const client = makeClient(failing.transport);
    expect(await outbox.drain(client)).toBe(0);
    expect(outbox.pendingCount).toBe(2);
    expect(outbox.pending[0].attempts).toBe(1);

    // Next drain succeeds and flushes both, in order.
    expect(await outbox.drain(client)).toBe(2);
    expect(outbox.pendingCount).toBe(0);
  });

  it('persists through storage and reloads', () => {
    const storage = new MemoryStorage();
    const outbox = new HermesOutbox(storage);
    outbox.enqueue('/v1/wiki/route', '{"keep":"me"}', now, 'a1');
    expect(storage.saved).toHaveLength(1);

    const reloaded = new HermesOutbox(new MemoryStorage(storage.saved));
    expect(reloaded.pendingCount).toBe(1);
    expect(reloaded.pending[0].path).toBe('/v1/wiki/route');
  });

  it('drops a poisoned action after max attempts', async () => {
    const outbox = new HermesOutbox(new MemoryStorage());
    outbox.enqueue('/v1/telegram/push', '{"poison":true}', now, 'a1');

    for (let i = 0; i < HermesOutbox.MAX_ATTEMPTS; i += 1) {
      const failing = makeTransport({ failures: 1 });
      await outbox.drain(makeClient(failing.transport));
    }
    expect(outbox.pendingCount).toBe(0);
  });
});
