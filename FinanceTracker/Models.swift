import Foundation

struct Account: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var balance: Double
    var includeInForecast: Bool = true
}

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case expense = "Расход"
    case income = "Доход"

    var id: String { rawValue }
}

enum EntryRecurrence: String, Codable, CaseIterable, Identifiable {
    case monthly
    case quarterly
    case yearly
    case custom
    case oneTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Каждый месяц"
        case .quarterly: "Раз в квартал"
        case .yearly: "Раз в год"
        case .custom: "Выбранные месяцы"
        case .oneTime: "Один раз"
        }
    }
}

struct FinanceEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var amount: Double
    var kind: EntryKind
    /// 1 = January ... 12 = December. For one-time entries this contains the selected month as well.
    var activeMonths: [Int]
    var recurrence: EntryRecurrence
    var oneTimeYear: Int?
    var oneTimeMonth: Int?
    var note: String

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        kind: EntryKind,
        activeMonths: [Int],
        recurrence: EntryRecurrence? = nil,
        oneTimeYear: Int? = nil,
        oneTimeMonth: Int? = nil,
        note: String = ""
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.kind = kind
        self.activeMonths = Array(Set(activeMonths)).sorted()
        self.recurrence = recurrence ?? Self.inferRecurrence(from: activeMonths)
        self.oneTimeYear = oneTimeYear
        self.oneTimeMonth = oneTimeMonth
        self.note = note
    }

    func isActive(in year: Int, month: Int) -> Bool {
        if recurrence == .oneTime {
            return oneTimeYear == year && oneTimeMonth == month
        }
        return activeMonths.contains(month)
    }

    var recurrenceDescription: String {
        switch recurrence {
        case .monthly:
            return "Каждый месяц"
        case .quarterly:
            return "Раз в квартал · \(monthList(activeMonths))"
        case .yearly:
            return "Раз в год · \(monthList(activeMonths))"
        case .custom:
            return "По месяцам · \(monthList(activeMonths))"
        case .oneTime:
            guard let year = oneTimeYear, let month = oneTimeMonth else {
                return "Один раз"
            }
            return "Один раз · \(Self.monthName(month)) \(year)"
        }
    }

    var isIrregular: Bool {
        recurrence != .monthly
    }

    static func inferRecurrence(from months: [Int]) -> EntryRecurrence {
        let normalized = Array(Set(months)).sorted()
        if normalized == Array(1...12) { return .monthly }
        if normalized.count == 1 { return .yearly }
        if isQuarterlyPattern(normalized) { return .quarterly }
        return .custom
    }

    static func isQuarterlyPattern(_ months: [Int]) -> Bool {
        guard months.count == 4 else { return false }
        let normalized = months.sorted()
        return zip(normalized, normalized.dropFirst()).allSatisfy { lhs, rhs in
            rhs - lhs == 3
        }
    }

    private func monthList(_ months: [Int]) -> String {
        months.sorted().map(Self.shortMonthName).joined(separator: ", ")
    }

    static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        let symbols = formatter.standaloneMonthSymbols ?? formatter.monthSymbols ?? []
        guard symbols.indices.contains(month - 1) else { return "месяц \(month)" }
        return symbols[month - 1].capitalized
    }

    static func shortMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        let symbols = formatter.shortStandaloneMonthSymbols ?? formatter.shortMonthSymbols ?? []
        guard symbols.indices.contains(month - 1) else { return "\(month)" }
        return symbols[month - 1].replacingOccurrences(of: ".", with: "")
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount, kind, activeMonths, recurrence, oneTimeYear, oneTimeMonth, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        kind = try container.decode(EntryKind.self, forKey: .kind)
        activeMonths = try container.decodeIfPresent([Int].self, forKey: .activeMonths) ?? []
        recurrence = try container.decodeIfPresent(EntryRecurrence.self, forKey: .recurrence)
            ?? Self.inferRecurrence(from: activeMonths)
        oneTimeYear = try container.decodeIfPresent(Int.self, forKey: .oneTimeYear)
        oneTimeMonth = try container.decodeIfPresent(Int.self, forKey: .oneTimeMonth)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct SavingsGoal: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date?
    var note: String = ""
    var isArchived: Bool = false

    var remainingAmount: Double {
        max(targetAmount - currentAmount, 0)
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    var isCompleted: Bool {
        currentAmount >= targetAmount && targetAmount > 0
    }
}

struct EntryStatusKey: Codable, Hashable {
    let entryID: UUID
    let year: Int
    let month: Int

    var stringValue: String {
        "\(year)-\(month)-\(entryID.uuidString)"
    }
}

struct SnapshotPayload: Codable, Hashable {
    var accounts: [Account]
    var entries: [FinanceEntry]
    var goals: [SavingsGoal]
    var completion: [String: Bool]
    var selectedYear: Int
    var selectedMonth: Int

    enum CodingKeys: String, CodingKey {
        case accounts, entries, goals, completion, selectedYear, selectedMonth
    }

    init(
        accounts: [Account],
        entries: [FinanceEntry],
        goals: [SavingsGoal],
        completion: [String: Bool],
        selectedYear: Int,
        selectedMonth: Int
    ) {
        self.accounts = accounts
        self.entries = entries
        self.goals = goals
        self.completion = completion
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decode([Account].self, forKey: .accounts)
        entries = try container.decode([FinanceEntry].self, forKey: .entries)
        goals = try container.decodeIfPresent([SavingsGoal].self, forKey: .goals) ?? []
        completion = try container.decode([String: Bool].self, forKey: .completion)
        selectedYear = try container.decode(Int.self, forKey: .selectedYear)
        selectedMonth = try container.decode(Int.self, forKey: .selectedMonth)
    }
}

struct FinanceSnapshot: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var reason: String
    var payload: SnapshotPayload
}

struct FinanceDocument: Codable {
    var accounts: [Account]
    var entries: [FinanceEntry]
    var goals: [SavingsGoal]
    var completion: [String: Bool]
    var selectedYear: Int
    var selectedMonth: Int
    var snapshots: [FinanceSnapshot]

    enum CodingKeys: String, CodingKey {
        case accounts, entries, goals, completion, selectedYear, selectedMonth, snapshots
    }

    init() {
        accounts = [
            Account(name: "Girokonto", balance: 0),
            Account(name: "Наличные", balance: 0),
            Account(name: "Amazon Guthaben", balance: 0),
            Account(name: "PayPal", balance: 0)
        ]

        entries = [
            FinanceEntry(
                title: "Зарплата",
                amount: 0,
                kind: .income,
                activeMonths: Array(1...12),
                recurrence: .monthly
            ),
            FinanceEntry(
                title: "Аренда",
                amount: 0,
                kind: .expense,
                activeMonths: Array(1...12),
                recurrence: .monthly
            )
        ]

        goals = []
        completion = [:]
        selectedYear = Calendar.current.component(.year, from: Date())
        selectedMonth = Calendar.current.component(.month, from: Date())
        snapshots = []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        entries = try container.decodeIfPresent([FinanceEntry].self, forKey: .entries) ?? []
        goals = try container.decodeIfPresent([SavingsGoal].self, forKey: .goals) ?? []
        completion = try container.decodeIfPresent([String: Bool].self, forKey: .completion) ?? [:]
        selectedYear = try container.decodeIfPresent(Int.self, forKey: .selectedYear)
            ?? Calendar.current.component(.year, from: Date())
        selectedMonth = try container.decodeIfPresent(Int.self, forKey: .selectedMonth)
            ?? Calendar.current.component(.month, from: Date())
        snapshots = try container.decodeIfPresent([FinanceSnapshot].self, forKey: .snapshots) ?? []
    }
}
