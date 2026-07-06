import { dayStartPrompt, fallbackSummary, type DayStartDigest } from '../core/dayStart';
import { parseMarkdown, plainTextPreview } from '../core/markdown';
import type { Settings, SuggestedItemKind, TaskPriority } from '../core/types';
import type { ExtractedTaskSuggestion } from '../shared/api';

/**
 * Local intelligence layer. Cross-platform replacement for the original
 * Apple Foundation Models integration: an Ollama-compatible endpoint
 * (configurable in Settings) handles summarization, tag suggestion, task
 * extraction, inbox classification, and the day-start briefing. Everything
 * degrades to honest rule-based fallbacks when no model is configured —
 * the app never fabricates intelligence. Hermes remains the separate,
 * higher-order orchestration layer.
 */
export class Intelligence {
  constructor(private readonly settings: () => Settings) {}

  available(): boolean {
    const s = this.settings();
    return s.ollamaUrl.length > 0 && s.ollamaModel.length > 0;
  }

  async summarize(text: string): Promise<string> {
    const result = await this.chatJSON<{ summary: string }>(
      'You summarize personal notes. Be brief, factual, and calm. Never invent content. Respond as JSON: {"summary": "1-2 sentence summary"}',
      `Summarize this note:\n\n${text}`
    );
    return result?.summary ?? plainTextPreview(text, 200);
  }

  async suggestTags(text: string, existing: string[]): Promise<string[]> {
    const result = await this.chatJSON<{ tags: string[] }>(
      'You suggest organizational tags for personal notes. Tags are short, lowercase, reusable. Prefer existing tags when they fit. Respond as JSON: {"tags": ["...", ...]} with at most 4 tags.',
      `Existing tags: ${existing.length > 0 ? existing.join(', ') : 'none yet'}\n\nSuggest tags for this note:\n\n${text}`
    );
    if (!Array.isArray(result?.tags)) return [];
    return result.tags
      .filter((t): t is string => typeof t === 'string')
      .map((t) => t.toLowerCase().trim())
      .filter((t) => t.length > 0)
      .slice(0, 4);
  }

  async extractTasks(text: string): Promise<ExtractedTaskSuggestion[]> {
    const result = await this.chatJSON<{
      tasks: Array<{ title?: string; priority?: string; dueHint?: string }>;
    }>(
      'You extract actionable tasks from personal notes. Only extract real actions; never pad the list. Respond as JSON: {"tasks": [{"title": "imperative, under 12 words", "priority": "none|low|medium|high", "dueHint": "verbatim due hint or omit"}]}',
      `Extract tasks from this note:\n\n${text}`
    );
    if (Array.isArray(result?.tasks)) {
      return result.tasks
        .filter((t) => typeof t.title === 'string' && t.title.length > 0)
        .map((t) => ({
          title: t.title as string,
          priority: (['none', 'low', 'medium', 'high'] as TaskPriority[]).includes(
            t.priority as TaskPriority
          )
            ? (t.priority as TaskPriority)
            : 'none',
          dueHint: typeof t.dueHint === 'string' ? t.dueHint : undefined,
        }));
    }
    // Fallback: unchecked markdown task items are extractable without any model.
    return parseMarkdown(text)
      .filter((b): b is { kind: 'task'; done: boolean; text: string } => b.kind === 'task' && !b.done)
      .map((b) => ({ title: b.text, priority: 'none' as TaskPriority }));
  }

  async classify(text: string): Promise<SuggestedItemKind> {
    const result = await this.chatJSON<{ kind: string }>(
      "You classify quick captures for an inbox. A 'task' is actionable; a 'note' is a thought worth keeping; 'reference' is a link or fact; 'note_and_task' is both. Respond as JSON: {\"kind\": \"note|task|note_and_task|reference\"}",
      `Classify this capture:\n\n${text}`
    );
    const kind = result?.kind;
    if (kind === 'note' || kind === 'task' || kind === 'note_and_task' || kind === 'reference') {
      return kind;
    }
    return 'unknown';
  }

  async dayStartBriefing(digest: DayStartDigest): Promise<string> {
    const result = await this.chatJSON<{ summary: string }>(
      'You write a calm two-sentence morning briefing. Factual, warm, no exclamation marks, no advice. Respond as JSON: {"summary": "..."}',
      dayStartPrompt(digest)
    );
    return result?.summary ?? fallbackSummary(digest);
  }

  /**
   * One round-trip to an Ollama-compatible /api/chat with format=json.
   * Returns null when unavailable or on any failure — callers fall back.
   */
  private async chatJSON<T>(system: string, user: string): Promise<T | null> {
    if (!this.available()) return null;
    const s = this.settings();
    try {
      const response = await fetch(`${s.ollamaUrl.replace(/\/+$/, '')}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: s.ollamaModel,
          stream: false,
          format: 'json',
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user },
          ],
        }),
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) return null;
      const payload = (await response.json()) as { message?: { content?: string } };
      const content = payload.message?.content;
      if (!content) return null;
      return JSON.parse(content) as T;
    } catch {
      return null;
    }
  }
}
