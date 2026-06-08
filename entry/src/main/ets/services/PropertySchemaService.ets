// services/PropertySchemaService.ets
// 属性 Schema 管理 — CRUD + JSON 持久化

import { PropertySchema, PropertyType } from './ApiTypes';
import { fileIo } from '@kit.CoreFileKit';

const SCHEMA_FILE = 'property_schemas.json';

export class PropertySchemaService {
  private schemas: Map<string, PropertySchema> = new Map();
  private basePath: string = '';

  setBasePath(path: string): void {
    this.basePath = path;
  }

  async load(): Promise<void> {
    if (!this.basePath) return;
    try {
      const filePath = `${this.basePath}/${SCHEMA_FILE}`;
      const exists = fileIo.accessSync(filePath);
      if (!exists) return;
      const raw = fileIo.readTextSync(filePath);
      const arr: PropertySchema[] = JSON.parse(raw);
      for (const s of arr) {
        this.schemas.set(s.key, s);
      }
    } catch (e) {
      console.error('PropertySchemaService load failed: ' + JSON.stringify(e));
    }
  }

  private async save(): Promise<void> {
    if (!this.basePath) return;
    try {
      const filePath = `${this.basePath}/${SCHEMA_FILE}`;
      const arr: PropertySchema[] = [];
      this.schemas.forEach((s: PropertySchema) => arr.push(s));
      const raw = JSON.stringify(arr);
      fileIo.writeTextSync(filePath, raw);
    } catch (e) {
      console.error('PropertySchemaService save failed: ' + JSON.stringify(e));
    }
  }

  getSchema(key: string): PropertySchema | undefined {
    return this.schemas.get(key);
  }

  getAllSchemas(): PropertySchema[] {
    const result: PropertySchema[] = [];
    this.schemas.forEach((s: PropertySchema) => result.push(s));
    return result;
  }

  async upsertSchema(schema: PropertySchema): Promise<void> {
    this.schemas.set(schema.key, schema);
    await this.save();
  }

  async deleteSchema(key: string): Promise<void> {
    this.schemas.delete(key);
    await this.save();
  }

  ensureDefault(key: string): PropertySchema {
    const existing = this.schemas.get(key);
    if (existing) return existing;
    const schema: PropertySchema = {
      key: key,
      type: PropertyType.TEXT,
      label: key,
      required: false
    };
    this.schemas.set(key, schema);
    return schema;
  }
}

export const propertySchemaService: PropertySchemaService = new PropertySchemaService();
