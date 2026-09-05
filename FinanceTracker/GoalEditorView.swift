import SwiftUI

struct GoalEditorView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss

    private let goal: SavingsGoal?

    @State private var title: String
    @State private var targetAmountText: String
    @State private var currentAmountText: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var note: String
    @State private var isArchived: Bool

    init(goal: SavingsGoal? = nil) {
        self.goal = goal
        _title = State(initialValue: goal?.title ?? "")
        _targetAmountText = State(initialValue: goal.map { String(format: "%.2f", $0.targetAmount) } ?? "")
        _currentAmountText = State(initialValue: goal.map { String(format: "%.2f", $0.currentAmount) } ?? "0")
        _hasTargetDate = State(initialValue: goal?.targetDate != nil)
        _targetDate = State(initialValue: goal?.targetDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
        _note = State(initialValue: goal?.note ?? "")
        _isArchived = State(initialValue: goal?.isArchived ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(goal == nil ? "Новая цель" : "Редактировать цель")
                .font(.title2.bold())

            Form {
                TextField("Название", text: $title)
                TextField("Целевая сумма, €", text: $targetAmountText)
                TextField("Уже накоплено, €", text: $currentAmountText)

                Toggle("Установить срок", isOn: $hasTargetDate)

                if hasTargetDate {
                    DatePicker(
                        "Достичь к",
                        selection: $targetDate,
                        displayedComponents: .date
                    )
                }

                TextField("Примечание", text: $note)

                if goal != nil {
                    Toggle("В архиве", isOn: $isArchived)
                }
            }

            HStack {
                if let goal {
                    Button("Удалить", role: .destructive) {
                        store.deleteGoal(goal)
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
        .frame(width: 520)
    }

    private var targetAmount: Double? {
        Double(targetAmountText.replacingOccurrences(of: ",", with: "."))
    }

    private var currentAmount: Double? {
        Double(currentAmountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (targetAmount ?? 0) > 0 &&
        (currentAmount ?? -1) >= 0
    }

    private func save() {
        guard let targetAmount,
              let currentAmount
        else { return }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveDate = hasTargetDate ? targetDate : nil

        if let goal {
            store.updateGoal(
                goal,
                title: cleanedTitle,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                targetDate: effectiveDate,
                note: cleanedNote,
                isArchived: isArchived
            )
        } else {
            store.addGoal(
                title: cleanedTitle,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                targetDate: effectiveDate,
                note: cleanedNote
            )
        }

        dismiss()
    }
}
