#import "TestSupport.h"
#import "PermissionCapability.h"
#import "PermissionFields.h"
#import "PermissionJudge.h"
#import "TemplateJsonParser.h"

@interface PermissionFieldsTests : XCTestCase
@end

@implementation PermissionFieldsTests

- (void)testWritesCameraStatusOntoPageData {
    JSONObject *data = [[JSONObject alloc] init];
    [PermissionFields write:data result:[PermissionJudge single:[PermissionCapability CAMERA]
                                                         granted:NO
                                                           asked:YES
                                             shouldShowRationale:NO]];

    XCTAssertEqualObjects([PermissionStatus PERMANENTLY_DENIED], [data getString:@"cameraStatus"]);
    XCTAssertEqualObjects(@"已关闭，要到系统设置里打开", [data getString:@"cameraStatusText"]);
    XCTAssertTrue([data getBooleanValue:@"cameraShowSettings"]);
}

- (void)testPhotoGrantStoresTheSelectedUri {
    JSONObject *data = [[JSONObject alloc] init];
    data[@"avatar"] = [JSONValue string:@"res:ic_ava_c"];
    [PermissionFields write:data result:[PermissionJudge grantedPhoto:@"content://media/picker/1"]];

    XCTAssertEqualObjects(@"content://media/picker/1", [data getString:@"photoSrc"]);
    XCTAssertEqualObjects(@"content://media/picker/1", [data getString:@"avatar"]);
    XCTAssertTrue([data getBooleanValue:@"photoVisible"]);
}

- (void)testLaterCheckKeepsTheSelectedPhoto {
    JSONObject *data = [[JSONObject alloc] init];
    data[@"avatar"] = [JSONValue string:@"content://media/picker/1"];
    PermissionResult *kept = [PermissionFields preservingPhoto:data result:[PermissionJudge photosAsked:YES]];

    XCTAssertEqualObjects([PermissionStatus GRANTED], kept.status);
    XCTAssertEqualObjects(@"content://media/picker/1", kept.detail);
}

- (void)testResourceAvatarIsNotTreatedAsAPickedPhoto {
    JSONObject *data = [[JSONObject alloc] init];
    data[@"avatar"] = [JSONValue string:@"res:ic_ava_c"];
    PermissionResult *result = [PermissionFields preservingPhoto:data result:[PermissionJudge photosAsked:NO]];

    XCTAssertEqualObjects([PermissionStatus DENIED], result.status);
    XCTAssertFalse([data containsKey:@"photoSrc"]);
}

- (void)testUnknownCapabilityDoesNotWrite {
    JSONObject *data = [[JSONObject alloc] init];
    [PermissionFields write:data result:[PermissionJudge unsupported:@"sms"]];

    XCTAssertNil([data getString:@"smsStatus"]);
    XCTAssertTrue(data.isEmpty);
}

@end

@interface PermissionJudgeTests : XCTestCase
@end

@implementation PermissionJudgeTests

- (void)testFirstLookIsDeniedAndCanAskAgain {
    PermissionResult *result = [PermissionJudge single:[PermissionCapability CAMERA]
                                                granted:NO
                                                  asked:NO
                                    shouldShowRationale:NO];

    XCTAssertEqualObjects([PermissionStatus DENIED], result.status);
    XCTAssertTrue(result.canAskAgain);
    XCTAssertFalse(result.showSettings);
    XCTAssertEqualObjects(@"还没问过", [result statusText]);
}

- (void)testDenyWithRationaleCanAskAgain {
    PermissionResult *result = [PermissionJudge single:[PermissionCapability MICROPHONE]
                                                granted:NO
                                                  asked:YES
                                    shouldShowRationale:YES];

    XCTAssertEqualObjects([PermissionStatus DENIED], result.status);
    XCTAssertTrue(result.canAskAgain);
    XCTAssertEqualObjects(@"未允许", [result statusText]);
}

- (void)testSecondDenyWithoutRationaleIsPermanent {
    PermissionResult *result = [PermissionJudge single:[PermissionCapability CAMERA]
                                                granted:NO
                                                  asked:YES
                                    shouldShowRationale:NO];

    XCTAssertEqualObjects([PermissionStatus PERMANENTLY_DENIED], result.status);
    XCTAssertFalse(result.canAskAgain);
    XCTAssertTrue(result.showSettings);
    XCTAssertEqualObjects(@"已关闭，要到系统设置里打开", [result statusText]);
}

- (void)testCoarseOnlyLocationIsLimited {
    PermissionResult *result = [PermissionJudge locationWithFineGranted:NO
                                                           coarseGranted:YES
                                                                   asked:YES
                                                          fineShouldShow:YES
                                                        coarseShouldShow:NO];

    XCTAssertEqualObjects([PermissionStatus LIMITED], result.status);
    XCTAssertEqualObjects(@"approximate", result.detail);
    XCTAssertTrue(result.canAskAgain);
    XCTAssertFalse(result.showSettings);
    XCTAssertEqualObjects(@"只给了大致位置", [result statusText]);
}

- (void)testFineLocationIsPrecise {
    PermissionResult *result = [PermissionJudge locationWithFineGranted:YES
                                                           coarseGranted:YES
                                                                   asked:YES
                                                          fineShouldShow:NO
                                                        coarseShouldShow:NO];

    XCTAssertEqualObjects([PermissionStatus GRANTED], result.status);
    XCTAssertEqualObjects(@"已允许，精确位置", [result statusText]);
}

- (void)testNotificationsBeforeRuntimeAreGranted {
    PermissionResult *result = [PermissionJudge notificationsWithRequiresRuntime:NO
                                                                         granted:NO
                                                                           asked:NO
                                                             shouldShowRationale:NO];

    XCTAssertEqualObjects([PermissionStatus GRANTED], result.status);
    XCTAssertEqualObjects(@"已允许", [result statusText]);
}

- (void)testUnknownCapabilityIsUnsupported {
    PermissionResult *result = [PermissionJudge unsupported:@"sms"];

    XCTAssertEqualObjects([PermissionStatus UNSUPPORTED], result.status);
    XCTAssertEqualObjects(@"当前版本没有这项", [result statusText]);
    XCTAssertFalse(result.canAskAgain);
}

@end

@interface PermissionTemplateTests : XCTestCase
@end

@implementation PermissionTemplateTests

- (void)testParsesPermissionPages {
    NSURL *root = OTFirstExistingDirectory(@[
        @"../Demo/src/main/assets",
        @"Demo/src/main/assets"
    ]);
    XCTAssertNotNil(root, @"找不到 Demo 资源目录");
    if (root == nil) {
        return;
    }
    for (NSString *path in @[
        @"templates/permission/permission.json",
        @"templates/market/mine.json",
        @"templates/market/home.json",
        @"templates/market/shop.json",
        @"templates/market/result.json"
    ]) {
        NSURL *file = [root URLByAppendingPathComponent:path];
        XCTAssertTrue(OTIsFile(file.path), @"%@", file.path);
        NSError *readError = nil;
        NSString *text = [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:&readError];
        XCTAssertNil(readError);
        NSError *parseError = nil;
        XCTAssertNotNil([TemplateJsonParser parseJSON:text error:&parseError]);
        XCTAssertNil(parseError);
    }
}

@end
