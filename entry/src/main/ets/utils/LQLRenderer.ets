// utils/LQLRenderer.ets
// LQL 结果渲染器 — TABLE/LIST/TASK HTML 输出

import { LQLResult } from './LQLExecutor';
import { TableRowData } from '../models/BasesTypes';

export class LQLRenderer {
  render(result: LQLResult): string {
    switch (result.type) {
      case 'TABLE': return this.renderTable(result);
      case 'LIST': return this.renderList(result);
      case 'TASK': return this.renderTasks(result);
      case 'CALENDAR': return this.renderCalendar(result);
    }
    return '';
  }

  private renderTable(result: LQLResult): string {
    if (result.rows.length === 0) {
      return '<p style="color:var(--text-muted);font-style:italic;">无匹配结果</p>';
    }

    let html = '<div style="overflow-x:auto;"><table style="width:100%;border-collapse:collapse;font-size:13px;">';
    // 表头
    html += '<thead><tr style="background:var(--background-secondary);">';
    for (const h of result.headers) {
      html += `<th style="padding:6px 10px;border-bottom:2px solid var(--divider);text-align:left;font-weight:600;">${h}</th>`;
    }
    html += '</tr></thead><tbody>';

    // 数据行
    for (let i = 0; i < result.rows.length; i++) {
      const row = result.rows[i];
      const bg = i % 2 === 0 ? 'var(--background-primary)' : 'var(--background-secondary)';
      html += `<tr style="background:${bg};">`;
      for (const h of result.headers) {
        const val = row.cells.get(h) || '-';
        html += `<td style="padding:5px 10px;border-bottom:1px solid var(--divider);">${val}</td>`;
      }
      html += '</tr>';
    }

    html += '</tbody></table></div>';
    html += `<p style="color:var(--text-muted);font-size:11px;margin-top:6px;">${result.totalCount} 条结果</p>`;
    return html;
  }

  private renderList(result: LQLResult): string {
    if (result.rows.length === 0) {
      return '<p style="color:var(--text-muted);font-style:italic;">无匹配结果</p>';
    }

    let html = '<ul style="padding-left:20px;">';
    for (const row of result.rows) {
      const title = row.title || row.path;
      html += `<li style="margin:4px 0;"><strong>${title}</strong>`;
      // 额外字段
      row.cells.forEach((val: string, key: string) => {
        if (key !== 'title' && key !== 'path' && val !== '') {
          html += ' <span style="color:var(--text-muted);font-size:11px;">' + key + ': ' + val + '</span>';
        }
      });
      html += '</li>';
    }
    html += '</ul>';
    html += `<p style="color:var(--text-muted);font-size:11px;">${result.totalCount} 条结果</p>`;
    return html;
  }

  private renderTasks(result: LQLResult): string {
    if (result.rows.length === 0) {
      return '<p style="color:var(--text-muted);font-style:italic;">无任务</p>';
    }

    let html = '<ul style="padding-left:20px;list-style:none;">';
    for (const row of result.rows) {
      const title = row.title || row.path;
      html += `<li style="margin:4px 0;"><input type="checkbox" style="margin-right:6px;">${title}</li>`;
    }
    html += '</ul>';
    html += `<p style="color:var(--text-muted);font-size:11px;">${result.totalCount} 个任务</p>`;
    return html;
  }

  private renderCalendar(result: LQLResult): string {
    if (result.rows.length === 0) {
      return '<p style="color:var(--text-muted);font-style:italic;">无日期数据</p>';
    }
    let html = '<div style="display:flex;flex-wrap:wrap;gap:6px;">';
    for (const row of result.rows) {
      html += `<div style="padding:6px 10px;background:var(--background-secondary);border-radius:6px;font-size:12px;">`;
      html += `<strong>${row.title || row.path}</strong>`;
      html += '</div>';
    }
    html += '</div>';
    html += `<p style="color:var(--text-muted);font-size:11px;">${result.totalCount} 条</p>`;
    return html;
  }
}

export const lqlRenderer: LQLRenderer = new LQLRenderer();
