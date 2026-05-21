import Foundation

enum TelemetryDateFormatter {
    static func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }

        if let date = makeFractionalFormatter().date(from: value) {
            return date
        }

        return makeStandardFormatter().date(from: value)
    }

    static func apiString(from date: Date) -> String {
        makeStandardFormatter().string(from: date)
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    private static func makeStandardFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    private static func makeFractionalFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
