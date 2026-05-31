// utils/FoldingManager.ets
// 编辑器折叠管理 — 检测可折叠区域并管理展开/折叠状态

export interface FoldableRegion {
  startLine: number;
  endLine: number;
  type: 'heading' | 'codeblock';
  isCollapsed: boolean;
}

export class FoldingManager {
  private regions: FoldableRegion[] = [];

  detectRegions(lines: string[]): void {
    this.regions = [];
    const headingStack: number[] = [];

    for (let i = 0; i < lines.length; i++) {
      const hMatch = lines[i].match(/^(#{1,6})\s/);
      if (hMatch) {
        const level = hMatch[1].length;
        // 关闭更高级别或同级标题的折叠区域
        while (headingStack.length > 0 &&
          this.regions[headingStack[headingStack.length - 1]].startLine >= 0) {
          const prevIdx = headingStack.pop()!;
          // find the matching level
          const prevLevel = lines[this.regions[prevIdx].startLine].match(/^(#{1,6})\s/)![1].length;
          if (prevLevel >= level) {
            this.regions[prevIdx].endLine = i - 1;
          } else {
            headingStack.push(prevIdx);
            break;
          }
        }
        this.regions.push({
          startLine: i,
          endLine: lines.length - 1,
          type: 'heading',
          isCollapsed: false
        });
        headingStack.push(this.regions.length - 1);
      }
    }

    // 关闭所有剩余未闭合的
    for (const idx of headingStack) {
      this.regions[idx].endLine = lines.length - 1;
    }
  }

  toggleFold(line: number): boolean {
    for (const region of this.regions) {
      if (region.startLine === line) {
        region.isCollapsed = !region.isCollapsed;
        return true;
      }
    }
    return false;
  }

  getVisibleLines(lines: string[]): string[] {
    if (this.regions.length === 0) return lines;
    const hidden: Set<number> = new Set();
    for (const region of this.regions) {
      if (region.isCollapsed) {
        for (let i = region.startLine + 1; i <= region.endLine; i++) {
          hidden.add(i);
        }
      }
    }
    return lines.filter((_: string, idx: number) => !hidden.has(idx));
  }

  isFolded(line: number): boolean {
    for (const region of this.regions) {
      if (region.isCollapsed && line === region.startLine) return true;
    }
    return false;
  }
}
