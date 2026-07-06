import { parseInline, parseMarkdown } from '../../core/markdown';

/** Inline spans: minimal bold / italic / code. */
export function Inline({ text }: { text: string }) {
  return (
    <>
      {parseInline(text).map((span, i) => {
        switch (span.kind) {
          case 'bold':
            return <strong key={i}>{span.text}</strong>;
          case 'italic':
            return <em key={i}>{span.text}</em>;
          case 'code':
            return <code key={i}>{span.text}</code>;
          default:
            return <span key={i}>{span.text}</span>;
        }
      })}
    </>
  );
}

/** Calm read view for a note body, rendered from the core block parser. */
export function MarkdownPreview({ markdown }: { markdown: string }) {
  const blocks = parseMarkdown(markdown);
  return (
    <div className="md">
      {blocks.map((block, i) => {
        switch (block.kind) {
          case 'heading': {
            const level = Math.min(block.level, 4);
            const Tag = `h${level}` as 'h1' | 'h2' | 'h3' | 'h4';
            return (
              <Tag key={i}>
                <Inline text={block.text} />
              </Tag>
            );
          }
          case 'paragraph':
            return (
              <p key={i}>
                <Inline text={block.text} />
              </p>
            );
          case 'bullet':
            return (
              <div className="li" key={i}>
                <span className="marker">•</span>
                <span>
                  <Inline text={block.text} />
                </span>
              </div>
            );
          case 'ordered':
            return (
              <div className="li" key={i}>
                <span className="marker">{block.number}.</span>
                <span>
                  <Inline text={block.text} />
                </span>
              </div>
            );
          case 'task':
            return (
              <div className="li" key={i}>
                <span className="marker">{block.done ? '☑' : '☐'}</span>
                <span className={block.done ? 'task-done' : ''}>
                  <Inline text={block.text} />
                </span>
              </div>
            );
          case 'quote':
            return (
              <blockquote key={i}>
                <Inline text={block.text} />
              </blockquote>
            );
          case 'code':
            return (
              <pre key={i}>
                <code>{block.code}</code>
              </pre>
            );
          case 'hr':
            return <hr key={i} />;
        }
      })}
    </div>
  );
}
