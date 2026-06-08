// utils/PalmRejection.ets
// 手掌误触检测 — 多点触摸 + 大面积 + 高压力过滤

export interface PalmConfig {
  maxTouchPoints: number;       // 超过此触点数 → 可能是手掌
  minTouchArea: number;         // 最小接触面积阈值
  highForceThreshold: number;   // 高压力阈值（手掌通常力大）
  enableDebug: boolean;         // 打印调试日志
}

const DEFAULT_CONFIG: PalmConfig = {
  maxTouchPoints: 1,
  minTouchArea: 20,
  highForceThreshold: 0.95,
  enableDebug: false
};

export class PalmRejection {
  private config: PalmConfig;
  private consecutivePalmCount: number = 0;
  private readonly PALM_COOLDOWN_MS: number = 300;
  private lastPalmTime: number = 0;

  constructor(config: Partial<PalmConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  // 判断当前触摸是否包含手掌
  isPalmTouch(e: TouchEvent): boolean {
    const touches = e.touches;
    const changedTouches = e.changedTouches;

    // 检测1：触点数量异常（>1 且有大面积 → 手掌 + 笔尖）
    if (touches.length > this.config.maxTouchPoints) {
      // 检查是否存在大面积触点
      for (let i = 0; i < touches.length; i++) {
        const t = touches[i];
        const area = this.estimateContactArea(t);
        if (area > this.config.minTouchArea) {
          this.onPalmDetected('多触点 + 大面积');
          return true;
        }
      }
    }

    // 检测2：单触点但接触面积特别大（整个手掌扁平贴合）
    if (touches.length === 1) {
      const area = this.estimateContactArea(touches[0]);
      if (area > this.config.minTouchArea * 2.5) {
        this.onPalmDetected('单触点超大接触面积');
        return true;
      }
      // 力特别大 → 可能是故意下压的手掌
      const force = touches[0].force ?? 0;
      if (force > this.config.highForceThreshold && area > this.config.minTouchArea) {
        this.onPalmDetected('高压力 + 大面积');
        return true;
      }
    }

    // 检测3：接触面积在短时间内急剧增大（手掌突然放下）
    if (changedTouches.length > 0) {
      const ct = changedTouches[0];
      const area = this.estimateContactArea(ct);
      if (area > this.config.minTouchArea * 3) {
        this.onPalmDetected('接触面积急剧增大');
        return true;
      }
    }

    this.consecutivePalmCount = 0;
    return false;
  }

  // 手掌冷却——短暂忽略所有触摸以防误触
  isInCooldown(): boolean {
    return (Date.now() - this.lastPalmTime) < this.PALM_COOLDOWN_MS;
  }

  // 判断 touch 是否为笔尖（小而精确的接触）
  isStylusTip(touch: Touch): boolean {
    const area = this.estimateContactArea(touch);
    // 笔尖接触面积小于阈值
    if (area < this.config.minTouchArea * 0.4) return true;
    // 压感笔的 force 值在正常书写范围
    const force = touch.force ?? 0.5;
    if (force > 0.05 && force < 0.9) return true;
    return false;
  }

  // 从 touches 中提取最可能的笔尖 touch
  getStylusTouch(e: TouchEvent): Touch | null {
    if (e.touches.length === 0) return null;
    if (e.touches.length === 1) {
      return this.isStylusTip(e.touches[0]) ? e.touches[0] : null;
    }
    // 多个触点 → 找面积最小的那个
    let best = e.touches[0];
    let bestArea = Infinity;
    for (let i = 0; i < e.touches.length; i++) {
      const area = this.estimateContactArea(e.touches[i]);
      if (area < bestArea) {
        bestArea = area;
        best = e.touches[i];
      }
    }
    return this.isStylusTip(best) ? best : null;
  }

  // 估算接触面积（简化：基于压力和 force 属性推断）
  private estimateContactArea(touch: Touch): number {
    // HarmonyOS Touch 对象可能没有直接 area 属性
    // 使用 force 和 fingerCount 近似推断
    const force = touch.force ?? 0.5;
    // 高力值通常意味着大面积接触（手掌 vs 笔尖）
    return force * 60; // 映射到 0~60 的范围
  }

  reset(): void {
    this.consecutivePalmCount = 0;
    this.lastPalmTime = 0;
  }

  private onPalmDetected(reason: string): void {
    this.consecutivePalmCount++;
    this.lastPalmTime = Date.now();
    if (this.config.enableDebug) {
      console.log(`PalmRejection: 手掌检测 (${reason}) #${this.consecutivePalmCount}`);
    }
  }
}
