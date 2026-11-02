import XCTest
@testable import OtterCore

final class PageFramesTests: XCTestCase {
    func testPopOnSingleFrameReturnsNullAndKeepsDepth() {
        let frames = PageFrames()
        frames.push("home")

        XCTAssertEqual(1, frames.depth)
        XCTAssertEqual("home", frames.top())
        XCTAssertNil(frames.pop())
        XCTAssertNil(frames.pop())
        XCTAssertEqual(1, frames.depth)
        XCTAssertEqual("home", frames.top())
    }

    func testPopReturnsPushedNameAndRestoresPreviousTop() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        XCTAssertEqual(2, frames.depth)
        XCTAssertEqual("detail", frames.top())
        XCTAssertEqual("detail", frames.pop())
        XCTAssertEqual(1, frames.depth)
        XCTAssertEqual("home", frames.top())
    }

    func testPopOnEmptyStackReturnsNull() {
        let frames = PageFrames()

        XCTAssertEqual(0, frames.depth)
        XCTAssertNil(frames.top())
        XCTAssertNil(frames.pop())
        XCTAssertEqual(0, frames.depth)
    }

    func testClearReturnsRemainingNamesAndEmpties() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        XCTAssertEqual(["home", "detail"], frames.clear())
        XCTAssertEqual(0, frames.depth)
        XCTAssertNil(frames.top())
        XCTAssertNil(frames.pop())
        XCTAssertTrue(frames.clear().isEmpty)
    }

    func testDropRemovesTheOnlyNameAndPopStillRefusesASingleFrame() {
        let frames = PageFrames()
        frames.push("checkout")

        XCTAssertEqual("checkout", frames.drop())
        XCTAssertEqual(0, frames.depth)
        XCTAssertNil(frames.top())
        XCTAssertNil(frames.drop())

        frames.push("checkout")
        XCTAssertEqual(1, frames.depth)
        XCTAssertEqual("checkout", frames.top())
        XCTAssertNil(frames.pop())
        XCTAssertEqual("checkout", frames.top())
    }

    func testDropThenPushReplacesTheTopWithoutKeepingItUnderneath() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("checkout")

        XCTAssertEqual("checkout", frames.drop())
        frames.push("result")

        XCTAssertEqual(2, frames.depth)
        XCTAssertEqual("result", frames.top())
        XCTAssertEqual("result", frames.pop())
        XCTAssertEqual("home", frames.top())
        XCTAssertNil(frames.pop())
    }

    func testPopToMissingNameLeavesTheStackUntouched() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        XCTAssertNil(frames.popTo("missing"))
        XCTAssertEqual(2, frames.depth)
        XCTAssertEqual("detail", frames.top())
        XCTAssertEqual("detail", frames.pop())
        XCTAssertEqual("home", frames.top())
    }

    func testPopToCurrentTopReturnsEmptyAndDoesNotPop() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("detail")

        XCTAssertEqual([] as [String]?, frames.popTo("detail"))
        XCTAssertEqual(2, frames.depth)
        XCTAssertEqual("detail", frames.top())
        XCTAssertNil(frames.popTo(""))
    }

    func testPopToRemovesNamesAboveTheNearestMatchFromTheTopDown() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("list")
        frames.push("detail")
        frames.push("list")
        frames.push("pay")

        XCTAssertEqual(["pay"], frames.popTo("list"))
        XCTAssertEqual(4, frames.depth)
        XCTAssertEqual("list", frames.top())
        XCTAssertEqual("list", frames.pop())
        XCTAssertEqual("detail", frames.top())
    }

    func testPopToDropsIntermediatesUntilTheTargetIncludingTheRoot() {
        let frames = PageFrames()
        frames.push("home")
        frames.push("list")
        frames.push("detail")
        frames.push("checkout")

        XCTAssertEqual(["checkout", "detail", "list"], frames.popTo("home"))
        XCTAssertEqual(1, frames.depth)
        XCTAssertEqual("home", frames.top())
        XCTAssertNil(frames.pop())
        XCTAssertEqual("home", frames.top())
    }
}
