import Combine
import Foundation
import ServiceManagement

@MainActor
final class MumutteController: ObservableObject {
    @Published private(set) var devices: [AudioInputDevice] = []
    @Published private(set) var selectedUID: String?
    @Published private(set) var currentVolume: Float?
    @Published private(set) var canSetSelectedDevice = false
    @Published private(set) var isMonitoring = false
    @Published private(set) var status = "入力デバイスを選択してください。"
    @Published private(set) var recentAdjustments: [GainAdjustment] = []
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var nextCheckAt: Date?
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginNeedsApproval = false
    @Published private(set) var canOpenLoginItemsSettings = false
    @Published private(set) var launchAtLoginMessage = ""

    private let deviceStore = CoreAudioDeviceStore()
    private var monitorTask: Task<Void, Never>?
    private let selectedDeviceKey = "selectedInputDeviceUID"
    private let monitoringEnabledKey = "monitoringEnabled"
    private let adjustmentHistoryKey = "recentGainAdjustments"
    private let lastCheckedAtKey = "lastMonitoringCheckDate"
    private static let checkIntervalSeconds: Int64 = 10 * 60
    private let notifier = GainResetNotifier()

    init() {
        selectedUID = UserDefaults.standard.string(forKey: selectedDeviceKey)
        lastCheckedAt = UserDefaults.standard.object(forKey: lastCheckedAtKey) as? Date
        if let data = UserDefaults.standard.data(forKey: adjustmentHistoryKey),
           let history = try? JSONDecoder().decode([GainAdjustment].self, from: data) {
            recentAdjustments = Array(history.prefix(10))
        }
        refreshDevices()
        updateCurrentReading()
        refreshLaunchAtLoginStatus()

        if UserDefaults.standard.bool(forKey: monitoringEnabledKey) {
            startMonitoring()
        }
    }

    func selectDevice(uid: String) {
        selectedUID = uid.isEmpty ? nil : uid
        if let selectedUID {
            UserDefaults.standard.set(selectedUID, forKey: selectedDeviceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedDeviceKey)
        }

        refreshDevices()
        updateCurrentReading()
        if isMonitoring {
            enforceMinimum()
        }
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }

            refreshLaunchAtLoginStatus()
            if enabled && launchAtLoginNeedsApproval {
                launchAtLoginMessage = "登録しました。システム設定で起動を許可してください。"
            } else if enabled && launchAtLoginEnabled {
                launchAtLoginMessage = "次回ログイン時から起動します。"
            } else if !enabled {
                launchAtLoginMessage = "ログイン時の自動起動を停止しました。"
            }
        } catch {
            refreshLaunchAtLoginStatus()
            canOpenLoginItemsSettings = true
            launchAtLoginMessage = "自動起動を変更できませんでした: \(error.localizedDescription)"
        }
    }

    func refreshLaunchAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginNeedsApproval = false
            canOpenLoginItemsSettings = false
            launchAtLoginMessage = ""
        case .requiresApproval:
            launchAtLoginEnabled = true
            launchAtLoginNeedsApproval = true
            canOpenLoginItemsSettings = true
            launchAtLoginMessage = "システム設定でログイン時の起動を許可してください。"
        case .notRegistered:
            launchAtLoginEnabled = false
            launchAtLoginNeedsApproval = false
            canOpenLoginItemsSettings = false
            launchAtLoginMessage = ""
        case .notFound:
            launchAtLoginEnabled = false
            launchAtLoginNeedsApproval = false
            canOpenLoginItemsSettings = true
            launchAtLoginMessage = "ログイン項目を確認できません。"
        @unknown default:
            launchAtLoginEnabled = false
            launchAtLoginNeedsApproval = false
            canOpenLoginItemsSettings = true
            launchAtLoginMessage = "ログイン項目の状態を確認できません。"
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func startMonitoring() {
        refreshDevices()
        updateCurrentReading()

        guard selectedUID != nil else {
            status = "先に入力デバイスを選択してください。"
            return
        }
        guard canSetSelectedDevice else {
            status = "このデバイスは入力ゲインを変更できません。"
            return
        }

        isMonitoring = true
        UserDefaults.standard.set(true, forKey: monitoringEnabledKey)
        enforceMinimum()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Self.checkIntervalSeconds))
                } catch {
                    break
                }
                guard !Task.isCancelled, let self else { break }
                self.enforceMinimum()
            }
        }
    }

    private func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
        nextCheckAt = nil
        UserDefaults.standard.set(false, forKey: monitoringEnabledKey)
        status = "監視を停止しました。"
    }

    private func refreshDevices() {
        devices = deviceStore.inputDevices()
    }

    private func updateCurrentReading() {
        guard let selectedUID else {
            currentVolume = nil
            canSetSelectedDevice = false
            status = "入力デバイスを選択してください。"
            return
        }

        guard let device = devices.first(where: { $0.uid == selectedUID }) else {
            currentVolume = nil
            canSetSelectedDevice = false
            status = "選択したデバイスが見つかりません。接続を確認してください。"
            return
        }

        currentVolume = device.volumeScalar
        canSetSelectedDevice = device.isControllable

        if device.volumeScalar == nil {
            status = "このデバイスから入力ゲインを取得できません。"
        } else if !device.isVolumeSettable {
            status = "このデバイスは入力ゲインを変更できません。"
        } else if !isMonitoring {
            status = "監視を開始できます。"
        }
    }

    private func enforceMinimum() {
        let checkedAt = Date()
        lastCheckedAt = checkedAt
        UserDefaults.standard.set(checkedAt, forKey: lastCheckedAtKey)
        nextCheckAt = isMonitoring
            ? checkedAt.addingTimeInterval(TimeInterval(Self.checkIntervalSeconds))
            : nil

        refreshDevices()

        guard let selectedUID,
              let device = devices.first(where: { $0.uid == selectedUID }) else {
            currentVolume = nil
            canSetSelectedDevice = false
            status = "選択したデバイスが見つかりません。接続を確認してください。"
            return
        }

        currentVolume = device.volumeScalar
        canSetSelectedDevice = device.isControllable

        guard let volume = device.volumeScalar else {
            status = "このデバイスから入力ゲインを取得できません。"
            return
        }
        guard device.isVolumeSettable else {
            status = "このデバイスは入力ゲインを変更できません。"
            return
        }

        if volume > 0.001 {
            let result = deviceStore.setInputVolume(0, on: device.objectID)
            if result == noErr {
                let adjustment = GainAdjustment(deviceName: device.name)
                recentAdjustments.insert(adjustment, at: 0)
                if recentAdjustments.count > 10 {
                    recentAdjustments = Array(recentAdjustments.prefix(10))
                }
                if let data = try? JSONEncoder().encode(recentAdjustments) {
                    UserDefaults.standard.set(data, forKey: adjustmentHistoryKey)
                }
                notifier.notifyGainReset(deviceName: device.name)

                refreshDevices()
                updateCurrentReading()
                status = "入力ゲインが上がったため、最小値に戻しました。"
            } else {
                status = "最小値に変更できませんでした（Core Audio: \(result)）。"
            }
        } else {
            status = "監視中です。入力ゲインは最小値です。"
        }
    }
}
