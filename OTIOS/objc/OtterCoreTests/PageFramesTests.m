#import <XCTest/XCTest.h>
#import "PageFrames.h"

@interface PageFramesTests : XCTestCase
@end

@implementation PageFramesTests

- (void)testPopOnSingleFrameReturnsNullAndKeepsDepth {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];

    XCTAssertEqual(1, frames.depth);
    XCTAssertEqualObjects(@"home", [frames top]);
    XCTAssertNil([frames pop]);
    XCTAssertNil([frames pop]);
    XCTAssertEqual(1, frames.depth);
    XCTAssertEqualObjects(@"home", [frames top]);
}

- (void)testPopReturnsPushedNameAndRestoresPreviousTop {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"detail"];

    XCTAssertEqual(2, frames.depth);
    XCTAssertEqualObjects(@"detail", [frames top]);
    XCTAssertEqualObjects(@"detail", [frames pop]);
    XCTAssertEqual(1, frames.depth);
    XCTAssertEqualObjects(@"home", [frames top]);
}

- (void)testPopOnEmptyStackReturnsNull {
    PageFrames *frames = [[PageFrames alloc] init];

    XCTAssertEqual(0, frames.depth);
    XCTAssertNil([frames top]);
    XCTAssertNil([frames pop]);
    XCTAssertEqual(0, frames.depth);
}

- (void)testClearReturnsRemainingNamesAndEmpties {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"detail"];

    XCTAssertEqualObjects((@[@"home", @"detail"]), [frames clear]);
    XCTAssertEqual(0, frames.depth);
    XCTAssertNil([frames top]);
    XCTAssertNil([frames pop]);
    XCTAssertEqual(0, [frames clear].count);
}

- (void)testDropRemovesTheOnlyNameAndPopStillRefusesASingleFrame {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"checkout"];

    XCTAssertEqualObjects(@"checkout", [frames drop]);
    XCTAssertEqual(0, frames.depth);
    XCTAssertNil([frames top]);
    XCTAssertNil([frames drop]);

    [frames push:@"checkout"];
    XCTAssertEqual(1, frames.depth);
    XCTAssertEqualObjects(@"checkout", [frames top]);
    XCTAssertNil([frames pop]);
    XCTAssertEqualObjects(@"checkout", [frames top]);
}

- (void)testDropThenPushReplacesTheTopWithoutKeepingItUnderneath {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"checkout"];

    XCTAssertEqualObjects(@"checkout", [frames drop]);
    [frames push:@"result"];

    XCTAssertEqual(2, frames.depth);
    XCTAssertEqualObjects(@"result", [frames top]);
    XCTAssertEqualObjects(@"result", [frames pop]);
    XCTAssertEqualObjects(@"home", [frames top]);
    XCTAssertNil([frames pop]);
}

- (void)testPopToMissingNameLeavesTheStackUntouched {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"detail"];

    XCTAssertNil([frames popTo:@"missing"]);
    XCTAssertEqual(2, frames.depth);
    XCTAssertEqualObjects(@"detail", [frames top]);
    XCTAssertEqualObjects(@"detail", [frames pop]);
    XCTAssertEqualObjects(@"home", [frames top]);
}

- (void)testPopToCurrentTopReturnsEmptyAndDoesNotPop {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"detail"];

    XCTAssertEqualObjects(@[], [frames popTo:@"detail"]);
    XCTAssertEqual(2, frames.depth);
    XCTAssertEqualObjects(@"detail", [frames top]);
    XCTAssertNil([frames popTo:@""]);
}

- (void)testPopToRemovesNamesAboveTheNearestMatchFromTheTopDown {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"list"];
    [frames push:@"detail"];
    [frames push:@"list"];
    [frames push:@"pay"];

    XCTAssertEqualObjects(@[@"pay"], [frames popTo:@"list"]);
    XCTAssertEqual(4, frames.depth);
    XCTAssertEqualObjects(@"list", [frames top]);
    XCTAssertEqualObjects(@"list", [frames pop]);
    XCTAssertEqualObjects(@"detail", [frames top]);
}

- (void)testPopToDropsIntermediatesUntilTheTargetIncludingTheRoot {
    PageFrames *frames = [[PageFrames alloc] init];
    [frames push:@"home"];
    [frames push:@"list"];
    [frames push:@"detail"];
    [frames push:@"checkout"];

    XCTAssertEqualObjects((@[@"checkout", @"detail", @"list"]), [frames popTo:@"home"]);
    XCTAssertEqual(1, frames.depth);
    XCTAssertEqualObjects(@"home", [frames top]);
    XCTAssertNil([frames pop]);
    XCTAssertEqualObjects(@"home", [frames top]);
}

@end
