import AppKit

/// マウスカーソルの現在位置を一定間隔でポーリングし、コールバックで通知する。
///
/// `NSEvent.mouseLocation` は Cocoa のグローバル座標（原点は左下、y は上向き）を返し、
/// `NSWindow.setFrameOrigin` と同じ座標系のため、追従ウィンドウの配置にそのまま使える。
/// アクセシビリティ権限は不要。
@MainActor
final class MouseTracker {
    private var timer: Timer?
    /// 位置更新ごとに呼ばれる。Cocoa グローバル座標。
    var onMove: ((CGPoint) -> Void)?

    /// 約 60fps で追従を開始する。既に動作中なら何もしない。
    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onMove?(NSEvent.mouseLocation)
            }
        }
        // ドラッグやメニュー操作中でも止まらないよう common モードで回す。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
