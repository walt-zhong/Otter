import AVFoundation
import CoreLocation
import OtterCore
import PhotosUI
import UIKit
import UserNotifications

public final class OTPermissionCenter: NSObject, CLLocationManagerDelegate, PHPickerViewControllerDelegate {
    public static let check = PermissionActions.CHECK
    public static let request = PermissionActions.REQUEST
    public static let openSettings = PermissionActions.OPEN_SETTINGS

    private let host: UIViewController
    private let prompts: [String: PermissionPrompt]
    private var released = false
    private var inFlight = false
    private var pending: ((PermissionResult) -> Void)?
    private var pendingCapability: String?
    private let location = CLLocationManager()
    private var locationAsked = false
    private var notificationCache = PermissionJudge.notifications(requiresRuntime: true, granted: false, asked: false, shouldShowRationale: true)

    public static func install(host: UIViewController, prompts: [String: PermissionPrompt] = PermissionPrompts.standard()) -> OTPermissionCenter {
        if let existing = installed[ObjectIdentifier(host)], !existing.released { return existing }
        let created = OTPermissionCenter(host: host, prompts: prompts)
        installed[ObjectIdentifier(host)] = created
        created.register()
        return created
    }

    public static func find(_ view: UIView) -> OTPermissionCenter? {
        guard let host = view.ot_controller else { return nil }
        let center = installed[ObjectIdentifier(host)]
        if center?.released == true { return nil }
        return center
    }

    public func releaseCenter() {
        released = true
        pending = nil
        inFlight = false
        OTPermissionCenter.installed.removeValue(forKey: ObjectIdentifier(host))
    }

    private static var installed: [ObjectIdentifier: OTPermissionCenter] = [:]

    private init(host: UIViewController, prompts: [String: PermissionPrompt]) {
        self.host = host
        self.prompts = prompts
        super.init()
        location.delegate = self
        refreshNotifications()
    }

    private func register() {
        let center = ExpansionCenter.shared
        center.registerHostAction(Self.check) { [weak self] view, params in
            self?.one(view, params, .check)
        }
        center.registerHostAction(Self.request) { [weak self] view, params in
            self?.one(view, params, .request)
        }
        center.registerHostAction(Self.openSettings) { [weak self] view, params in
            self?.one(view, params, .settings)
        }
    }

    public func publishAll(_ view: UIView) {
        guard let stack = PageStack.find(view) else { return }
        let results = PermissionCapability.all.map { check($0) }
        stack.editCurrentData { data in
            for result in results {
                PermissionFields.write(data, PermissionFields.preservingPhoto(data, result))
            }
        }
        stack.rebindCurrent()
    }

    private enum Mode { case check, request, settings }

    private func one(_ view: UIView, _ params: JSONObject?, _ mode: Mode) {
        let capability = params?.getString("capability") ?? ""
        if capability.isEmpty || PermissionFields.prefix(capability) == nil {
            OTToast.show("没有这项能力", in: view)
            return
        }
        guard OTPermissionCenter.find(view) != nil else {
            OTToast.show("这个操作还不能用", in: view)
            return
        }
        switch mode {
        case .check:
            publish(view, check(capability))
        case .request:
            request(capability) { [weak self] result in self?.publish(view, result) }
        case .settings:
            openSettings(capability) { [weak self] result in self?.publish(view, result) }
        }
    }

    private func publish(_ view: UIView, _ result: PermissionResult) {
        guard let stack = PageStack.find(view) else {
            OTToast.show("这个页面还接不上", in: view)
            return
        }
        stack.editCurrentData { data in
            PermissionFields.write(data, PermissionFields.preservingPhoto(data, result))
        }
        stack.rebindCurrent()
    }

    public func check(_ capability: String) -> PermissionResult {
        if capability == PermissionCapability.PHOTOS {
            return PermissionJudge.photos(asked: asked(capability))
        }
        if !PermissionCapability.all.contains(capability) || !hardware(capability) {
            return PermissionJudge.unsupported(capability)
        }
        switch capability {
        case PermissionCapability.CAMERA:
            return singleStatus(capability, AVCaptureDevice.authorizationStatus(for: .video))
        case PermissionCapability.MICROPHONE:
            return microphoneStatus()
        case PermissionCapability.LOCATION_WHEN_IN_USE:
            return locationStatus()
        case PermissionCapability.NOTIFICATIONS:
            return notificationStatus()
        default:
            return PermissionJudge.unsupported(capability)
        }
    }

    private func request(_ capability: String, _ onResult: @escaping (PermissionResult) -> Void) {
        if inFlight || released { return }
        let current = check(capability)
        if !shouldPrompt(current) {
            onResult(current)
            return
        }
        let prompt = prompts[capability] ?? PermissionPrompt(title: "权限", message: "接下来会弹出系统对话框，你可以拒绝。")
        inFlight = true
        let alert = UIAlertController(title: prompt.title, message: prompt.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "继续", style: .default) { [weak self] _ in
            self?.launch(capability, onResult)
        })
        alert.addAction(UIAlertAction(title: "先不用", style: .cancel) { [weak self] _ in
            self?.inFlight = false
        })
        host.present(alert, animated: true)
    }

    private func openSettings(_ capability: String, _ onResult: @escaping (PermissionResult) -> Void) {
        if inFlight || released { return }
        inFlight = true
        pending = onResult
        pendingCapability = capability
        markAsked(capability)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            finish(check(capability))
            return
        }
        UIApplication.shared.open(url) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.finish(self.check(capability))
            }
        }
    }

    private func launch(_ capability: String, _ onResult: @escaping (PermissionResult) -> Void) {
        pending = onResult
        pendingCapability = capability
        switch capability {
        case PermissionCapability.PHOTOS:
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            host.present(picker, animated: true)
        case PermissionCapability.CAMERA:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.markAsked(capability)
                    self?.finish(self?.check(capability) ?? PermissionJudge.unsupported(capability))
                }
            }
        case PermissionCapability.MICROPHONE:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] _ in
                DispatchQueue.main.async {
                    self?.markAsked(capability)
                    self?.finish(self?.check(capability) ?? PermissionJudge.unsupported(capability))
                }
            }
        case PermissionCapability.LOCATION_WHEN_IN_USE:
            locationAsked = true
            markAsked(capability)
            location.requestWhenInUseAuthorization()
        case PermissionCapability.NOTIFICATIONS:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.markAsked(capability)
                    self?.finish(self?.check(capability) ?? PermissionJudge.unsupported(capability))
                }
            }
        default:
            finish(check(capability))
        }
    }

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        markAsked(PermissionCapability.PHOTOS)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            finish(PermissionJudge.photos(asked: true))
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.9) else {
                    self.finish(PermissionJudge.photos(asked: true))
                    return
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("otter-photo-\(UUID().uuidString).jpg")
                do {
                    try data.write(to: url)
                    self.finish(PermissionJudge.grantedPhoto("content:\(url.path)"))
                } catch {
                    self.finish(PermissionJudge.photos(asked: true))
                }
            }
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locationAsked || pendingCapability == PermissionCapability.LOCATION_WHEN_IN_USE else { return }
        markAsked(PermissionCapability.LOCATION_WHEN_IN_USE)
        finish(check(PermissionCapability.LOCATION_WHEN_IN_USE))
    }

    private func finish(_ result: PermissionResult) {
        let callback = pending
        pending = nil
        pendingCapability = nil
        inFlight = false
        locationAsked = false
        callback?(result)
    }

    private func shouldPrompt(_ current: PermissionResult) -> Bool {
        if current.status == PermissionStatus.UNSUPPORTED || current.status == PermissionStatus.RESTRICTED || current.status == PermissionStatus.GRANTED || current.status == PermissionStatus.PERMANENTLY_DENIED {
            return false
        }
        if current.status == PermissionStatus.LIMITED && !current.canAskAgain { return false }
        return current.canAskAgain
    }

    private func singleStatus(_ capability: String, _ status: AVAuthorizationStatus) -> PermissionResult {
        switch status {
        case .authorized:
            return PermissionJudge.single(capability, granted: true, asked: asked(capability), shouldShowRationale: false)
        case .notDetermined:
            return PermissionJudge.single(capability, granted: false, asked: false, shouldShowRationale: true)
        case .restricted:
            return PermissionResult(capability: capability, status: PermissionStatus.RESTRICTED, canAskAgain: false, asked: asked(capability))
        case .denied:
            return PermissionJudge.single(capability, granted: false, asked: true, shouldShowRationale: false)
        @unknown default:
            return PermissionJudge.unsupported(capability)
        }
    }

    private func microphoneStatus() -> PermissionResult {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return PermissionJudge.single(PermissionCapability.MICROPHONE, granted: true, asked: asked(PermissionCapability.MICROPHONE), shouldShowRationale: false)
        case .undetermined:
            return PermissionJudge.single(PermissionCapability.MICROPHONE, granted: false, asked: false, shouldShowRationale: true)
        case .denied:
            return PermissionJudge.single(PermissionCapability.MICROPHONE, granted: false, asked: true, shouldShowRationale: false)
        @unknown default:
            return PermissionJudge.unsupported(PermissionCapability.MICROPHONE)
        }
    }

    private func locationStatus() -> PermissionResult {
        if !CLLocationManager.locationServicesEnabled() {
            return PermissionJudge.unsupported(PermissionCapability.LOCATION_WHEN_IN_USE)
        }
        let status = location.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            let precise = location.accuracyAuthorization == .fullAccuracy
            return PermissionJudge.location(fineGranted: precise, coarseGranted: !precise, asked: asked(PermissionCapability.LOCATION_WHEN_IN_USE), fineShouldShow: false, coarseShouldShow: false)
        case .notDetermined:
            return PermissionJudge.single(PermissionCapability.LOCATION_WHEN_IN_USE, granted: false, asked: false, shouldShowRationale: true)
        case .restricted:
            return PermissionResult(capability: PermissionCapability.LOCATION_WHEN_IN_USE, status: PermissionStatus.RESTRICTED, canAskAgain: false, asked: asked(PermissionCapability.LOCATION_WHEN_IN_USE))
        case .denied:
            return PermissionJudge.single(PermissionCapability.LOCATION_WHEN_IN_USE, granted: false, asked: true, shouldShowRationale: false)
        @unknown default:
            return PermissionJudge.unsupported(PermissionCapability.LOCATION_WHEN_IN_USE)
        }
    }

    private func notificationStatus() -> PermissionResult {
        refreshNotifications()
        return notificationCache
    }

    private func refreshNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let asked = self.asked(PermissionCapability.NOTIFICATIONS)
            let next: PermissionResult
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                next = PermissionJudge.notifications(requiresRuntime: true, granted: true, asked: asked, shouldShowRationale: false)
            case .notDetermined:
                next = PermissionJudge.notifications(requiresRuntime: true, granted: false, asked: false, shouldShowRationale: true)
            case .denied:
                next = PermissionJudge.notifications(requiresRuntime: true, granted: false, asked: true, shouldShowRationale: false)
            default:
                next = PermissionJudge.unsupported(PermissionCapability.NOTIFICATIONS)
            }
            DispatchQueue.main.async { self.notificationCache = next }
        }
    }

    private func hardware(_ capability: String) -> Bool {
        switch capability {
        case PermissionCapability.CAMERA:
            return AVCaptureDevice.default(for: .video) != nil
        case PermissionCapability.MICROPHONE:
            return AVAudioSession.sharedInstance().isInputAvailable
        case PermissionCapability.LOCATION_WHEN_IN_USE:
            return CLLocationManager.locationServicesEnabled()
        default:
            return true
        }
    }

    private func asked(_ capability: String) -> Bool {
        UserDefaults.standard.bool(forKey: "otter.permission.\(capability)")
    }

    private func markAsked(_ capability: String) {
        UserDefaults.standard.set(true, forKey: "otter.permission.\(capability)")
    }
}
