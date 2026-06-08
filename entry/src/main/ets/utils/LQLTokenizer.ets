// utils/LQLTokenizer.ets
// LQL 词法分析器 — 将 LQL 文本转换为 Token 序列

export enum TokenType {
  KEYWORD = 'KEYWORD',
  IDENTIFIER = 'IDENTIFIER',
  STRING = 'STRING',
  NUMBER = 'NUMBER',
  COMMA = 'COMMA',
  OPERATOR = 'OPERATOR',
  LPAREN = 'LPAREN',
  RPAREN = 'RPAREN',
  TAG = 'TAG',
  EOF = 'EOF'
}

export interface Token {
  type: TokenType;
  value: string;
  position: number;
}

const KEYWORDS: Set<string> = new Set([
  'TABLE', 'LIST', 'TASK', 'CALENDAR',
  'FROM', 'WHERE', 'SORT', 'GROUP', 'BY', 'LIMIT',
  'ASC', 'DESC', 'AND', 'OR', 'NOT', 'TRUE', 'FALSE'
]);

const OPERATORS: Set<string> = new Set([
  '=', '!=', '>', '<', '>=', '<='
]);

export class LQLTokenizer {
  private input: string = '';
  private pos: number = 0;

  tokenize(input: string): Token[] {
    this.input = input;
    this.pos = 0;
    const tokens: Token[] = [];

    while (this.pos < this.input.length) {
      const ch = this.peek();

      // 跳过空白
      if (ch === ' ' || ch === '\n' || ch === '\r' || ch === '\t') {
        this.pos++;
        continue;
      }

      // 字符串
      if (ch === '"') {
        tokens.push(this.readString());
        continue;
      }

      // 标签
      if (ch === '#') {
        tokens.push(this.readTag());
        continue;
      }

      // 数字
      if (ch >= '0' && ch <= '9') {
        tokens.push(this.readNumber());
        continue;
      }

      // 逗号
      if (ch === ',') {
        tokens.push({ type: TokenType.COMMA, value: ',', position: this.pos });
        this.pos++;
        continue;
      }

      // 括号
      if (ch === '(') {
        tokens.push({ type: TokenType.LPAREN, value: '(', position: this.pos });
        this.pos++;
        continue;
      }
      if (ch === ')') {
        tokens.push({ type: TokenType.RPAREN, value: ')', position: this.pos });
        this.pos++;
        continue;
      }

      // 运算符 (>=, <=, !=, =, >, <)
      if (ch === '>' || ch === '<' || ch === '=' || ch === '!') {
        tokens.push(this.readOperator());
        continue;
      }

      // 标识符或关键字
      if (this.isIdentStart(ch)) {
        tokens.push(this.readIdentOrKeyword());
        continue;
      }

      // 跳过不识别的字符
      this.pos++;
    }

    tokens.push({ type: TokenType.EOF, value: '', position: this.pos });
    return tokens;
  }

  private peek(): string {
    return this.pos < this.input.length ? this.input[this.pos] : '';
  }

  private isIdentStart(ch: string): boolean {
    const code = ch.charCodeAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || ch === '_' || ch === '.';
  }

  private isIdentPart(ch: string): boolean {
    const code = ch.charCodeAt(0);
    return this.isIdentStart(ch) || (code >= 48 && code <= 57) || ch === '-' || ch === '.';
  }

  private readString(): Token {
    const start = this.pos;
    this.pos++; // skip opening "
    let value = '';
    while (this.pos < this.input.length && this.peek() !== '"') {
      value += this.input[this.pos];
      this.pos++;
    }
    if (this.peek() === '"') this.pos++; // skip closing "
    return { type: TokenType.STRING, value: value, position: start };
  }

  private readTag(): Token {
    const start = this.pos;
    this.pos++; // skip #
    let value = '';
    while (this.pos < this.input.length) {
      const ch = this.peek();
      if (ch === ' ' || ch === '\n' || ch === '\r' || ch === '\t' || ch === ',' || ch === ')') break;
      value += ch;
      this.pos++;
    }
    return { type: TokenType.TAG, value: value, position: start };
  }

  private readNumber(): Token {
    const start = this.pos;
    let value = '';
    while (this.pos < this.input.length) {
      const ch = this.peek();
      if ((ch >= '0' && ch <= '9') || ch === '.') {
        value += ch;
        this.pos++;
      } else {
        break;
      }
    }
    return { type: TokenType.NUMBER, value: value, position: start };
  }

  private readOperator(): Token {
    const start = this.pos;
    let value = this.input[this.pos];
    this.pos++;

    // 双字符运算符
    if (this.pos < this.input.length) {
      const two = value + this.input[this.pos];
      if (OPERATORS.has(two)) {
        value = two;
        this.pos++;
      }
    }
    return { type: TokenType.OPERATOR, value: value, position: start };
  }

  private readIdentOrKeyword(): Token {
    const start = this.pos;
    let value = '';
    while (this.pos < this.input.length && this.isIdentPart(this.peek())) {
      value += this.input[this.pos];
      this.pos++;
    }
    if (KEYWORDS.has(value.toUpperCase())) {
      return { type: TokenType.KEYWORD, value: value.toUpperCase(), position: start };
    }
    return { type: TokenType.IDENTIFIER, value: value, position: start };
  }
}

export function tokenizeLQL(input: string): Token[] {
  const tokenizer = new LQLTokenizer();
  return tokenizer.tokenize(input);
}
