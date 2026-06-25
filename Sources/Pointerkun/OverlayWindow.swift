import AppKit

/// 透明・最前面・クリックスルーのボーダーレスウィンドウを生成するファクトリ。
/// リップル（機能1）とハイライト円（機能2）の双方で使う。
///
/// keykun の `HUDController` と同じ設定を踏襲する:
/// - `level = .statusBar` でメニューバー相当の最前面に表示
/// - `ignoresMouseEvents = true` でクリックを下のアプリに通す（クリックスルー）
/// - `collectionBehavior` で全スペース表示・フルスクリーン補助・Cmd+Tab から除外
enum OverlayWindow {
    static func make(size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        // レイヤーバックの空ビューを内容にする（各コントローラが sublayer を足す）。
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        window.contentView = view
        return window
    }
}
