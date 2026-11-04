#import <XCTest/XCTest.h>
#import "ScreenAdapt.h"

@interface ScreenAdaptTests : XCTestCase
@end

@implementation ScreenAdaptTests

- (void)testDesignWidthStaysAtOne {
    XCTAssertEqualWithAccuracy(1.0, [ScreenAdapt scaleForWindowWidth:375], 0.001);
}

- (void)testCommonPhoneScalesWithWindowWidth {
    XCTAssertEqualWithAccuracy(360.0 / 375.0, [ScreenAdapt scaleForWindowWidth:360], 0.001);
    XCTAssertEqualWithAccuracy(411.0 / 375.0, [ScreenAdapt scaleForWindowWidth:411], 0.001);
}

- (void)testNarrowWindowDoesNotShrinkWithoutLimit {
    XCTAssertEqualWithAccuracy(0.88, [ScreenAdapt scaleForWindowWidth:280], 0.001);
}

- (void)testTabletStopsAtLargePhoneScale {
    XCTAssertEqualWithAccuracy(480.0 / 375.0, [ScreenAdapt scaleForWindowWidth:800], 0.001);
    XCTAssertEqualWithAccuracy(480.0 / 375.0, [ScreenAdapt scaleForWindowWidth:480], 0.001);
}

- (void)testMissingWidthDoesNotScale {
    XCTAssertEqualWithAccuracy(1.0, [ScreenAdapt scaleForWindowWidth:0], 0.001);
}

@end
