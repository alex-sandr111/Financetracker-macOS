import SwiftUI

struct EntryEditorView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss

    private let entry: FinanceEntry?

    @State private var title: String
    @State private var amountText: String
    @State private var kind: EntryKind
    @State private var activeMonths: Set<Int>
    @State private var note: String

    init(entry: FinanceEntry? = nil) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _amountText = State(initialValue: entry.map { String(format: "%.2f", $0.amount) } ?? "")
        _kind = State(initialValue: entry?.kind ?? .expense)
        _activeMonths = State(initialValue: Set(entry?.activeMonths ?? Array(1...12)))
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Периодичность")

                    HStack {
                        Button("Каждый месяц") {
                            activeMonths = Set(1...12)
                        }

                        Button("Раз в квартал") {
                            activeMonths = [1, 4, 7, 10]
                        }

                        Button("Раз в год") {
                            activeMonths = [Calendar.current.component(.month, from: Date())]
                        }

                        Button("Очистить") {
                            activeMonths.removeAll()
                        }
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 8
                    ) {
                        ForEach(1...12, id: \.self) { month in
                            Toggle(monthName(month), isOn: Binding(
                                get: { activeMonths.contains(month) },
                                set: { enabled in
                                    if enabled {
                                        activeMonths.insert(month)
                                    } else {
                                        activeMonths.remove(month)
                                    }
                                }
                            ))
                            .toggleStyle(.button)
                        }
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
        .frame(width: 600)
    }

    private var normalizedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        normalizedAmount != nil &&
        !activeMonths.isEmpty
    }

    private func save() {
        guard let amount = normalizedAmount else { return }

        if let entry {
            store.updateEntry(
                entry,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                kind: kind,
                activeMonths: Array(activeMonths),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            store.addEntry(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                kind: kind,
                activeMonths: Array(activeMonths),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        dismiss()
    }

    private func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        guard symbols.indices.contains(month - 1) else { return "\(month)" }
        return symbols[month - 1].capitalized
    }
}
