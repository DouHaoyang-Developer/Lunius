export function describe(name: string, fn: () => void): void { fn(); }
export function beforeAll(fn: () => void): void { fn(); }
export function beforeEach(fn: () => void): void { fn(); }
export function afterEach(fn: () => void): void { fn(); }
export function afterAll(fn: () => void): void { fn(); }
export function it(name: string, fn: () => void): void { fn(); }

export class Expect {
  private value: Object;
  constructor(value: Object) { this.value = value; }
  assertContain(substr: string): void { const s: string = this.value as string; if (s.indexOf(substr) < 0) { throw new Error('not contain'); } }
  assertEqual(expected: Object): void { if (this.value !== expected) { throw new Error('not equal'); } }
}
export function expect(value: Object): Expect { return new Expect(value); }
