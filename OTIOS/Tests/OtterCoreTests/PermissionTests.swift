import XCTest
@testable import OtterCore

final class PermissionFieldsTests: XCTestCase {
    func testWritesCameraStatusOntoPageData() {
        let data = JSONObject()
        PermissionFields.write(
            data,
            PermissionJudge.single(
                PermissionCapability.CAMERA,
                granted: false,
                asked: true,
                shouldShowRationale: false
            )
        )

        XCTAssertEqual(PermissionStatus.PERMANENTLY_DENIED, data.getString("cameraStatus"))
        XCTAssertEqual("已关闭，要到系统设置里打开", data.getString("cameraStatusText"))
        XCTAssertTrue(data.getBooleanValue("cameraShowSettings"))
    }

    func testPhotoGrantStoresTheSelectedUri() {
        let data = JSONObject()
        data["avatar"] = .string("res:ic_ava_c")
        PermissionFields.write(
            data,
            PermissionJudge.grantedPhoto("content://media/picker/1")
        )

        XCTAssertEqual("content://media/picker/1", data.getString("photoSrc"))
        XCTAssertEqual("content://media/picker/1", data.getString("avatar"))
        XCTAssertTrue(data.getBooleanValue("photoVisible"))
    }

    func testLaterCheckKeepsTheSelectedPhoto() {
        let data = JSONObject()
        data["avatar"] = .string("content://media/picker/1")
        let kept = PermissionFields.preservingPhoto(data, PermissionJudge.photos(asked: true))

        XCTAssertEqual(PermissionStatus.GRANTED, kept.status)
        XCTAssertEqual("content://media/picker/1", kept.detail)
    }

    func testResourceAvatarIsNotTreatedAsAPickedPhoto() {
        let data = JSONObject()
        data["avatar"] = .string("res:ic_ava_c")
        let result = PermissionFields.preservingPhoto(data, PermissionJudge.photos(asked: false))

        XCTAssertEqual(PermissionStatus.DENIED, result.status)
        XCTAssertFalse(data.containsKey("photoSrc"))
    }

    func testUnknownCapabilityDoesNotWrite() {
        let data = JSONObject()
        PermissionFields.write(data, PermissionJudge.unsupported("sms"))

        XCTAssertNil(data.getString("smsStatus"))
        XCTAssertTrue(data.isEmpty)
    }
}

final class PermissionJudgeTests: XCTestCase {
    func testFirstLookIsDeniedAndCanAskAgain() {
        let result = PermissionJudge.single(
            PermissionCapability.CAMERA,
            granted: false,
            asked: false,
            shouldShowRationale: false
        )

        XCTAssertEqual(PermissionStatus.DENIED, result.status)
        XCTAssertTrue(result.canAskAgain)
        XCTAssertFalse(result.showSettings)
        XCTAssertEqual("还没问过", result.statusText())
    }

    func testDenyWithRationaleCanAskAgain() {
        let result = PermissionJudge.single(
            PermissionCapability.MICROPHONE,
            granted: false,
            asked: true,
            shouldShowRationale: true
        )

        XCTAssertEqual(PermissionStatus.DENIED, result.status)
        XCTAssertTrue(result.canAskAgain)
        XCTAssertEqual("未允许", result.statusText())
    }

    func testSecondDenyWithoutRationaleIsPermanent() {
        let result = PermissionJudge.single(
            PermissionCapability.CAMERA,
            granted: false,
            asked: true,
            shouldShowRationale: false
        )

        XCTAssertEqual(PermissionStatus.PERMANENTLY_DENIED, result.status)
        XCTAssertFalse(result.canAskAgain)
        XCTAssertTrue(result.showSettings)
        XCTAssertEqual("已关闭，要到系统设置里打开", result.statusText())
    }

    func testCoarseOnlyLocationIsLimited() {
        let result = PermissionJudge.location(
            fineGranted: false,
            coarseGranted: true,
            asked: true,
            fineShouldShow: true,
            coarseShouldShow: false
        )

        XCTAssertEqual(PermissionStatus.LIMITED, result.status)
        XCTAssertEqual("approximate", result.detail)
        XCTAssertTrue(result.canAskAgain)
        XCTAssertFalse(result.showSettings)
        XCTAssertEqual("只给了大致位置", result.statusText())
    }

    func testFineLocationIsPrecise() {
        let result = PermissionJudge.location(
            fineGranted: true,
            coarseGranted: true,
            asked: true,
            fineShouldShow: false,
            coarseShouldShow: false
        )

        XCTAssertEqual(PermissionStatus.GRANTED, result.status)
        XCTAssertEqual("已允许，精确位置", result.statusText())
    }

    func testNotificationsBeforeRuntimeAreGranted() {
        let result = PermissionJudge.notifications(
            requiresRuntime: false,
            granted: false,
            asked: false,
            shouldShowRationale: false
        )

        XCTAssertEqual(PermissionStatus.GRANTED, result.status)
        XCTAssertEqual("已允许", result.statusText())
    }

    func testUnknownCapabilityIsUnsupported() {
        let result = PermissionJudge.unsupported("sms")

        XCTAssertEqual(PermissionStatus.UNSUPPORTED, result.status)
        XCTAssertEqual("当前版本没有这项", result.statusText())
        XCTAssertFalse(result.canAskAgain)
    }
}

final class PermissionTemplateTests: XCTestCase {
    func testParsesPermissionPages() throws {
        let root = firstExistingDirectory([
            "../Demo/src/main/assets",
            "Demo/src/main/assets"
        ])
        XCTAssertNotNil(root, "找不到 Demo 资源目录")
        guard let root else { return }
        for path in [
            "templates/permission/permission.json",
            "templates/market/mine.json",
            "templates/market/home.json",
            "templates/market/shop.json",
            "templates/market/result.json"
        ] {
            let file = root.appendingPathComponent(path)
            XCTAssertTrue(isFile(file.path), file.path)
            let text = try String(contentsOf: file, encoding: .utf8)
            _ = try TemplateJsonParser.parse(text)
        }
    }
}
