import XCTest
import CoreGraphics
@testable import PointerkunCore

final class OverlayGeometryTests: XCTestCase {
    func testOriginCentersWindowOnPoint() {
        let origin = OverlayGeometry.originCentered(
            at: CGPoint(x: 100, y: 200),
            size: CGSize(width: 60, height: 40)
        )
        XCTAssertEqual(origin.x, 70, accuracy: 0.0001)
        XCTAssertEqual(origin.y, 180, accuracy: 0.0001)
    }

    func testOriginCenteredCenterRoundTrips() {
        let point = CGPoint(x: 12.5, y: -3)
        let size = CGSize(width: 50, height: 30)
        let origin = OverlayGeometry.originCentered(at: point, size: size)
        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        XCTAssertEqual(center.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(center.y, point.y, accuracy: 0.0001)
    }
}
