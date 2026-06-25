import XCTest
@testable import PointerkunCore

final class SettingsTests: XCTestCase {
    // MARK: - RGBAColor

    func testRGBAColorRoundTrips() throws {
        let color = RGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(RGBAColor.self, from: data)
        XCTAssertEqual(decoded, color)
    }

    // MARK: - Settings defaults / 前方後方互換

    func testDefaultSettingsHasReasonableValues() {
        let s = Settings.default
        XCTAssertFalse(s.highlight.isEnabled)         // ハイライト円は既定オフ（デモ用途）
        XCTAssertGreaterThan(s.highlight.diameter, 0)
        XCTAssertGreaterThan(s.ripple.maxDiameter, 0)
        XCTAssertGreaterThan(s.ripple.duration, 0)
    }

    func testDefaultHotKeysAreDistinct() {
        let s = Settings.default
        // リップル発火は ⌃⌘P、ハイライト切替は ⌃⌘H。
        XCTAssertEqual(s.locatorHotKey.displayString, "⌃⌘P")
        XCTAssertEqual(s.highlightHotKey.displayString, "⌃⌘H")
        XCTAssertNotEqual(s.locatorHotKey, s.highlightHotKey)
    }

    func testSettingsDecodesEmptyObjectToDefaults() throws {
        // 空 JSON（全キー欠損）でも既定値で補完され壊れない。
        let data = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, Settings.default)
    }

    func testSettingsDecodesPartialObject() throws {
        // 一部キーのみの JSON でも、欠損サブ構造体は既定で補完される。
        let json = """
        {"highlight":{"isEnabled":true,"diameter":120}}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.highlight.isEnabled)
        XCTAssertEqual(decoded.highlight.diameter, 120)
        // 指定しなかった ripple / 各ホットキーは既定のまま。
        XCTAssertEqual(decoded.ripple, RippleSettings())
        XCTAssertEqual(decoded.locatorHotKey, HotKeyConfig.defaultLocator)
        XCTAssertEqual(decoded.highlightHotKey, HotKeyConfig.defaultHighlightToggle)
    }

    func testSettingsRoundTrips() throws {
        var s = Settings.default
        s.highlight.isEnabled = true
        s.highlight.diameter = 88
        s.highlight.color = RGBAColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        s.ripple.maxDiameter = 300
        s.locatorHotKey = HotKeyConfig(keyCode: 49, carbonModifiers: HotKeyConfig.optionKey, keyLabel: "Space")
        s.highlightHotKey = HotKeyConfig(keyCode: 2, carbonModifiers: HotKeyConfig.shiftKey, keyLabel: "D")
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, s)
    }
}
