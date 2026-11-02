import XCTest
@testable import OtterCore

final class ScreenAdaptTests: XCTestCase {
    func testDesignWidthStaysAtOne() {
        XCTAssertEqual(Float(1), ScreenAdapt.scaleFor(375), accuracy: 0.001)
    }

    func testCommonPhoneScalesWithWindowWidth() {
        XCTAssertEqual(Float(360) / 375, ScreenAdapt.scaleFor(360), accuracy: 0.001)
        XCTAssertEqual(Float(411) / 375, ScreenAdapt.scaleFor(411), accuracy: 0.001)
    }

    func testNarrowWindowDoesNotShrinkWithoutLimit() {
        XCTAssertEqual(Float(0.88), ScreenAdapt.scaleFor(280), accuracy: 0.001)
    }

    func testTabletStopsAtLargePhoneScale() {
        XCTAssertEqual(Float(480) / 375, ScreenAdapt.scaleFor(800), accuracy: 0.001)
        XCTAssertEqual(Float(480) / 375, ScreenAdapt.scaleFor(480), accuracy: 0.001)
    }

    func testMissingWidthDoesNotScale() {
        XCTAssertEqual(Float(1), ScreenAdapt.scaleFor(0), accuracy: 0.001)
    }
}
