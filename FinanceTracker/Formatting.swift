import Foundation

enum AppFormatting {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func money(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static func monthTitle(year: Int, month: Int) -> String {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = 1
        guard let d = Calendar.current.date(from: c) else {
            return "\(month)/\(year)"
        }
        return monthFormatter.string(from: d).capitalized
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
