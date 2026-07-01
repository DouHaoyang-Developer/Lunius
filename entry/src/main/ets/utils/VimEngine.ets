// utils/VimEngine.ets
// Vim 模式引擎 — normal/insert/visual 模式，支持 hjkl/w/b/e/dd/yy/p/u/v/V 等

export type VimMode = 'normal' | 'insert' | 'visual';

export interface VimActionResult {
  handled: boolean;
  content?: string;
  cursor?: number;
  yankBuffer?: string;
  visualStart?: number;
  visualEnd?: number;
}

export class VimEngine {
  mode: VimMode = 'normal';
  private commandBuffer: string = '';
  private yankBuffer: string = '';
  private undoStack: string[] = [];
  private motionCount: number = 0;
  private visualStart: number = -1;

  private isVisualMode(): boolean {
    return this.mode === 'visual' && this.visualStart >= 0;
  }

  private getVisualRange(cursor: number): [number, number] {
    if (this.visualStart <= cursor) {
      return [this.visualStart, cursor];
    }
    return [cursor, this.visualStart];
  }

  handleKey(key: string, content: string, cursor: number, lines: string[]): VimActionResult {
    if (this.mode === 'insert') {
      if (key === 'Escape') {
        this.mode = 'normal';
        this.visualStart = -1;
        return { handled: true, cursor: Math.max(0, cursor - 1) };
      }
      return { handled: false };
    }

    if (this.isVisualMode()) {
      return this.handleVisualKey(key, content, cursor, lines);
    }

    if (this.commandBuffer.length > 0) {
      return this.handleCommandBuffer(key, content, cursor, lines);
    }

    const currentLine = this.getCurrentLine(content, cursor);
    const currentLineIdx = this.getLineIndex(content, cursor);
    const colInLine = cursor - this.getLineStart(content, currentLineIdx);

    switch (key) {
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

      case 'd': this.commandBuffer = 'd'; return { handled: true };
      case 'y': this.commandBuffer = 'y'; return { handled: true };

      case 'i':
        this.mode = 'insert';
        this.visualStart = -1;
        return { handled: true };
      case 'a':
        this.mode = 'insert';
        this.visualStart = -1;
        return { handled: true, cursor: Math.min(cursor + 1, content.length) };
      case 'o': {
        const lineEndChar = this.getLineEnd(content, currentLineIdx);
        const newText = content.substring(0, lineEndChar + 1) + '\n' +
          content.substring(lineEndChar + 1);
        this.mode = 'insert';
        this.visualStart = -1;
        return { handled: true, content: newText, cursor: lineEndChar + 2 };
      }
      case 'I':
        this.mode = 'insert';
        this.visualStart = -1;
        return { handled: true, cursor: this.getLineStart(content, currentLineIdx) };
      case 'A':
        this.mode = 'insert';
        this.visualStart = -1;
        return { handled: true, cursor: this.getLineEnd(content, currentLineIdx) };

      case 'v':
        this.mode = 'visual';
        this.visualStart = cursor;
        return { handled: true, visualStart: cursor, visualEnd: cursor };
      case 'V': {
        const lnStart = this.getLineStart(content, currentLineIdx);
        const lnEnd = this.getLineEnd(content, currentLineIdx);
        this.mode = 'visual';
        this.visualStart = lnStart;
        return { handled: true, visualStart: lnStart, visualEnd: lnEnd };
      }

      case 'u':
        if (this.undoStack.length > 0) {
          const prev = this.undoStack.pop()!;
          return { handled: true, content: prev, cursor: cursor };
        }
        return { handled: true };

      case 'p':
        if (this.yankBuffer.length > 0) {
          const insertPos = cursor < content.length ? cursor + 1 : content.length;
          const newContent = content.substring(0, insertPos) + this.yankBuffer +
            content.substring(insertPos);
          return { handled: true, content: newContent,
            cursor: insertPos + this.yankBuffer.length };
        }
        return { handled: true };

      case 'Escape':
        this.commandBuffer = '';
        this.visualStart = -1;
        this.mode = 'normal';
        return { handled: true };

      default: return { handled: false };
    }
  }

  private handleCommandBuffer(key: string, content: string, cursor: number,
    lines: string[]): VimActionResult {
    const cmd = this.commandBuffer + key;
    this.commandBuffer = '';
    const currentLineIdx = this.getLineIndex(content, cursor);
    const lineStart = this.getLineStart(content, currentLineIdx);
    const lineEnd = this.getLineEnd(content, currentLineIdx);
    const currentLine = content.substring(lineStart, lineEnd + 1);

    if (cmd === 'dd') {
      const isLastLine = currentLineIdx === lines.length - 1;
      this.yankBuffer = isLastLine ? currentLine : currentLine + '\n';
      const removeLen = isLastLine && lineStart > 0 ? 2 : (lineEnd + 2 - lineStart);
      const newContent = content.substring(0, lineStart) +
        content.substring(lineStart + removeLen);
      const newCursor = Math.min(lineStart, newContent.length);
      return { handled: true, content: newContent, cursor: newCursor,
        yankBuffer: this.yankBuffer };
    }
    if (cmd === 'yy') {
      const isLastLine = currentLineIdx === lines.length - 1;
      this.yankBuffer = isLastLine ? currentLine : currentLine + '\n';
      return { handled: true, yankBuffer: this.yankBuffer };
    }
    if (cmd === 'dw') {
      let pos = cursor;
      while (pos < content.length && content[pos] !== ' ' && content[pos] !== '\n') pos++;
      this.yankBuffer = content.substring(cursor, pos);
      const newContent = content.substring(0, cursor) + content.substring(pos);
      return { handled: true, content: newContent, cursor: cursor,
        yankBuffer: this.yankBuffer };
    }
    if (cmd === 'yw') {
      let pos = cursor;
      while (pos < content.length && content[pos] !== ' ' && content[pos] !== '\n') pos++;
      this.yankBuffer = content.substring(cursor, pos);
      return { handled: true, yankBuffer: this.yankBuffer };
    }
    return { handled: false };
  }

  private handleVisualKey(key: string, content: string, cursor: number,
    lines: string[]): VimActionResult {
    if (key === 'Escape') {
      this.mode = 'normal';
      this.visualStart = -1;
      return { handled: true, cursor: cursor, visualStart: -1, visualEnd: -1 };
    }

    const currentLineIdx = this.getLineIndex(content, cursor);
    const colInLine = cursor - this.getLineStart(content, currentLineIdx);

    switch (key) {
      case 'h': {
        const nc = Math.max(0, cursor - 1);
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }
      case 'l': {
        const nc = Math.min(content.length, cursor + 1);
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }
      case 'j': {
        const nextStart = this.getLineStart(content, currentLineIdx + 1);
        const nextLine = lines[currentLineIdx + 1] || '';
        const nc = nextStart + Math.min(colInLine, nextLine.length);
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }
      case 'k': {
        const prevStart = this.getLineStart(content, currentLineIdx - 1);
        const prevLine = lines[currentLineIdx - 1] || '';
        const nc = prevStart + Math.min(colInLine, prevLine.length);
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }
      case 'w': {
        let pos = cursor;
        while (pos < content.length && content[pos] !== ' ' && content[pos] !== '\n') pos++;
        while (pos < content.length && (content[pos] === ' ' || content[pos] === '\n')) pos++;
        const nc = Math.min(pos, content.length);
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }
      case 'b': {
        let pos = cursor - 1;
        while (pos > 0 && (content[pos] === ' ' || content[pos] === '\n')) pos--;
        while (pos > 0 && content[pos] !== ' ' && content[pos] !== '\n') pos--;
        const nc = pos > 0 ? pos + 1 : 0;
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }
      case 'e': {
        let pos = cursor;
        while (pos < content.length && content[pos] !== ' ' && content[pos] !== '\n') pos++;
        const nc = Math.max(0, pos - 1);
        return { handled: true, cursor: nc, visualStart: this.visualStart, visualEnd: nc };
      }

      case 'y': {
        const [ySelStart, ySelEnd] = this.getVisualRange(cursor);
        this.yankBuffer = content.substring(ySelStart, ySelEnd + 1);
        this.mode = 'normal';
        this.visualStart = -1;
        return { handled: true, cursor: ySelStart, yankBuffer: this.yankBuffer,
          visualStart: -1, visualEnd: -1 };
      }
      case 'd': {
        const [dSelStart, dSelEnd] = this.getVisualRange(cursor);
        this.yankBuffer = content.substring(dSelStart, dSelEnd + 1);
        const newContent = content.substring(0, dSelStart) +
          content.substring(dSelEnd + 1);
        this.mode = 'normal';
        this.visualStart = -1;
        return { handled: true, content: newContent,
          cursor: Math.min(dSelStart, newContent.length),
          yankBuffer: this.yankBuffer, visualStart: -1, visualEnd: -1 };
      }
      case 'c': {
        const [cSelStart, cSelEnd] = this.getVisualRange(cursor);
        this.yankBuffer = content.substring(cSelStart, cSelEnd + 1);
        const newContent = content.substring(0, cSelStart) +
          content.substring(cSelEnd + 1);
        this.mode = 'insert';
        this.visualStart = -1;
        return { handled: true, content: newContent, cursor: cSelStart,
          yankBuffer: this.yankBuffer, visualStart: -1, visualEnd: -1 };
      }

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
