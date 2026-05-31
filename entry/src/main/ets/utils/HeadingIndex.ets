// utils/HeadingIndex.ets
// 标题和块 ID 索引 — 解析 Markdown 内容中的标题和块引用

export interface HeadingAnchor {
  text: string;
  level: number;
  lineNumber: number;
  slug: string;
}

export interface BlockAnchor {
  blockId: string;
  text: string;
  lineNumber: number;
}

export function parseHeadings(content: string): HeadingAnchor[] {
  const headings: HeadingAnchor[] = [];
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(/^(#{1,6})\s+(.+)/);
    if (match) {
      const level = match[1].length;
      const text = match[2].trim();
      const slug = text.toLowerCase().replace(/[^\w一-鿿]+/g, '-').replace(/-+$/g, '');
      headings.push({ text, level, lineNumber: i + 1, slug });
    }
  }
  return headings;
}

export function parseBlockIds(content: string): Map<string, number> {
  const blocks = new Map<string, number>();
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const match = lines[i].match(/\^([a-zA-Z0-9_-]+)$/);
    if (match) {
      blocks.set(match[1], i + 1);
    }
  }
  return blocks;
}

export function findHeadingBySlug(content: string, slug: string): number {
  const headings = parseHeadings(content);
  for (const h of headings) {
    if (h.slug === slug || h.text.toLowerCase().replace(/[^\w一-鿿]+/g, '-') === slug) {
      return h.lineNumber;
    }
  }
  return -1;
}
