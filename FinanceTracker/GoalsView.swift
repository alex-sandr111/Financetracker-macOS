import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var showingNewGoal = false
    @State private var showArchived = false

    private var visibleGoals: [SavingsGoal] {
        store.goals.filter { showArchived || !$0.isArchived }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Финансовые цели")
                            .font(.largeTitle.bold())
                        Text("Накопления на крупные покупки, резерв и другие планы.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("Показывать архив", isOn: $showArchived)
                        .toggleStyle(.switch)

                    Button {
                        showingNewGoal = true
                    } label: {
                        Label("Новая цель", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if store.totalGoalTarget > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Общий прогресс")
                                .font(.headline)
                            Spacer()
                            Text("\(AppFormatting.money(store.totalGoalSaved)) из \(AppFormatting.money(store.totalGoalTarget))")
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(
                            value: min(store.totalGoalSaved / store.totalGoalTarget, 1)
                        )

                        Text(AppFormatting.percent(min(store.totalGoalSaved / store.totalGoalTarget, 1)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }

                if visibleGoals.isEmpty {
                    ContentUnavailableView(
                        "Целей пока нет",
                        systemImage: "target",
                        description: Text("Создайте первую финансовую цель — например, резерв, отпуск или крупную покупку.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 330), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(visibleGoals) { goal in
                            GoalCard(goal: goal)
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingNewGoal) {
            GoalEditorView()
                .environmentObject(store)
        }
    }
}

private struct GoalCard: View {
    @EnvironmentObject private var store: FinanceStore
    let goal: SavingsGoal

    @State private var showingEdit = false
    @State private var showingContribution = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.title)
                    .font(.title3.bold())
                    .lineLimit(1)

                Spacer()

                if goal.isCompleted {
                    Label("Готово", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if goal.isArchived {
                    Text("Архив")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(AppFormatting.money(goal.currentAmount))
                        .font(.title2.bold())
                        .monospacedDigit()

                    Text("из \(AppFormatting.money(goal.targetAmount))")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(AppFormatting.percent(goal.progress))
                        .fontWeight(.semibold)
                }

                ProgressView(value: goal.progress)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Осталось")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppFormatting.money(goal.remainingAmount))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                Spacer()

                if let targetDate = goal.targetDate {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Срок")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                            .fontWeight(.semibold)
                    }
                }
            }

            if let monthly = monthlyRequired(for: goal),
               goal.remainingAmount > 0 {
                Text("Чтобы успеть к сроку: ≈ \(AppFormatting.money(monthly)) / месяц")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !goal.note.isEmpty {
                Text(goal.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            HStack {
                Button {
                    showingContribution = true
                } label: {
                    Label("Пополнить", systemImage: "plus.circle")
                }
                .disabled(goal.isArchived)

                Spacer()

                Button {
                    showingEdit = true
                } label: {
                    Label("Изменить", systemImage: "pencil")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.07))
        )
        .sheet(isPresented: $showingEdit) {
            GoalEditorView(goal: goal)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingContribution) {
            GoalContributionView(goal: goal)
                .environmentObject(store)
        }
    }

    private func monthlyRequired(for goal: SavingsGoal) -> Double? {
        guard let date = goal.targetDate else { return nil }
        let now = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)

        guard target > now else {
            return goal.remainingAmount
        }

        let months = max(
            Calendar.current.dateComponents([.month], from: now, to: target).month ?? 1,
            1
        )

        return goal.remainingAmount / Double(months)
    }
}

private struct GoalContributionView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal
    @State private var amountText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Пополнить «\(goal.title)»")
                .font(.title2.bold())

            Text("Текущий прогресс: \(AppFormatting.money(goal.currentAmount)) из \(AppFormatting.money(goal.targetAmount))")
                .foregroundStyle(.secondary)

            TextField("Сумма, €", text: $amountText)

            HStack {
                Spacer()

                Button("Отмена") {
                    dismiss()
                }

                Button("Добавить") {
                    if let amount = parsedAmount {
                        store.addToGoal(goal, amount: amount)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedAmount == nil || parsedAmount == 0)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }
}
