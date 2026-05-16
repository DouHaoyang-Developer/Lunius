/**
 * Markdown 语法自动补全项
 */
export interface CompletionItem {
  /** 显示标签 */
  label: string;
  /** 插入文本 */
  insertText: string;
  /** 辅助说明 */
  description: string;
  /** 插入后光标相对于插入文本末尾的偏移（负数表示向左回退） */
  cursorOffset: number;
}

/**
 * 根据光标前的文本内容，返回适用的补全建议
 * @param textBeforeCursor 光标前的文本（当前行开始到光标位置）
 * @param fullLine 当前完整行
 * @returns 补全建议列表，空数组表示无建议
 */
export function getCompletions(textBeforeCursor: string, fullLine: string): CompletionItem[] {
  // 仅在行首或紧跟空格时触发
  const trimmed = textBeforeCursor.trimStart();
  if (trimmed === '') {
    return [];
  }

  // ─── 标题补全 ──────────────────────────────
  if (/^#{1,5}$/.test(trimmed)) {
    const level = trimmed.length + 1;
    const hashes = '#'.repeat(level);
    return [
      {
        label: `${hashes} 标题${level}`,
        insertText: `${hashes} `,
        description: `${level}级标题`,
        cursorOffset: 0,
      }
    ];
  }

  if (trimmed === '#') {
    return [
      { label: '# 一级标题', insertText: '# ', description: '一级标题', cursorOffset: 0 },
      { label: '## 二级标题', insertText: '## ', description: '二级标题', cursorOffset: 0 },
      { label: '### 三级标题', insertText: '### ', description: '三级标题', cursorOffset: 0 },
    ];
  }

  // ─── 粗体 / 斜体 ──────────────────────────
  if (trimmed === '*' || trimmed === '**') {
    return [
      { label: '**粗体**', insertText: '**粗体文本**', description: '粗体', cursorOffset: -2 },
      { label: '*斜体*', insertText: '*斜体文本*', description: '斜体', cursorOffset: -1 },
      { label: '***粗斜体***', insertText: '***粗斜体***', description: '粗体+斜体', cursorOffset: -3 },
    ];
  }

  // ─── 代码 ──────────────────────────────────
  if (trimmed === '`') {
    return [
      { label: '`行内代码`', insertText: '`代码`', description: '行内代码', cursorOffset: -1 },
      { label: '```代码块', insertText: '```\n\n```', description: '代码块', cursorOffset: -4 },
    ];
  }

  // ─── 引用 / 列表 ───────────────────────────
  if (trimmed === '>') {
    return [
      { label: '> 引用', insertText: '> ', description: '引用块', cursorOffset: 0 },
    ];
  }

  if (trimmed === '-' || trimmed === '+' || trimmed === '*') {
    return [
      { label: '- 无序列表', insertText: '- ', description: '无序列表', cursorOffset: 0 },
    ];
  }

  if (/^\d$/.test(trimmed)) {
    return [
      { label: `${trimmed}. 有序列表`, insertText: `${trimmed}. `, description: '有序列表', cursorOffset: 0 },
    ];
  }

  if (trimmed === '[') {
    return [
      { label: '[标题](url)', insertText: '[链接文本](https://)', description: '超链接', cursorOffset: -9 },
    ];
  }

  if (trimmed === '![') {
    return [
      { label: '![图片](url)', insertText: '![图片描述](https://)', description: '图片', cursorOffset: -10 },
    ];
  }

  // ─── 水平分割线 ────────────────────────────
  if (trimmed === '---' || trimmed === '***' || trimmed === '___') {
    return [
      { label: '分割线', insertText: '\n---\n', description: '水平分割线', cursorOffset: -1 },
    ];
  }

  // ─── 任务列表 ──────────────────────────────
  if (trimmed === '- [' || trimmed === '* [') {
    return [
      { label: '- [ ] 待办', insertText: '- [ ] ', description: '待办事项', cursorOffset: 0 },
      { label: '- [x] 已办', insertText: '- [x] ', description: '已完成事项', cursorOffset: 0 },
    ];
  }

  return [];
}

/**
 * 判断是否应显示补全面板
 */
export function shouldShowCompletion(textBeforeCursor: string): boolean {
  const trimmed = textBeforeCursor.trimStart();
  if (trimmed === '') {
    return false;
  }

  // 触发字符
  const triggers = ['#', '*', '`', '>', '-', '+', '[', '!', '---', '***', '___'];
  for (const t of triggers) {
    if (trimmed === t || trimmed.startsWith(t) && t.length > 1) {
      return true;
    }
  }

  // 数字开头（有序列表）
  if (/^\d+$/.test(trimmed)) {
    return true;
  }

  // - [ 任务列表
  if (trimmed === '- [' || trimmed === '* [') {
    return true;
  }

  // # 开头（多级标题）
  if (/^#{1,5}$/.test(trimmed)) {
    return true;
  }

  return false;
}
