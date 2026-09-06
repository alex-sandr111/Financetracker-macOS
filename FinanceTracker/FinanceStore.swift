import Foundation
import SwiftUI

@MainActor
final class FinanceStore: ObservableObject {
    @Published private(set) var document: FinanceDocument

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let folder = appSupport.appendingPathComponent(
            "FinanceTracker",
            isDirectory: true
        )

        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        fileURL = folder.appendingPathComponent("finance.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(FinanceDocument.self, from: data) {
            document = decoded
        } else {
            document = FinanceDocument()
            save()
        }
    }

    var selectedYear: Int { document.selectedYear }
    var selectedMonth: Int { document.selectedMonth }
    var lastBalanceUpdatedAt: Date? { document.lastBalanceUpdatedAt }

    var accounts: [Account] { document.accounts }
    var entries: [FinanceEntry] { document.entries }
    var goals: [SavingsGoal] {
        document.goals.sorted {
            if $0.isArchived != $1.isArchived { return !$0.isArchived }
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
    var snapshots: [FinanceSnapshot] { document.snapshots.sorted { $0.createdAt > $1.createdAt } }

    var activeExpenses: [FinanceEntry] {
        document.entries.filter {
            $0.kind == .expense && $0.isActive(in: selectedYear, month: selectedMonth)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var activeIncomes: [FinanceEntry] {
        document.entries.filter {
            $0.kind == .income && $0.isActive(in: selectedYear, month: selectedMonth)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var irregularExpenses: [FinanceEntry] {
        document.entries
            .filter { $0.kind == .expense && $0.isIrregular }
            .sorted { lhs, rhs in
                let rank: (EntryRecurrence) -> Int = { recurrence in
                    switch recurrence {
                    case .oneTime: 0
                    case .quarterly: 1
                    case .yearly: 2
                    case .custom: 3
                    case .monthly: 4
                    }
                }

                if rank(lhs.recurrence) != rank(rhs.recurrence) {
                    return rank(lhs.recurrence) < rank(rhs.recurrence)
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    func remainingIrregularExpenseTotalThisYear(relativeTo date: Date = Date()) -> Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: date)
        let currentMonth = calendar.component(.month, from: date)

        return irregularExpenses.reduce(0) { total, entry in
            let remainingForEntry = (currentMonth...12).reduce(0.0) { subtotal, month in
                guard entry.isActive(in: currentYear, month: month) else {
                    return subtotal
                }

                guard !isCompleted(entry, year: currentYear, month: month) else {
                    return subtotal
                }

                if month == currentMonth {
                    let referenceDate = budgetReferenceDate(
                        forYear: currentYear,
                        month: month,
                        relativeTo: date
                    )
                    return subtotal + entry.remainingExpenseAmount(
                        in: currentYear,
                        month: month,
                        at: referenceDate,
                        calendar: calendar
                    )
                }

                return subtotal + entry.amount
            }

            return total + remainingForEntry
        }
    }

    var totalAssets: Double {
        document.accounts
            .filter(\.includeInForecast)
            .reduce(0) { $0 + $1.balance }
    }

    var remainingExpenses: Double {
        activeExpenses
            .filter { !isCompleted($0) }
            .reduce(0) { $0 + remainingExpenseAmount(for: $1) }
    }

    func remainingExpenseAmount(for entry: FinanceEntry) -> Double {
        guard entry.kind == .expense, !isCompleted(entry) else { return 0 }

        let referenceDate = budgetReferenceDate(
            forYear: selectedYear,
            month: selectedMonth
        )

        return entry.remainingExpenseAmount(
            in: selectedYear,
            month: selectedMonth,
            at: referenceDate
        )
    }

    func remainingExpenseFraction(for entry: FinanceEntry) -> Double {
        guard entry.kind == .expense, !isCompleted(entry) else { return 0 }

        let referenceDate = budgetReferenceDate(
            forYear: selectedYear,
            month: selectedMonth
        )

        return entry.remainingExpenseFraction(
            in: selectedYear,
            month: selectedMonth,
            at: referenceDate
        )
    }

    private func budgetReferenceDate(
        forYear year: Int,
        month: Int,
        relativeTo comparisonDate: Date = Date()
    ) -> Date {
        if let lastBalanceUpdatedAt = document.lastBalanceUpdatedAt {
            return lastBalanceUpdatedAt
        }

        return FinanceEntry.fallbackBudgetReferenceDate(
            forYear: year,
            month: month,
            relativeTo: comparisonDate
        )
    }

    var remainingIncome: Double {
        activeIncomes
            .filter { !isCompleted($0) }
            .reduce(0) { $0 + $1.amount }
    }

    var forecast: Double {
        totalAssets + remainingIncome - remainingExpenses
    }

    var totalGoalTarget: Double {
        document.goals
            .filter { !$0.isArchived }
            .reduce(0) { $0 + $1.targetAmount }
    }

    var totalGoalSaved: Double {
        document.goals
            .filter { !$0.isArchived }
            .reduce(0) { $0 + min($1.currentAmount, $1.targetAmount) }
    }

    func isCompleted(_ entry: FinanceEntry) -> Bool {
        isCompleted(entry, year: selectedYear, month: selectedMonth)
    }

    private func isCompleted(_ entry: FinanceEntry, year: Int, month: Int) -> Bool {
        document.completion[statusKey(for: entry, year: year, month: month)] ?? false
    }

    func toggleCompletion(_ entry: FinanceEntry) {
        captureSnapshot(reason: "\(entry.kind == .expense ? "Оплата" : "Получение"): \(entry.title)")
        let key = statusKey(for: entry)
        document.completion[key] = !(document.completion[key] ?? false)
        persistAndPublish()
    }

    func setMonth(year: Int, month: Int) {
        guard (1...12).contains(month) else { return }
        document.selectedYear = year
        document.selectedMonth = month
        persistAndPublish(makeSnapshot: false)
    }

    func moveMonth(by delta: Int) {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1

        guard let date = Calendar.current.date(from: components),
              let next = Calendar.current.date(byAdding: .month, value: delta, to: date)
        else { return }

        document.selectedYear = Calendar.current.component(.year, from: next)
        document.selectedMonth = Calendar.current.component(.month, from: next)
        persistAndPublish(makeSnapshot: false)
    }

    func addAccount(name: String, balance: Double, includeInForecast: Bool) {
        captureSnapshot(reason: "Добавлен счёт \(name)")
        document.accounts.append(
            Account(name: name, balance: balance, includeInForecast: includeInForecast)
        )
        if includeInForecast {
            document.lastBalanceUpdatedAt = Date()
        }
        persistAndPublish()
    }

    func updateAccount(_ account: Account, name: String, balance: Double, includeInForecast: Bool) {
        guard let index = document.accounts.firstIndex(where: { $0.id == account.id }) else { return }
        captureSnapshot(reason: "Обновлён счёт \(account.name)")
        let affectsForecast = document.accounts[index].includeInForecast || includeInForecast
        document.accounts[index].name = name
        document.accounts[index].balance = balance
        document.accounts[index].includeInForecast = includeInForecast
        if affectsForecast {
            document.lastBalanceUpdatedAt = Date()
        }
        persistAndPublish()
    }

    func deleteAccount(_ account: Account) {
        captureSnapshot(reason: "Удалён счёт \(account.name)")
        document.accounts.removeAll { $0.id == account.id }
        persistAndPublish()
    }

    func addEntry(
        title: String,
        amount: Double,
        kind: EntryKind,
        activeMonths: [Int],
        recurrence: EntryRecurrence,
        oneTimeYear: Int?,
        oneTimeMonth: Int?,
        expenseForecastMode: ExpenseForecastMode,
        note: String
    ) {
        captureSnapshot(reason: "Добавлен \(kind.rawValue.lowercased()) \(title)")
        document.entries.append(
            FinanceEntry(
                title: title,
                amount: amount,
                kind: kind,
                activeMonths: Array(Set(activeMonths)).sorted(),
                recurrence: recurrence,
                oneTimeYear: oneTimeYear,
                oneTimeMonth: oneTimeMonth,
                expenseForecastMode: expenseForecastMode,
                note: note
            )
        )
        persistAndPublish()
    }

    func updateEntry(
        _ entry: FinanceEntry,
        title: String,
        amount: Double,
        kind: EntryKind,
        activeMonths: [Int],
        recurrence: EntryRecurrence,
        oneTimeYear: Int?,
        oneTimeMonth: Int?,
        expenseForecastMode: ExpenseForecastMode,
        note: String
    ) {
        guard let index = document.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        captureSnapshot(reason: "Обновлён \(entry.kind.rawValue.lowercased()) \(entry.title)")
        document.entries[index].title = title
        document.entries[index].amount = amount
        document.entries[index].kind = kind
        document.entries[index].activeMonths = Array(Set(activeMonths)).sorted()
        document.entries[index].recurrence = recurrence
        document.entries[index].oneTimeYear = oneTimeYear
        document.entries[index].oneTimeMonth = oneTimeMonth
        document.entries[index].expenseForecastMode = expenseForecastMode
        document.entries[index].note = note
        persistAndPublish()
    }

    func deleteEntry(_ entry: FinanceEntry) {
        captureSnapshot(reason: "Удалён \(entry.kind.rawValue.lowercased()) \(entry.title)")
        document.entries.removeAll { $0.id == entry.id }
        persistAndPublish()
    }

    func addGoal(
        title: String,
        targetAmount: Double,
        currentAmount: Double,
        targetDate: Date?,
        note: String
    ) {
        captureSnapshot(reason: "Добавлена цель \(title)")
        document.goals.append(
            SavingsGoal(
                title: title,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                targetDate: targetDate,
                note: note
            )
        )
        persistAndPublish()
    }

    func updateGoal(
        _ goal: SavingsGoal,
        title: String,
        targetAmount: Double,
        currentAmount: Double,
        targetDate: Date?,
        note: String,
        isArchived: Bool
    ) {
        guard let index = document.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        captureSnapshot(reason: "Обновлена цель \(goal.title)")
        document.goals[index].title = title
        document.goals[index].targetAmount = targetAmount
        document.goals[index].currentAmount = currentAmount
        document.goals[index].targetDate = targetDate
        document.goals[index].note = note
        document.goals[index].isArchived = isArchived
        persistAndPublish()
    }

    func addToGoal(_ goal: SavingsGoal, amount: Double) {
        guard amount != 0,
              let index = document.goals.firstIndex(where: { $0.id == goal.id })
        else { return }

        captureSnapshot(reason: "Изменён прогресс цели \(goal.title)")
        document.goals[index].currentAmount = max(0, document.goals[index].currentAmount + amount)
        persistAndPublish()
    }

    func deleteGoal(_ goal: SavingsGoal) {
        captureSnapshot(reason: "Удалена цель \(goal.title)")
        document.goals.removeAll { $0.id == goal.id }
        persistAndPublish()
    }

    func makeManualSnapshot(reason: String = "Ручной снимок") {
        captureSnapshot(reason: reason)
        persistAndPublish(makeSnapshot: false)
    }

    func restore(_ snapshot: FinanceSnapshot) {
        captureSnapshot(reason: "Перед восстановлением снимка")
        document.accounts = snapshot.payload.accounts
        document.entries = snapshot.payload.entries
        document.goals = snapshot.payload.goals
        document.completion = snapshot.payload.completion
        document.selectedYear = snapshot.payload.selectedYear
        document.selectedMonth = snapshot.payload.selectedMonth
        document.lastBalanceUpdatedAt = snapshot.payload.lastBalanceUpdatedAt
        persistAndPublish(makeSnapshot: false)
    }

    private func statusKey(for entry: FinanceEntry) -> String {
        statusKey(for: entry, year: selectedYear, month: selectedMonth)
    }

    private func statusKey(for entry: FinanceEntry, year: Int, month: Int) -> String {
        EntryStatusKey(
            entryID: entry.id,
            year: year,
            month: month
        ).stringValue
    }

    private func captureSnapshot(reason: String) {
        let payload = SnapshotPayload(
            accounts: document.accounts,
            entries: document.entries,
            goals: document.goals,
            completion: document.completion,
            selectedYear: document.selectedYear,
            selectedMonth: document.selectedMonth,
            lastBalanceUpdatedAt: document.lastBalanceUpdatedAt
        )

        document.snapshots.append(
            FinanceSnapshot(reason: reason, payload: payload)
        )

        if document.snapshots.count > 500 {
            document.snapshots.removeFirst(document.snapshots.count - 500)
        }
    }

    private func persistAndPublish(makeSnapshot: Bool = false) {
        save()
        objectWillChange.send()
    }

    private func save() {
        guard let data = try? encoder.encode(document) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
