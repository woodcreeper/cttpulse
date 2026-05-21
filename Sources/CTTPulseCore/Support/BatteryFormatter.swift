import Foundation

enum BatteryFormatter {
    static func string(_ value: Double?) -> String {
        guard let value else { return "Battery unknown" }
        return String(format: "%.2f V", value)
    }
}
