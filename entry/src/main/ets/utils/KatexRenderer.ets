// utils/KatexRenderer.ets
// LaTeX 数学公式渲染器 — 通过 ArkWeb 加载 KaTeX CDN 渲染公式

import { webview } from '@kit.ArkWeb';

export interface MathBlock {
  type: 'inline' | 'block';
  content: string;
}

export interface LatexBlock extends MathBlock {
  rawIndex: number;
}

@Component
export struct KatexWebView {
  @Prop latexCode: string = '';
  @Prop displayMode: boolean = false;
  @Prop themeMode: string = 'dark';
  @State webHeight: number = 60;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.webHeight = this.displayMode ? 80 : 40;
  }

  build() {
    Web({ src: $rawfile('katex_render.html'), controller: this.controller })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .width('100%')
      .height(this.webHeight)
      .onPageEnd(() => {
        const escaped = this.latexCode
          .replace(/\\/g, '\\\\')
          .replace(/`/g, '\\`')
          .replace(/\n/g, '\\n');
        this.controller.runJavaScript("setTheme('" + this.themeMode + "')");
        this.controller.runJavaScript(
          "renderLatex(`" + escaped + "`," + (this.displayMode ? 'true' : 'false') + ")"
        );
      })
  }
}

export function extractLatexBlocks(mdContent: string): LatexBlock[] {
  const blocks: LatexBlock[] = [];
  let idx = 0;

  // 块级 $$...$$
  const blockRegex = /\$\$([\s\S]*?)\$\$/g;
  let m: RegExpExecArray | null;
  while ((m = blockRegex.exec(mdContent)) !== null) {
    const block: LatexBlock = { type: 'block', content: m[1].trim(), rawIndex: idx };
    blocks.push(block);
    idx++;
  }

  // 行内 $...$（排除 $$）
  const inlineRegex = /(?<!\$)\$(?!\$)([^$\n]+?)\$(?!\$)/g;
  while ((m = inlineRegex.exec(mdContent)) !== null) {
    const block: LatexBlock = { type: 'inline', content: m[1].trim(), rawIndex: idx };
    blocks.push(block);
    idx++;
  }

  return blocks;
}
