import AppKit
import SwiftUI

struct MumutteMenuView: View {
    @ObservedObject var controller: MumutteController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mumutte / ミュミュット")
                    .font(.headline)
                Spacer()
                Image(systemName: controller.isMonitoring ? "checkmark.shield.fill" : "shield")
                    .foregroundStyle(controller.isMonitoring ? .green : .secondary)
            }

            Text("対象の入力デバイス")
                .font(.subheadline)

            Picker("対象", selection: Binding(
                get: { controller.selectedUID ?? "" },
                set: { controller.selectDevice(uid: $0) }
            )) {
                Text("選択してください").tag("")
                ForEach(controller.devices) { device in
                    Text(device.name + (device.isControllable ? "" : "（操作不可）"))
                        .tag(device.uid)
                }
            }
            .labelsHidden()
            .disabled(controller.isMonitoring)

            HStack {
                Text("現在の入力ゲイン")
                Spacer()
                if let volume = controller.currentVolume {
                    Text("\(Int((volume * 100).rounded()))%")
                        .monospacedDigit()
                } else {
                    Text("取得できません")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最終確認")
                        .foregroundStyle(.secondary)
                    Text(controller.lastCheckedAt?.formatted(date: .numeric, time: .shortened) ?? "未確認")
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("次回確認")
                        .foregroundStyle(.secondary)
                    Text(controller.nextCheckAt?.formatted(date: .numeric, time: .shortened) ?? "監視停止中")
                        .monospacedDigit()
                }
            }
            .font(.caption)

            Button(controller.isMonitoring ? "監視を停止" : "監視を開始") {
                controller.toggleMonitoring()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!controller.isMonitoring && (controller.selectedUID == nil || !controller.canSetSelectedDevice))
            .frame(maxWidth: .infinity)

            Text(controller.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("開始時に確認し、その後10分ごとに入力ゲインを確認します。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("0%にした履歴（最大10件）")
                .font(.subheadline)

            if controller.recentAdjustments.isEmpty {
                Text("まだ記録はありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(controller.recentAdjustments) { adjustment in
                        HStack(spacing: 8) {
                            Text(adjustment.deviceName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text(adjustment.date.formatted(date: .numeric, time: .shortened))
                                .monospacedDigit()
                        }
                        .font(.caption2)
                    }
                }
            }

            Text("ゲインを下げたときに通知します。初回は通知許可を求めます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Toggle("ログイン時に起動", isOn: Binding(
                get: { controller.launchAtLoginEnabled },
                set: { controller.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)

            if !controller.launchAtLoginMessage.isEmpty {
                Text(controller.launchAtLoginMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if controller.canOpenLoginItemsSettings {
                Button("ログイン項目の設定を開く") {
                    controller.openLoginItemsSettings()
                }
            }

            Text("監視中に終了した場合、次回起動時に監視を再開します。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("終了") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")

            HStack {
                Spacer()
                Text("v\(appVersion)+\(appCommit)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            controller.refreshLaunchAtLoginStatus()
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var appCommit: String {
        Bundle.main.infoDictionary?["MumutteCommit"] as? String ?? "none"
    }
}
