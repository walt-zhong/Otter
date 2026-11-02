public enum PermissionFields {
    public static func prefix(_ capability: String) -> String? {
        switch capability {
        case PermissionCapability.CAMERA:
            return "camera"
        case PermissionCapability.MICROPHONE:
            return "microphone"
        case PermissionCapability.LOCATION_WHEN_IN_USE:
            return "location"
        case PermissionCapability.PHOTOS:
            return "photos"
        case PermissionCapability.NOTIFICATIONS:
            return "notifications"
        default:
            return nil
        }
    }

    public static func write(_ data: JSONObject, _ result: PermissionResult) {
        guard let key = prefix(result.capability) else {
            return
        }
        data["\(key)Status"] = .string(result.status)
        data["\(key)StatusText"] = .string(result.statusText())
        data["\(key)ShowSettings"] = .bool(result.showSettings)
        if result.capability != PermissionCapability.PHOTOS {
            return
        }
        if result.status == PermissionStatus.GRANTED && result.detail.hasPrefix("content:") {
            data["photoSrc"] = .string(result.detail)
            data["avatar"] = .string(result.detail)
            data["photoVisible"] = .bool(true)
        }
    }

    public static func preservingPhoto(_ data: JSONObject, _ result: PermissionResult) -> PermissionResult {
        if result.capability != PermissionCapability.PHOTOS {
            return result
        }
        if result.status == PermissionStatus.GRANTED && result.detail.hasPrefix("content:") {
            return result
        }
        let saved = [data.getString("photoSrc"), data.getString("avatar")]
            .compactMap { $0 }
            .first { value in
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    value.hasPrefix("content:")
            }
        guard let saved else {
            return result
        }
        return PermissionResult(
            capability: result.capability,
            status: PermissionStatus.GRANTED,
            canAskAgain: true,
            asked: true,
            detail: saved
        )
    }
}
