import AppKit
import PointerkunCore

/// `RGBAColor`（Core の純粋な色表現）と AppKit / CoreGraphics の色との相互変換。
extension RGBAColor {
    /// sRGB の `NSColor` に変換する。
    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// 描画用の `CGColor`（sRGB）に変換する。
    var cgColor: CGColor {
        nsColor.cgColor
    }

    /// `NSColor` から生成する。sRGB に正規化してから各成分を取り出す。
    init(_ color: NSColor) {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }
}
