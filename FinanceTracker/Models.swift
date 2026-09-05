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

struct FinanceEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var amount: Double
    var kind: EntryKind
    /// 1 = January ... 12 = December.
    var activeMonths: [Int]
    var note: String = ""

    func isActive(in month: Int) -> Bool {
        activeMonths.contains(month)
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
                activeMonths: Array(1...12)
            ),
            FinanceEntry(
                title: "Аренда",
                amount: 0,
                kind: .expense,
                activeMonths: Array(1...12)
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
