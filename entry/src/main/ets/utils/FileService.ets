import { fileIo as fs, ReadOptions, ListFileOptions } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 文件服务工具类（异步 I/O）
 * 提供文件创建、读取、写入等功能，所有磁盘操作均为异步 Promise 风格
 */
export class FileService {
  private static instance: FileService;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  public static getInstance(): FileService {
    if (!FileService.instance) {
      FileService.instance = new FileService();
    }
    return FileService.instance;
  }

  /**
   * 设置应用上下文（应在 EntryAbility.onCreate 中全局初始化）
   */
  public setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 获取应用文件目录路径（公开方法，供其他模块如 TabManager 使用）
   */
  public getBaseDirectory(): string {
    if (!this.context) {
      throw new Error('Context is not set. Call setContext() in EntryAbility.onCreate first.');
    }
    return this.context.filesDir;
  }

  /**
   * 获取应用文件目录路径
   */
  private getFilesDir(): string {
    return this.getBaseDirectory();
  }

  /**
   * 创建新文件（仅创建，不写入冗余空内容）
   * @param fileName 文件名
   * @returns 文件路径，失败返回空字符串
   */
  public async createFile(fileName: string): Promise<string> {
    try {
      const filesDir = this.getFilesDir();
      const filePath = `${filesDir}/${fileName}`;
      const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      await fs.close(file);
      console.info(`File created: ${filePath}`);
      return filePath;
    } catch (err) {
      console.error(`Failed to create file: ${(err as BusinessError).message}`);
      return '';
    }
  }

  /**
   * 读取文件内容
   * @param filePath 文件路径
   * @returns 文件内容字符串
   */
  public async readFile(filePath: string): Promise<string> {
    try {
      const accessResult = await fs.access(filePath);
      if (!accessResult) {
        console.warn(`File does not exist: ${filePath}`);
        return '';
      }

      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);
      const stats = await fs.stat(filePath);
      const fileSize = stats.size;

      if (fileSize === 0) {
        await fs.close(file);
        return '';
      }

      const arrayBuffer = new ArrayBuffer(fileSize);
      const readOptions: ReadOptions = { offset: 0, length: fileSize };
      const readLen = await fs.read(file.fd, arrayBuffer, readOptions);
      await fs.close(file);

      const buf = buffer.from(arrayBuffer, 0, readLen);
      const content = buf.toString();
      console.info(`File read: ${filePath}, size: ${fileSize}`);
      return content;
    } catch (err) {
      console.error(`Failed to read file: ${(err as BusinessError).message}`);
      return '';
    }
  }

  /**
   * 写入文件内容（覆盖写入）
   * @param filePath 文件路径
   * @param content 要写入的内容
   */
  public async writeFile(filePath: string, content: string): Promise<void> {
    try {
      const file = await fs.open(
        filePath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC
      );
      const writeLen = await fs.write(file.fd, content);
      await fs.close(file);
      console.info(`File written: ${filePath}, length: ${writeLen}`);
    } catch (err) {
      console.error(`Failed to write file: ${(err as BusinessError).message}`);
    }
  }

  /**
   * 重命名/移动文件
   * @param oldPath 原文件路径
   * @param newPath 新文件路径
   */
  public async renameFile(oldPath: string, newPath: string): Promise<boolean> {
    try {
      await fs.moveFile(oldPath, newPath);
      console.info(`File renamed: ${oldPath} -> ${newPath}`);
      return true;
    } catch (err) {
      console.error(`Failed to rename file: ${(err as BusinessError).message}`);
      return false;
    }
  }

  /**
   * 检查文件是否存在
   * @param filePath 文件路径
   * @returns 是否存在
   */
  public async fileExists(filePath: string): Promise<boolean> {
    try {
      return await fs.access(filePath);
    } catch (err) {
      return false;
    }
  }

  /**
   * 生成唯一文件名（避免重名）
   * @param baseName 基础文件名
   * @param extension 文件扩展名
   * @returns 唯一文件名
   */
  public async generateUniqueFileName(baseName: string, extension: string): Promise<string> {
    const filesDir = this.getFilesDir();
    let fileName = `${baseName}.${extension}`;
    let counter = 1;

    while (await this.fileExists(`${filesDir}/${fileName}`)) {
      fileName = `${baseName}(${counter}).${extension}`;
      counter++;
    }

    return fileName;
  }

  /**
   * 获取所有 .md 文件列表
   * @returns 文件路径数组
   */
  public async getMarkdownFiles(): Promise<string[]> {
    try {
      const filesDir = this.getFilesDir();
      const listFileOption: ListFileOptions = {
        recursion: false,
        listNum: 0,
        filter: {
          suffix: ['.md'],
          displayName: [],
          fileSizeOver: 0,
          lastModifiedAfter: 0
        }
      };
      const files = await fs.listFile(filesDir, listFileOption);
      return files.map(file => `${filesDir}/${file}`);
    } catch (err) {
      console.error(`Failed to list markdown files: ${(err as BusinessError).message}`);
      return [];
    }
  }
}
