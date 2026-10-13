/**
 * Inline markup (SPEC §5): **bold**, *italic*, ==highlight== (nestable, must not cross),
 * and tokens {{user.name}} / {{answer.<key>}}.
 *
 * Scanning rule (shared with the Flutter parser): at each position, `**` is checked before `*`;
 * a marker closes the format if that format is the innermost open one, opens it if it is not open,
 * and is an error if it is open but not innermost (crossing).
 */

export type MarkupFormat = 'bold' | 'italic' | 'highlight';

export interface MarkupIssue {
  index: number;
  message: string;
}

export type MarkupToken = { kind: 'user.name' } | { kind: 'answer'; key: string };

const TOKEN_PATTERN = /^\{\{\s*(user\.name|answer\.([a-z][a-z0-9_]*))\s*\}\}/;

/** Parses a `{{…}}` token at `index`; returns null if the text there is not a valid token. */
function readToken(text: string, index: number): { token: MarkupToken; length: number } | null {
  const match = TOKEN_PATTERN.exec(text.slice(index));
  if (!match) return null;
  const token: MarkupToken = match[2] ? { kind: 'answer', key: match[2] } : { kind: 'user.name' };
  return { token, length: match[0].length };
}

/** Returns every markup problem in `text` (empty array = valid). */
export function validateMarkup(text: string): MarkupIssue[] {
  const issues: MarkupIssue[] = [];
  const stack: { format: MarkupFormat; index: number }[] = [];

  const toggle = (format: MarkupFormat, index: number) => {
    const top = stack[stack.length - 1];
    if (top?.format === format) {
      stack.pop();
    } else if (stack.some((open) => open.format === format)) {
      issues.push({ index, message: `"${format}" closes across another open format` });
    } else {
      stack.push({ format, index });
    }
  };

  let i = 0;
  while (i < text.length) {
    if (text.startsWith('{{', i)) {
      const token = readToken(text, i);
      if (!token) {
        const end = text.indexOf('}}', i);
        const raw = end === -1 ? text.slice(i) : text.slice(i, end + 2);
        issues.push({ index: i, message: `invalid token ${raw}` });
        i = end === -1 ? text.length : end + 2;
      } else {
        i += token.length;
      }
    } else if (text.startsWith('}}', i)) {
      issues.push({ index: i, message: 'unmatched "}}"' });
      i += 2;
    } else if (text.startsWith('**', i)) {
      toggle('bold', i);
      i += 2;
    } else if (text.startsWith('==', i)) {
      toggle('highlight', i);
      i += 2;
    } else if (text[i] === '*') {
      toggle('italic', i);
      i += 1;
    } else {
      i += 1;
    }
  }
  for (const open of stack) issues.push({ index: open.index, message: `unclosed "${open.format}"` });
  return issues;
}

/** All `{{…}}` tokens used in `text` (invalid ones are ignored). */
export function extractTokens(text: string): MarkupToken[] {
  const tokens: MarkupToken[] = [];
  let i = text.indexOf('{{');
  while (i !== -1) {
    const token = readToken(text, i);
    if (token) tokens.push(token.token);
    i = text.indexOf('{{', i + 2);
  }
  return tokens;
}
