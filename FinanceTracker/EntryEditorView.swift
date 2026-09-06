import SwiftUI

struct EntryEditorView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss

    private let entry: FinanceEntry?

    @State private var title: String
    @State private var amountText: String
    @State private var kind: EntryKind
    @State private var recurrence: EntryRecurrence
    @State private var customMonths: Set<Int>
    @State private var quarterlyStartMonth: Int
    @State private var yearlyMonth: Int
    @State private var oneTimeMonth: Int
    @State private var oneTimeYear: Int
    @State private var expenseForecastMode: ExpenseForecastMode
    @State private var note: String

    init(
        entry: FinanceEntry? = nil,
        defaultKind: EntryKind = .expense,
        defaultRecurrence: EntryRecurrence = .monthly
    ) {
        self.entry = entry

        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let existingRecurrence = entry?.recurrence ?? defaultRecurrence
        let defaultMonths: [Int] = {
            switch defaultRecurrence {
            case .monthly:
                Array(1...12)
            case .quarterly:
                [1, 4, 7, 10]
            case .yearly, .custom, .oneTime:
                [currentMonth]
            }
        }()
        let existingMonths = entry?.activeMonths ?? defaultMonths

        _title = State(initialValue: entry?.title ?? "")
        _amountText = State(initialValue: entry.map { String(format: "%.2f", $0.amount) } ?? "")
        _kind = State(initialValue: entry?.kind ?? defaultKind)
        _recurrence = State(initialValue: existingRecurrence)
        _customMonths = State(initialValue: Set(existingMonths))
        _quarterlyStartMonth = State(initialValue: Self.inferQuarterlyStart(from: existingMonths))
        _yearlyMonth = State(initialValue: existingMonths.first ?? currentMonth)
        _oneTimeMonth = State(initialValue: entry?.oneTimeMonth ?? currentMonth)
        _oneTimeYear = State(initialValue: entry?.oneTimeYear ?? currentYear)
        _expenseForecastMode = State(initialValue: entry?.expenseForecastMode ?? .fixed)
        _note = State(initialValue: entry?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(entry == nil ? "Новый пункт" : "Редактировать пункт")
                .font(.title2.bold())

            Form {
                TextField("Название", text: $title)
                TextField("Сумма, €", text: $amountText)

                Picker("Тип", selection: $kind) {
                    ForEach(EntryKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }

                Picker("Периодичность", selection: $recurrence) {
                    ForEach(EntryRecurrence.allCases) { recurrence in
                        Text(recurrence.title).tag(recurrence)
                    }
                }

                recurrenceEditor

                if kind == .expense {
                    Picker("Учёт в прогнозе", selection: $expenseForecastMode) {
                        ForEach(ExpenseForecastMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if expenseForecastMode == .monthlyBudget {
                        Text("Сумма считается месячным бюджетом: 1–7 числа учитывается 100%, 8–14 — 75%, 15–21 — 50%, 22–28 — 25%, с 29-го — 0%. Будущий месяц всегда учитывается полностью.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("Примечание", text: $note)
            }

            HStack {
                if let entry {
                    Button("Удалить", role: .destructive) {
                        store.deleteEntry(entry)
                        dismiss()
                    }
                }

                Spacer()

                Button("Отмена") {
                    dismiss()
                }

                Button("Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 620)
    }

    @ViewBuilder
    private var recurrenceEditor: some View {
        switch recurrence {
        case .monthly:
            LabeledContent("Расписание") {
                Text("Каждый месяц")
                    .foregroundStyle(.secondary)
            }

        case .quarterly:
            Picker("Первый платёж квартального цикла", selection: $quarterlyStartMonth) {
                ForEach(1...3, id: \.self) { month in
                    Text(FinanceEntry.monthName(month)).tag(month)
                }
            }

            LabeledContent("Будет в месяцах") {
                Text(quarterlyMonths.map(FinanceEntry.shortMonthName).joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }

        case .yearly:
            Picker("Месяц", selection: $yearlyMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(FinanceEntry.monthName(month)).tag(month)
                }
            }

        case .custom:
            VStack(alignment: .leading, spacing: 10) {
                Text("Месяцы")

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 4),
                    spacing: 8
                ) {
                    ForEach(1...12, id: \.self) { month in
                        Toggle(FinanceEntry.shortMonthName(month).capitalized, isOn: Binding(
                            get: { customMonths.contains(month) },
                            set: { enabled in
                                if enabled {
                                    customMonths.insert(month)
                                } else {
                                    customMonths.remove(month)
                                }
                            }
                        ))
                        .toggleStyle(.button)
                    }
                }
            }

        case .oneTime:
            Picker("Месяц", selection: $oneTimeMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(FinanceEntry.monthName(month)).tag(month)
                }
            }

            Stepper(value: $oneTimeYear, in: 2000...2100) {
                Text(verbatim: "Год: \(oneTimeYear)")
            }

            Text("Этот пункт появится только в выбранном месяце и не повторится в следующем году.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var quarterlyMonths: [Int] {
        stride(from: quarterlyStartMonth, through: 12, by: 3).map { $0 }
    }

    private var normalizedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              normalizedAmount != nil
        else { return false }

        if recurrence == .custom {
            return !customMonths.isEmpty
        }
        return true
    }

    private func save() {
        guard let amount = normalizedAmount else { return }

        let schedule = effectiveSchedule
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let entry {
            store.updateEntry(
                entry,
                title: cleanedTitle,
                amount: amount,
                kind: kind,
                activeMonths: schedule.months,
                recurrence: recurrence,
                oneTimeYear: schedule.year,
                oneTimeMonth: schedule.month,
                expenseForecastMode: kind == .expense ? expenseForecastMode : .fixed,
                note: cleanedNote
            )
        } else {
            store.addEntry(
                title: cleanedTitle,
                amount: amount,
                kind: kind,
                activeMonths: schedule.months,
                recurrence: recurrence,
                oneTimeYear: schedule.year,
                oneTimeMonth: schedule.month,
                expenseForecastMode: kind == .expense ? expenseForecastMode : .fixed,
                note: cleanedNote
            )
        }

        dismiss()
    }

    private var effectiveSchedule: (months: [Int], year: Int?, month: Int?) {
        switch recurrence {
        case .monthly:
            return (Array(1...12), nil, nil)
        case .quarterly:
            return (quarterlyMonths, nil, nil)
        case .yearly:
            return ([yearlyMonth], nil, nil)
        case .custom:
            return (Array(customMonths).sorted(), nil, nil)
        case .oneTime:
            return ([oneTimeMonth], oneTimeYear, oneTimeMonth)
        }
    }

    private static func inferQuarterlyStart(from months: [Int]) -> Int {
        guard FinanceEntry.isQuarterlyPattern(months), let first = months.sorted().first else {
            return 1
        }
        return min(max(first, 1), 3)
    }
}
