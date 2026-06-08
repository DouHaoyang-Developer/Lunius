// models/BasesTypes.ets
// 数据库视图 (Bases) 类型定义

import { PropertyType } from '../services/ApiTypes';

export interface ColumnDef {
  key: string;
  label: string;
  type: PropertyType;
  width: number;
  visible: boolean;
  sortable: boolean;
  filterable: boolean;
}

export interface FilterCondition {
  property: string;
  operator: 'equals' | 'not_equals' | 'contains' | 'not_contains' |
            'greater_than' | 'less_than' | 'exists' | 'not_exists';
  value: string;
}

export interface FilterGroup {
  conjunction: 'and' | 'or';
  conditions: (FilterCondition | FilterGroup)[];
}

export interface SortRule {
  property: string;
  direction: 'asc' | 'desc';
}

export interface TableViewConfig {
  columns: ColumnDef[];
  filter: FilterGroup;
  sort: SortRule[];
  groupBy: string;
  limit: number;
}

export interface TableRowData {
  noteId: string;
  title: string;
  path: string;
  cells: Map<string, string>;
}

export interface TableViewState {
  config: TableViewConfig;
  rows: TableRowData[];
  isLoading: boolean;
  totalCount: number;
  filteredCount: number;
}
