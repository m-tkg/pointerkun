import AppKit
import PointerkunCore

/// 機能2: ポインタの周りに半透明の円を常時表示し、マウスに追従させる。
///
/// 透明クリックスルー窓に `CAShapeLayer` の塗りつぶし円を描き、`MouseTracker` の
/// 通知ごとにウィンドウ原点をカーソル中心へ移動する。色・直径・不透明度は設定で変わる（機能3）。
@MainActor
final class HighlightController {
    private var window: NSWindow?
    private let circle = CAShapeLayer()
    private let tracker = MouseTracker()
    private var settings = HighlightSettings()

    /// 設定を反映する。有効なら表示・追従を開始し、無効なら隠す。
    func update(_ newSettings: HighlightSettings) {
        settings = newSettings
        if settings.isEnabled {
            ensureWindow()
            applyAppearance()
            startTracking()
        } else {
            stopTracking()
        }
    }

    // MARK: - 構築・外観

    private func ensureWindow() {
        guard window == nil else { return }
        let diameter = CGFloat(settings.diameter)
        let window = OverlayWindow.make(size: NSSize(width: diameter, height: diameter))
        window.contentView?.layer?.addSublayer(circle)
        self.window = window
    }

    /// 直径・色をウィンドウと円レイヤーに反映する。
    private func applyAppearance() {
        guard let window, let contentView = window.contentView else { return }
        let diameter = CGFloat(settings.diameter)
        let size = NSSize(width: diameter, height: diameter)

        // ウィンドウ・コンテンツビューをリサイズ（中心を保つ）。
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        window.setContentSize(size)
        window.setFrameOrigin(OverlayGeometry.originCentered(at: center, size: size))
        contentView.frame = NSRect(origin: .zero, size: size)

        // アニメーション無しで即時反映する。
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        circle.frame = contentView.bounds
        circle.path = CGPath(ellipseIn: contentView.bounds, transform: nil)
        circle.fillColor = settings.color.cgColor
        CATransaction.commit()
    }

    // MARK: - 追従

    private func startTracking() {
        guard let window else { return }
        moveWindow(to: NSEvent.mouseLocation)
        window.orderFrontRegardless()
        tracker.onMove = { [weak self] point in self?.moveWindow(to: point) }
        tracker.start()
    }

    private func stopTracking() {
        tracker.stop()
        window?.orderOut(nil)
    }

    private func moveWindow(to point: CGPoint) {
        guard let window else { return }
        window.setFrameOrigin(OverlayGeometry.originCentered(at: point, size: window.frame.size))
    }
}
