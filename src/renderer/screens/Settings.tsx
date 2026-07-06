import { useEffect, useState } from 'react';
import type { Settings as SettingsModel } from '../../core/types';
import type { HermesStatus } from '../../shared/api';
import { api, relativeTime, useApp } from '../state';

/** Minimal settings: Hermes connection, mirror folder, local AI, ICS feeds. */
export function SettingsModal({ onClose }: { onClose: () => void }) {
  const { data, refresh } = useApp();
  const [draft, setDraft] = useState<SettingsModel>({ ...data.settings });
  const [status, setStatus] = useState<HermesStatus | null>(null);

  useEffect(() => {
    void api.hermesStatus().then(setStatus);
  }, []);

  const set = <K extends keyof SettingsModel>(key: K, value: SettingsModel[K]) =>
    setDraft((d) => ({ ...d, [key]: value }));

  const save = async () => {
    await api.saveSettings(draft);
    await api.hermesSync();
    await refresh();
    onClose();
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>Settings</h2>

        <div className="section-label" style={{ marginTop: 4 }}>
          Hermes
        </div>
        <div className="form-row">
          <label>Base URL</label>
          <input
            type="url"
            placeholder="https://hermes.example.com"
            value={draft.hermesBaseUrl}
            onChange={(e) => set('hermesBaseUrl', e.target.value.trim())}
          />
        </div>
        <div className="form-row">
          <label>Bearer token</label>
          <input
            type="password"
            value={draft.hermesToken}
            onChange={(e) => set('hermesToken', e.target.value.trim())}
          />
        </div>
        {status && (
          <div className="faint" style={{ marginLeft: 120 }}>
            {status.configured
              ? `${status.lastSyncAt ? `Last sync ${relativeTime(status.lastSyncAt)}.` : 'Not synced yet.'}${
                  status.pendingOutbox > 0 ? ` ${status.pendingOutbox} action(s) queued.` : ''
                }${status.lastError ? ` Last error: ${status.lastError}` : ''}`
              : 'Hermes powers email/calendar importance, Telegram capture, and wiki routing. The app works fully offline without it.'}
          </div>
        )}

        <div className="section-label">Markdown mirror</div>
        <div className="form-row">
          <label>Folder</label>
          <input type="text" value={draft.mirrorDir} onChange={(e) => set('mirrorDir', e.target.value)} />
          <button
            className="quiet"
            onClick={async () => {
              const dir = await api.pickMirrorDir();
              if (dir) set('mirrorDir', dir);
            }}
          >
            Choose…
          </button>
        </div>
        <div className="faint" style={{ marginLeft: 120 }}>
          Notes are mirrored as markdown files with front matter — the local-first, wiki-aligned copy
          of your data (default ~/Desktop/M/HermesNotes).
        </div>

        <div className="section-label">Local AI (Ollama-compatible)</div>
        <div className="form-row">
          <label>Endpoint</label>
          <input
            type="url"
            placeholder="http://localhost:11434"
            value={draft.ollamaUrl}
            onChange={(e) => set('ollamaUrl', e.target.value.trim())}
          />
        </div>
        <div className="form-row">
          <label>Model</label>
          <input
            type="text"
            placeholder="e.g. llama3.2 — empty disables AI assists"
            value={draft.ollamaModel}
            onChange={(e) => set('ollamaModel', e.target.value.trim())}
          />
        </div>
        <div className="faint" style={{ marginLeft: 120 }}>
          Summaries, tag suggestions, task extraction, and inbox classification run against this
          local model. Without one, the app uses honest rule-based fallbacks.
        </div>

        <div className="section-label">Calendar feeds (ICS)</div>
        {[...draft.icsFeeds, ''].map((feed, i) => (
          <div className="form-row" key={i}>
            <label>{i === 0 ? 'Feed URL' : ''}</label>
            <input
              type="url"
              placeholder="https://…/calendar.ics"
              value={feed}
              onChange={(e) => {
                const feeds = [...draft.icsFeeds];
                if (i < feeds.length) {
                  if (e.target.value.trim() === '') feeds.splice(i, 1);
                  else feeds[i] = e.target.value.trim();
                } else if (e.target.value.trim() !== '') {
                  feeds.push(e.target.value.trim());
                }
                set('icsFeeds', feeds);
              }}
            />
          </div>
        ))}

        <div className="row" style={{ marginTop: 16 }}>
          <div className="grow" />
          <button className="quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="primary" onClick={save}>
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
