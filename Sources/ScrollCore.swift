import CoreGraphics

/// 滚动来源。触控板和鼠标滚轮手感完全不同，必须分开处理：
/// 触控板本身就是像素级连续滚动且自带惯性，再插值只会更糊。
enum ScrollSource {
    case mouse       // 传统滚轮，一格一格跳
    case trackpad    // 触控板 / 妙控鼠标，连续像素滚动
}

/// 滚动调节参数。
struct ScrollTuning: Codable, Equatable {
    /// 反转方向
    var reverse = true
    /// 平滑插值
    var smooth = true
    /// 一格滚轮走多少像素
    var step: Double = 55
    /// 衰减系数，越小越快停下。0.1~0.95
    var damping: Double = 0.75
    /// 只对鼠标生效，触控板保持原样
    var mouseOnly = true

    static let `default` = ScrollTuning()

    /// 参数夹到安全范围，防止界面传进离谱的值导致滚动卡死或飞出去。
    var sanitized: ScrollTuning {
        var t = self
        t.step = min(max(step, 5), 300)
        t.damping = min(max(damping, 0.1), 0.95)
        return t
    }
}

/// 判断这个滚动事件要不要接管。
enum ScrollFilter {
    /// 触控板事件是连续的（isContinuous 为真），鼠标滚轮是离散的。
    static func source(isContinuous: Bool) -> ScrollSource {
        isContinuous ? .trackpad : .mouse
    }

    /// 该不该改写这个事件。
    static func shouldHandle(source: ScrollSource, tuning: ScrollTuning) -> Bool {
        // 两个开关都关了就没必要拦
        guard tuning.reverse || tuning.smooth else { return false }
        if tuning.mouseOnly && source == .trackpad { return false }
        return true
    }
}

/// 平滑滚动的积分器。把一次滚轮跳变摊到多帧里发出去。
/// 做法是维护一个"还欠多少像素"的缓冲，每帧吐出其中一部分。
struct SmoothScroller {
    private(set) var remaining: Double = 0

    /// 小于这个值就直接一次性吐完，免得拖出无限小的尾巴。
    static let epsilon = 0.1

    var isIdle: Bool { abs(remaining) < SmoothScroller.epsilon }

    /// 来了一格滚轮，累加进缓冲。同向连续滚动会叠加，反向会抵消。
    mutating func push(_ delta: Double) {
        remaining += delta
    }

    /// 吐出这一帧应该滚多少。damping 越大每帧吐得越少、滑得越久。
    mutating func next(damping: Double) -> Double {
        guard !isIdle else {
            remaining = 0
            return 0
        }
        // 剩余量太小时一次吐完，避免无限逼近 0
        let out = remaining * (1 - damping)
        if abs(out) < SmoothScroller.epsilon {
            let all = remaining
            remaining = 0
            return all
        }
        remaining -= out
        return out
    }

    mutating func reset() { remaining = 0 }
}
