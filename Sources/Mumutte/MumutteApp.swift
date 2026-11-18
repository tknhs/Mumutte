import AppKit
import SwiftUI

@main
struct MumutteApp: App {
    @StateObject private var controller = MumutteController()

    var body: some Scene {
        MenuBarExtra {
            MumutteMenuView(controller: controller)
                .padding(16)
                .frame(width: 320)
        } label: {
            Image(systemName: controller.isMonitoring ? "mic.slash.fill" : "mic.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
