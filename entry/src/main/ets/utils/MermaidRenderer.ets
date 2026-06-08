// utils/MermaidRenderer.ets
// Mermaid 图表渲染器 — 通过 ArkWeb Web 组件内嵌 CDN Mermaid.js 渲染 SVG

import { webview } from '@kit.ArkWeb';

@Component
export struct MermaidWebView {
  @Prop mermaidCode: string = '';
  @Prop themeMode: string = 'dark';
  @State webHeight: number = 300;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.webHeight = this.estimateHeight(this.mermaidCode);
  }

  private estimateHeight(code: string): number {
    const lines = code.split('\n').length;
    // 每条约 30px 高度，最小 200px，最大 800px
    const h = Math.max(200, Math.min(800, lines * 30));
    return h;
  }

  private escapeCode(code: string): string {
    let escaped = code
      .replace(/\\/g, '\\\\')
      .replace(/`/g, '\\`')
      .replace(/\$/g, '\\$')
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '');
    return escaped;
  }

  build() {
    Web({ src: $rawfile('mermaid_render.html'), controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .width('100%')
      .height(this.webHeight)
      .onPageEnd(() => {
        const escaped = this.escapeCode(this.mermaidCode);
        // 先设置主题
        this.controller.runJavaScript(
          "setTheme('" + this.themeMode + "')"
        );
        // 再渲染图表
        this.controller.runJavaScript(
          "renderMermaid(`" + escaped + "`)"
        );
      })
  }
}

// 从 Markdown 内容提取 Mermaid 代码块
export interface ContentBlock {
  type: 'markdown' | 'mermaid';
  content: string;
  rendered: string;
}

export function extractMermaidBlocks(mdContent: string): ContentBlock[] {
  const blocks: ContentBlock[] = [];
  const lines = mdContent.split('\n');
  let currentMd = '';
  let inMermaid = false;
  let mermaidLines: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!inMermaid && line.trim().startsWith('```mermaid')) {
      // 进入 Mermaid 块
      if (currentMd.length > 0) {
        blocks.push({ type: 'markdown', content: currentMd, rendered: '' });
        currentMd = '';
      }
      inMermaid = true;
      mermaidLines = [];
    } else if (inMermaid && line.trim() === '```') {
      // 结束 Mermaid 块
      blocks.push({ type: 'mermaid', content: mermaidLines.join('\n'), rendered: '' });
      inMermaid = false;
      mermaidLines = [];
    } else if (inMermaid) {
      mermaidLines.push(line);
    } else {
      currentMd += (currentMd.length > 0 ? '\n' : '') + line;
    }
  }
  // 剩余文本
  if (currentMd.length > 0) {
    blocks.push({ type: 'markdown', content: currentMd, rendered: '' });
  }
  // 未闭合的 Mermaid 块还原为 markdown
  if (inMermaid && mermaidLines.length > 0) {
    const recoveredText: string = '```mermaid\n' + mermaidLines.join('\n');
    const recoveredBlock: ContentBlock = { type: 'markdown', content: recoveredText, rendered: '' };
    blocks.push(recoveredBlock);
  }

  return blocks;
}
