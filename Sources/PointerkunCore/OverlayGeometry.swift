import CoreGraphics

/// オーバーレイウィンドウの配置計算（純粋関数）。AppKit に依存せずテスト可能にする。
public enum OverlayGeometry {
    /// 指定した点を中心に、与えたサイズのウィンドウを置くための原点（左下）を返す。
    /// `point` は Cocoa グローバル座標（原点は左下）を想定する。
    public static func originCentered(at point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
    }
}
