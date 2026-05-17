// utils/LivePreviewHelper.ets
// Obsidian 风格实时阅览引擎 —— 基于 RichEditor Spans 的光标感知语法隐藏

import { parseMarkdownSegments, MarkdownSegment } from './MarkdownSegmenter';

// ─── 样式常量 ─────────────────────────────────

const SYNTAX_HIDDEN_STYLE: RichEditorTextStyle = {
  fontColor: Color.Transparent,
  fontSize: 1
};

const SYNTAX_VISIBLE_STYLE: RichEditorTextStyle = {
  fontColor: '#B0B0B0',
  fontSize: 14,
  fontFamily: 'monospace'
};

const CONTENT_STYLE: RichEditorTextStyle = {
  fontColor: '#1A1A1A',
  fontSize: 16,
  fontFamily: 'monospace'
};

const HEADING_1_STYLE: RichEditorTextStyle = {
  fontColor: '#6C3BD4',
  fontSize: 28,
  fontWeight: FontWeight.Bold,
  fontFamily: 'monospace'
};

const HEADING_2_STYLE: RichEditorTextStyle = {
  fontColor: '#7B2D8B',
  fontSize: 24,
  fontWeight: FontWeight.Bold,
  fontFamily: 'monospace'
};

const HEADING_3_STYLE: RichEditorTextStyle = {
  fontColor: '#8B5CF6',
  fontSize: 20,
  fontWeight: FontWeight.Bold,
  fontFamily: 'monospace'
};

export interface RichEditorTextStyle {
  fontColor?: string | Color;
  fontSize?: number;
  fontWeight?: FontWeight;
  fontFamily?: string;
  fontStyle?: FontStyle;
  decoration?: DecorationStyle;
}

// ─── 行级上下文类型 ───────────────────────────

enum LineContext {
  NORMAL = 'normal',
  HEADING = 'heading',
  QUOTE = 'quote',
  HR = 'hr',
  LIST = 'list'
}

export class LivePreviewHelper {
  private isRebuilding: boolean = false;

  getIsRebuilding(): boolean {
    return this.isRebuilding;
  }

  // ─── 主体方法：将 Markdown 文本渲染为 RichEditor Spans ────

  buildSpans(controller: RichEditorController, text: string, caretOffset: number): void {
    if (this.isRebuilding) return;
    this.isRebuilding = true;
    try {
      controller.deleteSpans();
      this.buildSpansInternal(controller, text, caretOffset);
    } catch (e) {
      console.error('LivePreviewHelper buildSpans error: ' + JSON.stringify(e));
    } finally {
      this.isRebuilding = false;
    }
  }

  // ─── 源码模式：纯文本，统一样式 ──────────────────

  buildSourceSpans(controller: RichEditorController, text: string): void {
    if (this.isRebuilding) return;
    this.isRebuilding = true;
    try {
      controller.deleteSpans();
      if (text.length > 0) {
        controller.addTextSpan(text, { style: CONTENT_STYLE });
      }
    } catch (e) {
      console.error('LivePreviewHelper buildSourceSpans error: ' + JSON.stringify(e));
    } finally {
      this.isRebuilding = false;
    }
  }

  // ─── 从 spans 重建纯文本 ──────────────────────

  static extractText(controller: RichEditorController): string {
    try {
      const spans = controller.getSpans();
      let text = '';
      for (let i = 0; i < spans.length; i++) {
        const item = spans[i];
        if (item !== null && item !== undefined) {
          const spanObj = item as RichEditorTextSpanResult;
          const value: string = spanObj.value;
          text = text + value;
        }
      }
      return text;
    } catch (e) {
      console.error('LivePreviewHelper extractText error');
      return '';
    }
  }

  // ─── 内部实现：逐行解析 + 光标感知 ─────────────

  private buildSpansInternal(controller: RichEditorController, text: string, caretOffset: number): void {
    const segments = parseMarkdownSegments(text);
    let offset: number = 0;

    // 当前行的上下文（追踪是否在标题行、引用行、列表行等）
    let currentLineContext: LineContext = LineContext.NORMAL;
    let headingLevel: number = 0;

    for (let i = 0; i < segments.length; i++) {
      const seg: MarkdownSegment = segments[i];
      if (!seg.text) continue;

      const segStart: number = offset;
      const segEnd: number = offset + seg.text.length;
      offset = segEnd;

      // 判断光标是否在语法段内
      const cursorInside: boolean = caretOffset >= 0 &&
        caretOffset >= segStart && caretOffset < segEnd;

      // 换行符重置行上下文
      if (seg.text === '\n') {
        currentLineContext = LineContext.NORMAL;
        headingLevel = 0;
        continue;
      }

      // 根据段类型和行上下文选择样式
      const style = this.chooseStyle(seg, cursorInside, currentLineContext, headingLevel);

      // 更新行上下文
      if (seg.type === 'syntax') {
        // 检测标题
        const hMatch = seg.text.match(/^(#{1,6})\s$/);
        if (hMatch) {
          currentLineContext = LineContext.HEADING;
          headingLevel = hMatch[1].length;
        }
        // 检测引用
        if (seg.text.match(/^>\s?$/)) {
          currentLineContext = LineContext.QUOTE;
        }
        // 检测列表标记
        if (seg.text.match(/^[\-\*\+]\s$/) || seg.text.match(/^\d+\.\s$/)) {
          currentLineContext = LineContext.LIST;
        }
        // 检测分割线
        if (seg.text.match(/^(---|\*\*\*|___)\s*$/)) {
          currentLineContext = LineContext.HR;
        }
      }

      if (style) {
        controller.addTextSpan(seg.text, { style: style });
      } else {
        controller.addTextSpan(seg.text, {});
      }
    }
  }

  private chooseStyle(seg: MarkdownSegment, cursorInside: boolean,
    lineCtx: LineContext, headingLvl: number): RichEditorTextStyle | null {

    const isSyntax: boolean = seg.type === 'syntax';

    // ─── 内容段：始终显示 ───────────────────────
    if (!isSyntax) {
      if (lineCtx === LineContext.QUOTE) {
        return { fontColor: '#8B5CF6', fontSize: 16, fontStyle: FontStyle.Italic, fontFamily: 'monospace' };
      }
      if (lineCtx === LineContext.HR) {
        return { fontColor: '#C7C7CC', fontSize: 14, fontFamily: 'monospace' };
      }
      if (lineCtx === LineContext.HEADING && headingLvl > 0 && headingLvl <= 3) {
        // 标题内容用对应样式
        const headingStyles: RichEditorTextStyle[] = [HEADING_1_STYLE, HEADING_2_STYLE, HEADING_3_STYLE];
        return headingStyles[headingLvl - 1];
      }
      return CONTENT_STYLE;
    }

    // ─── 语法段 ─────────────────────────────────
    // 核心逻辑：光标不在语法段内 → 隐藏；光标在语法段内 → 显示为灰色
    if (cursorInside) {
      return SYNTAX_VISIBLE_STYLE;
    }
    return SYNTAX_HIDDEN_STYLE;
  }
}
