import Foundation

/// 0...1 で正規化した RGBA の色表現。AppKit に依存せず Codable に永続化するための型。
/// App 側で `NSColor` / `CGColor` に変換して使う。
public struct RGBAColor: Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// ハイライト円の既定色（半透明の黄）。
    public static let defaultHighlight = RGBAColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.35)
    /// リップルの既定色（半透明の青）。
    public static let defaultRipple = RGBAColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.9)

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.red = try c.decodeIfPresent(Double.self, forKey: .red) ?? 0
        self.green = try c.decodeIfPresent(Double.self, forKey: .green) ?? 0
        self.blue = try c.decodeIfPresent(Double.self, forKey: .blue) ?? 0
        self.alpha = try c.decodeIfPresent(Double.self, forKey: .alpha) ?? 1
    }

    private enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
}

/// 「ポインタ追従ハイライト円」（機能2）の設定。常時表示の半透明円。
/// 色・直径・不透明度（色の alpha）を設定 UI から変更できる（機能3）。
public struct HighlightSettings: Codable, Equatable {
    /// 機能の有効/無効。既定はオフ（デモ/プレゼン時にだけ使う想定）。
    public var isEnabled: Bool
    /// 円の塗り色（alpha が不透明度を兼ねる）。
    public var color: RGBAColor
    /// 円の直径（ポイント）。
    public var diameter: Double

    public init(
        isEnabled: Bool = false,
        color: RGBAColor = .defaultHighlight,
        diameter: Double = 60
    ) {
        self.isEnabled = isEnabled
        self.color = color
        self.diameter = diameter
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = HighlightSettings()
        self.isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? d.isEnabled
        self.color = try c.decodeIfPresent(RGBAColor.self, forKey: .color) ?? d.color
        self.diameter = try c.decodeIfPresent(Double.self, forKey: .diameter) ?? d.diameter
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, color, diameter
    }
}

/// 「ホットキーで広がる円（リップル）」（機能1）の設定。
/// 色・最大直径・線幅・継続時間を設定 UI から変更できる（機能3）。
public struct RippleSettings: Codable, Equatable {
    /// 円の線色（alpha が不透明度を兼ねる）。
    public var color: RGBAColor
    /// 広がりきったときの最大直径（ポイント）。
    public var maxDiameter: Double
    /// 円の線幅（ポイント）。
    public var lineWidth: Double
    /// 1 回のアニメーションの継続時間（秒）。
    public var duration: Double

    public init(
        color: RGBAColor = .defaultRipple,
        maxDiameter: Double = 220,
        lineWidth: Double = 4,
        duration: Double = 0.6
    ) {
        self.color = color
        self.maxDiameter = maxDiameter
        self.lineWidth = lineWidth
        self.duration = duration
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RippleSettings()
        self.color = try c.decodeIfPresent(RGBAColor.self, forKey: .color) ?? d.color
        self.maxDiameter = try c.decodeIfPresent(Double.self, forKey: .maxDiameter) ?? d.maxDiameter
        self.lineWidth = try c.decodeIfPresent(Double.self, forKey: .lineWidth) ?? d.lineWidth
        self.duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? d.duration
    }

    private enum CodingKeys: String, CodingKey {
        case color, maxDiameter, lineWidth, duration
    }
}

/// アプリ全体の設定。機能ごとにサブ構造体を持ち、機能追加時はここにプロパティを足して拡張する。
/// 前方/後方互換のため Codable は欠損キーを既定値で補完する。
public struct Settings: Codable, Equatable {
    /// ポインタ追従ハイライト円（機能2）。
    public var highlight: HighlightSettings
    /// ホットキーで広がるリップル（機能1）。
    public var ripple: RippleSettings
    /// リップルを発火させるホットキー（機能1）。
    public var locatorHotKey: HotKeyConfig
    /// ハイライト円の表示/非表示を切り替えるホットキー（機能2）。
    public var highlightHotKey: HotKeyConfig

    public init(
        highlight: HighlightSettings = HighlightSettings(),
        ripple: RippleSettings = RippleSettings(),
        locatorHotKey: HotKeyConfig = .defaultLocator,
        highlightHotKey: HotKeyConfig = .defaultHighlightToggle
    ) {
        self.highlight = highlight
        self.ripple = ripple
        self.locatorHotKey = locatorHotKey
        self.highlightHotKey = highlightHotKey
    }

    /// 既定設定。
    public static let `default` = Settings()

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.highlight = try c.decodeIfPresent(HighlightSettings.self, forKey: .highlight) ?? HighlightSettings()
        self.ripple = try c.decodeIfPresent(RippleSettings.self, forKey: .ripple) ?? RippleSettings()
        self.locatorHotKey = try c.decodeIfPresent(HotKeyConfig.self, forKey: .locatorHotKey) ?? .defaultLocator
        self.highlightHotKey = try c.decodeIfPresent(HotKeyConfig.self, forKey: .highlightHotKey) ?? .defaultHighlightToggle
    }

    private enum CodingKeys: String, CodingKey {
        case highlight, ripple, locatorHotKey, highlightHotKey
    }
}
