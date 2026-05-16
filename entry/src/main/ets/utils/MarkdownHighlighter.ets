import { LengthUnit } from '@kit.ArkUI';

/**
 * 行级样式
 */
const DEFAULT_STYLE: TextStyle = new TextStyle({
  fontColor: '#333333',
  fontSize: { value: 16, unit: LengthUnit.VP },
});

const HEADING_STYLES: TextStyle[] = [
  new TextStyle({ fontColor: '#6C3BD4', fontSize: { value: 28, unit: LengthUnit.VP }, fontWeight: FontWeight.Bold }),
  new TextStyle({ fontColor: '#7B2D8B', fontSize: { value: 24, unit: LengthUnit.VP }, fontWeight: FontWeight.Bold }),
  new TextStyle({ fontColor: '#8B5CF6', fontSize: { value: 20, unit: LengthUnit.VP }, fontWeight: FontWeight.Bold }),
  new TextStyle({ fontColor: '#9D50FF', fontSize: { value: 18, unit: LengthUnit.VP }, fontWeight: FontWeight.Bold }),
  new TextStyle({ fontColor: '#B065FB', fontSize: { value: 16, unit: LengthUnit.VP }, fontWeight: FontWeight.Bold }),
  new TextStyle({ fontColor: '#C084FC', fontSize: { value: 16, unit: LengthUnit.VP }, fontWeight: FontWeight.Bold }),
];

const QUOTE_STYLE: TextStyle = new TextStyle({
  fontColor: '#8B5CF6',
  fontSize: { value: 16, unit: LengthUnit.VP },
  fontStyle: FontStyle.Italic,
});

const HR_STYLE: TextStyle = new TextStyle({
  fontColor: '#C7C7CC',
  fontSize: { value: 14, unit: LengthUnit.VP },
});

/**
 * 行内样式范围
 */
interface InlineRange {
  start: number;
  end: number;
  style: TextStyle;
  decoration?: DecorationStyle;
}

/**
 * 将原始 Markdown 文本转换为带语法高亮的 MutableStyledString
 */
export function highlightMarkdown(text: string): MutableStyledString {
  const result: MutableStyledString = new MutableStyledString(text);
  applyFontStyle(result, 0, text.length, DEFAULT_STYLE);

  const lines = text.split('\n');
  let offset = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineLen = line.length;

    const headingMatch = line.match(/^(#{1,6})\s+(.*)/);
    const isHr = /^(---|\*\*\*|___)\s*$/.test(line);
    const isQuote = /^>\s?/.test(line);

    if (headingMatch) {
      const level = headingMatch[1].length;
      applyFontStyle(result, offset, lineLen, HEADING_STYLES[level - 1]);
    } else if (isHr) {
      applyFontStyle(result, offset, lineLen, HR_STYLE);
    } else if (isQuote) {
      applyFontStyle(result, offset, lineLen, QUOTE_STYLE);
    } else {
      const inlineRanges = parseInlineRanges(line, offset);
      for (const r of inlineRanges) {
        applyFontStyle(result, r.start, r.end - r.start, r.style);
        if (r.decoration) {
          applyDecorationStyle(result, r.start, r.end - r.start, r.decoration);
        }
      }
    }

    offset += lineLen + 1;
  }

  return result;
}

function applyFontStyle(target: MutableStyledString, start: number, length: number, style: TextStyle): void {
  target.setStyle({
    start: start,
    length: length,
    styledKey: StyledStringKey.FONT,
    styledValue: style
  });
}

function applyDecorationStyle(target: MutableStyledString, start: number, length: number,
  style: DecorationStyle): void {
  target.setStyle({
    start: start,
    length: length,
    styledKey: StyledStringKey.DECORATION,
    styledValue: style
  });
}

/**
 * 解析一行文本中的行内 Markdown 语法，返回样式范围列表
 */
function parseInlineRanges(line: string, lineOffset: number): InlineRange[] {
  const ranges: InlineRange[] = [];
  let i = 0;

  while (i < line.length) {
    const biMatch = matchAt(line, i, /^\*\*\*(.+?)\*\*\*/);
    if (biMatch) {
      ranges.push({
        start: lineOffset + i,
        end: lineOffset + i + biMatch[0].length,
        style: BI_STYLE
      });
      i += biMatch[0].length;
      continue;
    }

    const bMatch = matchAt(line, i, /^\*\*(.+?)\*\*/);
    if (bMatch) {
      ranges.push({
        start: lineOffset + i,
        end: lineOffset + i + bMatch[0].length,
        style: BOLD_STYLE
      });
      i += bMatch[0].length;
      continue;
    }

    const iMatch = matchAt(line, i, /^\*(?!\*)(.+?)\*(?!\*)/);
    if (iMatch) {
      ranges.push({
        start: lineOffset + i,
        end: lineOffset + i + iMatch[0].length,
        style: ITALIC_STYLE
      });
      i += iMatch[0].length;
      continue;
    }

    const cMatch = matchAt(line, i, /^`([^`]+)`/);
    if (cMatch) {
      ranges.push({
        start: lineOffset + i,
        end: lineOffset + i + cMatch[0].length,
        style: CODE_STYLE
      });
      i += cMatch[0].length;
      continue;
    }

    const lMatch = matchAt(line, i, /^\[([^\]]+)\]\(([^)]+)\)/);
    if (lMatch) {
      ranges.push({
        start: lineOffset + i,
        end: lineOffset + i + lMatch[0].length,
        style: LINK_STYLE,
        decoration: LINK_DECORATION
      });
      i += lMatch[0].length;
      continue;
    }

    i++;
  }

  return ranges;
}

function matchAt(text: string, pos: number, regex: RegExp): RegExpMatchArray | null {
  const sub = text.slice(pos);
  const m = sub.match(regex);
  return m && m.index === 0 ? m : null;
}

// ─── 行内样式 ───────────────────────────────────────────

const BOLD_STYLE: TextStyle = new TextStyle({ fontWeight: FontWeight.Bold });
const ITALIC_STYLE: TextStyle = new TextStyle({ fontStyle: FontStyle.Italic });
const BI_STYLE: TextStyle = new TextStyle({ fontWeight: FontWeight.Bold, fontStyle: FontStyle.Italic });

const CODE_STYLE: TextStyle = new TextStyle({
  fontColor: '#C0392B',
  fontFamily: 'monospace',
  fontSize: { value: 15, unit: LengthUnit.VP },
});

const LINK_STYLE: TextStyle = new TextStyle({
  fontColor: '#8B5CF6',
});

const LINK_DECORATION: DecorationStyle = new DecorationStyle({
  type: TextDecorationType.Underline,
  color: '#8B5CF6',
});
