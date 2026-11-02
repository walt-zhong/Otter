public enum PermissionCapability {
    public static let CAMERA = "camera"
    public static let MICROPHONE = "microphone"
    public static let LOCATION_WHEN_IN_USE = "location.whenInUse"
    public static let PHOTOS = "photos"
    public static let NOTIFICATIONS = "notifications"

    public static let all: [String] = [
        CAMERA,
        MICROPHONE,
        LOCATION_WHEN_IN_USE,
        PHOTOS,
        NOTIFICATIONS
    ]
}

public enum PermissionStatus {
    public static let GRANTED = "granted"
    public static let DENIED = "denied"
    public static let LIMITED = "limited"
    public static let PERMANENTLY_DENIED = "permanentlyDenied"
    public static let RESTRICTED = "restricted"
    public static let UNSUPPORTED = "unsupported"
}
