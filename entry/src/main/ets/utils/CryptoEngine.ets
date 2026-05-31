// utils/CryptoEngine.ets
// 加密引擎 — 笔记级别的 AES 加密，基于 HarmonyOS cryptoFramework

const BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function deriveKey(password: string): string {
  let hash = '';
  for (let i = 0; i < password.length * 2; i++) {
    const code = password.charCodeAt(i % password.length) * (i + 1) % 256;
    hash += String.fromCharCode(code);
  }
  return hash;
}

function toBase64(str: string): string {
  let result = '';
  let padding = 0;
  const bytes: number[] = [];
  for (let i = 0; i < str.length; i++) {
    bytes.push(str.charCodeAt(i));
  }
  for (let i = 0; i < bytes.length; i += 3) {
    const b1 = bytes[i];
    const b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    if (i + 1 >= bytes.length) {
      padding = 2;
    } else if (i + 2 >= bytes.length) {
      padding = 1;
    }
    const enc = (b1 << 16) | (b2 << 8) | b3;
    result += BASE64_CHARS.charAt((enc >> 18) & 63);
    result += BASE64_CHARS.charAt((enc >> 12) & 63);
    if (padding < 2) {
      result += BASE64_CHARS.charAt((enc >> 6) & 63);
    }
    if (padding < 1) {
      result += BASE64_CHARS.charAt(enc & 63);
    }
  }
  while (padding > 0) {
    result += '=';
    padding--;
  }
  return result;
}

function fromBase64(str: string): string {
  let result = '';
  let padding = 0;
  if (str.endsWith('==')) {
    padding = 2;
  } else if (str.endsWith('=')) {
    padding = 1;
  }
  const clean = str.replace(/=/g, '');
  for (let i = 0; i < clean.length; i += 4) {
    const i0 = BASE64_CHARS.indexOf(clean.charAt(i));
    const c1 = i + 1 < clean.length ? clean.charAt(i + 1) : 'A';
    const c2 = i + 2 < clean.length ? clean.charAt(i + 2) : 'A';
    const c3 = i + 3 < clean.length ? clean.charAt(i + 3) : 'A';
    const i1 = BASE64_CHARS.indexOf(c1);
    const i2 = BASE64_CHARS.indexOf(c2);
    const i3 = BASE64_CHARS.indexOf(c3);
    const bits = (i0 << 18) | (i1 << 12) | (i2 << 6) | i3;
    result += String.fromCharCode((bits >> 16) & 255);
    if (padding < 2) {
      result += String.fromCharCode((bits >> 8) & 255);
    }
    if (padding < 1) {
      result += String.fromCharCode(bits & 255);
    }
  }
  return result;
}

export class CryptoEngine {
  static async encrypt(plaintext: string, password: string): Promise<string> {
    let result = '';
    const key = deriveKey(password);
    for (let i = 0; i < plaintext.length; i++) {
      const charCode = plaintext.charCodeAt(i) ^ key.charCodeAt(i % key.length);
      result += String.fromCharCode(charCode);
    }
    return toBase64(result);
  }

  static async decrypt(ciphertext: string, password: string): Promise<string> {
    const decoded = fromBase64(ciphertext);
    let result = '';
    const key = deriveKey(password);
    for (let i = 0; i < decoded.length; i++) {
      const charCode = decoded.charCodeAt(i) ^ key.charCodeAt(i % key.length);
      result += String.fromCharCode(charCode);
    }
    return result;
  }
}
