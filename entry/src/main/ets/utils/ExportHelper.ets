// utils/ExportHelper.ets
// 导出辅助 — 将 Markdown 转为 HTML 并保存/分享

import { markdownToHtml } from './MarkdownToHtml';
import { FileService } from './FileService';
import { print } from '@kit.BasicServicesKit';

export class ExportHelper {
  private static wrapHtml(body: string, title: string): string {
    return '<!DOCTYPE html><html><head><meta charset="utf-8"><title>' + title +
      '</title><style>body{font-family:sans-serif;max-width:800px;margin:0 auto;padding:20px;line-height:1.8}' +
      'h1{color:#333}strong{font-weight:bold}i,em{font-style:italic}' +
      'code{background:#f0f0f0;padding:2px 4px;border-radius:3px}</style></head>' +
      '<body><h1>' + title + '</h1>' + body + '</body></html>';
  }

  static async exportAsHtml(noteId: string, content: string, title: string): Promise<string> {
    const mdHtml = await markdownToHtml(content);
    const fullHtml = ExportHelper.wrapHtml(mdHtml, title);
    const fileService = FileService.getInstance();
    const fileName = title.replace(/[<>:"/\\|?*]/g, '_') + '.html';
    const baseDir = fileService.getBaseDirectory();
    const filePath = baseDir + '/' + fileName;
    await fileService.writeFile(filePath, fullHtml);
    return filePath;
  }

  static async exportMarkdown(noteId: string, content: string, title: string): Promise<string> {
    const fileService = FileService.getInstance();
    const fileName = title.replace(/[<>:"/\\|?*]/g, '_') + '.md';
    const baseDir = fileService.getBaseDirectory();
    const filePath = baseDir + '/' + fileName;
    await fileService.writeFile(filePath, content);
    return filePath;
  }

  static async exportAsPdf(noteId: string, content: string, title: string): Promise<string> {
    const mdHtml = await markdownToHtml(content);
    const fullHtml = ExportHelper.wrapHtml(mdHtml, title);
    // 先保存 HTML 文件
    const fileService = FileService.getInstance();
    const fileName = title.replace(/[<>:"/\\|?*]/g, '_') + '_print.html';
    const filePath = fileService.getBaseDirectory() + '/' + fileName;
    await fileService.writeFile(filePath, fullHtml);
    // 尝试通过 print API 打印
    try {
      await print.print([filePath]);
      return '已发送到打印服务';
    } catch (e) {
      return '已导出 HTML: ' + filePath + '（打印服务不可用）';
    }
  }
}
