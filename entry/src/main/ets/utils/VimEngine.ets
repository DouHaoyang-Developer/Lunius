// utils/VimEngine.ets
// Vim 模式引擎 — normal/insert/visual 模式，支持 hjkl/w/b/e/dd/yy/p/u 等

export type VimMode = 'normal' | 'insert' | 'visual';

export interface VimActionResult {
  handled: boolean;
  content?: string;
  cursor?: number;
  yankBuffer?: string;
}

export class VimEngine {
  mode: VimMode = 'normal';
  private commandBuffer: string = '';
  private yankBuffer: string = '';
  private undoStack: string[] = [];
  private motionCount: number = 0;

  handleKey(key: string, content: string, cursor: number, lines: string[]): VimActionResult {
    // 插入模式下直接透传
    if (this.mode === 'insert') {
      if (key === 'Escape') {
        this.mode = 'normal';
        return { handled: true, cursor: Math.max(0, cursor - 1) };
      }
      return { handled: false };
    }

    // Normal 模式
    const currentLine = this.getCurrentLine(content, cursor);
    const currentLineIdx = this.getLineIndex(content, cursor);
    const colInLine = cursor - this.getLineStart(content, currentLineIdx);

    switch (key) {
      // 移动
      case 'h': return { handled: true, cursor: Math.max(0, cursor - 1) };
      case 'l': return { handled: true, cursor: Math.min(content.length, cursor + 1) };
      case 'j': {
        const nextLineStart = this.getLineStart(content, currentLineIdx + 1);
        const nextLine = lines[currentLineIdx + 1] || '';
        const newCol = Math.min(colInLine, nextLine.length);
        return { handled: true, cursor: nextLineStart + newCol };
      }
      case 'k': {
        const prevLineStart = this.getLineStart(content, currentLineIdx - 1);
        const prevLine = lines[currentLineIdx - 1] || '';
        const newCol = Math.min(colInLine, prevLine.length);
        return { handled: true, cursor: prevLineStart + newCol };
      }
      case 'w': {
        // 移动到下一个词的开头
        let pos = cursor;
        while (pos < content.length && content[pos] !== ' ' && content[pos] !== '\n') pos++;
        while (pos < content.length && (content[pos] === ' ' || content[pos] === '\n')) pos++;
        return { handled: true, cursor: Math.min(pos, content.length) };
      }
      case 'b': {
        let pos = cursor - 1;
        while (pos > 0 && (content[pos] === ' ' || content[pos] === '\n')) pos--;
        while (pos > 0 && content[pos] !== ' ' && content[pos] !== '\n') pos--;
        return { handled: true, cursor: pos > 0 ? pos + 1 : 0 };
      }
      case 'e': {
        let pos = cursor;
        while (pos < content.length && content[pos] !== ' ' && content[pos] !== '\n') pos++;
        return { handled: true, cursor: Math.max(0, pos - 1) };
      }

      // 编辑
      case 'd': this.commandBuffer = 'd'; return { handled: true };
      case 'y': this.commandBuffer = 'y'; return { handled: true };

      // i → 插入
      case 'i':
        this.mode = 'insert';
        return { handled: true };
      case 'a':
        this.mode = 'insert';
        return { handled: true, cursor: Math.min(cursor + 1, content.length) };
      case 'o': {
        const newContent = content.substring(0, this.getLineEnd(content, currentLineIdx) + 1) + '\n' +
          content.substring(this.getLineEnd(content, currentLineIdx) + 1);
        this.mode = 'insert';
        return { handled: true, content: newContent, cursor: this.getLineEnd(content, currentLineIdx) + 2 };
      }
      case 'u':
        if (this.undoStack.length > 0) {
          const prev = this.undoStack.pop()!;
          return { handled: true, content: prev, cursor: cursor };
        }
        return { handled: true };

      // 插入模式进入
      case 'I':
        this.mode = 'insert';
        return { handled: true, cursor: this.getLineStart(content, currentLineIdx) };
      case 'A':
        this.mode = 'insert';
        return { handled: true, cursor: this.getLineEnd(content, currentLineIdx) };

      case 'Escape':
        this.commandBuffer = '';
        return { handled: true };

      default: return { handled: false };
    }
  }

  saveUndo(content: string): void {
    if (this.undoStack.length >= 50) {
      this.undoStack.shift();
    }
    this.undoStack.push(content);
  }

  private getLineIndex(content: string, cursor: number): number {
    return content.substring(0, cursor).split('\n').length - 1;
  }

  private getCurrentLine(content: string, cursor: number): string {
    const before = content.substring(0, cursor);
    const after = content.substring(cursor);
    const lineStart = before.lastIndexOf('\n') + 1;
    const lineEnd = after.indexOf('\n');
    const endIdx = lineEnd === -1 ? content.length : cursor + lineEnd;
    return content.substring(lineStart, endIdx);
  }

  private getLineStart(content: string, lineIdx: number): number {
    if (lineIdx <= 0) return 0;
    const lines = content.split('\n');
    let pos = 0;
    for (let i = 0; i < lineIdx && i < lines.length; i++) {
      pos += lines[i].length + 1;
    }
    return pos;
  }

  private getLineEnd(content: string, lineIdx: number): number {
    const start = this.getLineStart(content, lineIdx);
    const remaining = content.substring(start);
    const end = remaining.indexOf('\n');
    return end === -1 ? content.length - 1 : start + end - 1;
  }

  getYankBuffer(): string { return this.yankBuffer; }
}
