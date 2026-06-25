import XCTest
@testable import PointerkunCore

final class HotKeyConfigTests: XCTestCase {
    func testDefaultIsControlCommandP() {
        let c = HotKeyConfig()
        XCTAssertEqual(c.carbonModifiers, HotKeyConfig.controlKey | HotKeyConfig.cmdKey)
        XCTAssertEqual(c.keyLabel, "P")
        XCTAssertEqual(c.displayString, "⌃⌘P")
    }

    func testModifierSymbolsUseAppleOrder() {
        // 表示順は Apple 慣習: ⌃ ⌥ ⇧ ⌘
        let all = HotKeyConfig(
            keyCode: 0,
            carbonModifiers: HotKeyConfig.controlKey | HotKeyConfig.optionKey
                | HotKeyConfig.shiftKey | HotKeyConfig.cmdKey,
            keyLabel: "A"
        )
        XCTAssertEqual(all.modifierSymbols, "⌃⌥⇧⌘")
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘A")
    }

    func testModifierSymbolsSubset() {
        let c = HotKeyConfig(keyCode: 0, carbonModifiers: HotKeyConfig.optionKey | HotKeyConfig.shiftKey, keyLabel: "B")
        XCTAssertEqual(c.modifierSymbols, "⌥⇧")
    }

    func testNoModifiersYieldsEmptySymbols() {
        let c = HotKeyConfig(keyCode: 0, carbonModifiers: 0, keyLabel: "F5")
        XCTAssertEqual(c.modifierSymbols, "")
        XCTAssertEqual(c.displayString, "F5")
    }

    func testRoundTrips() throws {
        let c = HotKeyConfig(keyCode: 35, carbonModifiers: HotKeyConfig.cmdKey, keyLabel: "P")
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(HotKeyConfig.self, from: data), c)
    }
}
