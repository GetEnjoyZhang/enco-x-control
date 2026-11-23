import Foundation

struct BatteryStatus {
    var left: Int?
    var right: Int?
    var caseLevel: Int?
}

enum ANCMode {
    case on
    case off
    case transparency
}

struct LogEntry: Identifiable {
    let id = UUID()
    let kind: Kind
    let text: String
    let date = Date()

    enum Kind: String {
        case tx = "TX"
        case rx = "RX"
        case info = "INFO"
    }
}
