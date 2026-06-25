import AppKit
import PointerkunCore

/// 機能1: ホットキーで、マウスカーソルを中心に円が広がるエフェクト（リップル）を表示する。
///
/// 発火のたびに透明クリックスルー窓を生成し、`CAShapeLayer` のリング（縁取り円）を
/// 拡大しながらフェードさせる。少しずらした2本のリングで波紋らしさを出す。
/// 色・最大直径・線幅・継続時間は設定で変わる（機能3）。
@MainActor
final class RippleController {
    private var settings = RippleSettings()
    /// アニメーション完了まで保持するアクティブな窓（終わったら解放する）。
    private var activeWindows: [NSWindow] = []

    func update(_ newSettings: RippleSettings) {
        settings = newSettings
    }

    /// 現在のマウス位置にリップルを発火する。
    func fire() {
        let center = NSEvent.mouseLocation
        let diameter = CGFloat(settings.maxDiameter)
        let size = NSSize(width: diameter, height: diameter)

        let window = OverlayWindow.make(size: size)
        window.setFrameOrigin(OverlayGeometry.originCentered(at: center, size: size))
        guard let contentView = window.contentView else { return }

        // 2本のリングを少し時間差で広げる。
        addRing(to: contentView, beginDelay: 0)
        addRing(to: contentView, beginDelay: settings.duration * 0.25)

        window.orderFrontRegardless()
        activeWindows.append(window)

        // 全リング（時間差含む）が終わる頃に窓を片付ける。
        let total = settings.duration * 1.25 + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + total) { [weak self, weak window] in
            guard let self, let window else { return }
            window.orderOut(nil)
            self.activeWindows.removeAll { $0 === window }
        }
    }

    /// 縁取り円レイヤーを1本追加し、拡大＋フェードのアニメーションを付ける。
    private func addRing(to view: NSView, beginDelay: TimeInterval) {
        let bounds = view.bounds
        let lineWidth = CGFloat(settings.lineWidth)
        let ring = CAShapeLayer()
        ring.frame = bounds
        // 線幅ぶん内側に描いて、拡大時に端が切れないようにする。
        let inset = bounds.insetBy(dx: lineWidth, dy: lineWidth)
        ring.path = CGPath(ellipseIn: inset, transform: nil)
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = settings.color.cgColor
        ring.lineWidth = lineWidth
        // 中心基準で拡大させる。
        ring.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        ring.position = CGPoint(x: bounds.midX, y: bounds.midY)
        ring.opacity = 0
        view.layer?.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.1
        scale.toValue = 1.0

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.9
        fade.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = settings.duration
        group.beginTime = CACurrentMediaTime() + beginDelay
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        ring.add(group, forKey: "ripple")
    }
}
