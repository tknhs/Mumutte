import Foundation

struct GainAdjustment: Codable, Identifiable {
    let id: UUID
    let deviceName: String
    let date: Date

    init(deviceName: String, date: Date = Date()) {
        self.id = UUID()
        self.deviceName = deviceName
        self.date = date
    }
}
