import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSnapshot: FinanceSnapshot?

    var body: some View {
        NavigationSplitView {
            List(store.snapshots, selection: $selectedSnapshot) { snapshot in
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.reason)
                        .lineLimit(1)

                    Text(snapshot.createdAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(snapshot)
            }
            .navigationTitle("История")
            .frame(minWidth: 320)
        } detail: {
            if let snapshot = selectedSnapshot {
                SnapshotDetailView(snapshot: snapshot)
            } else {
                ContentUnavailableView(
                    "Выберите снимок",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Здесь можно посмотреть прежнее состояние и при необходимости восстановить его.")
                )
            }
        }
        .frame(minWidth: 940, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
    }
}

private struct SnapshotDetailView: View {
    @EnvironmentObject private var store: FinanceStore
    let snapshot: FinanceSnapshot

    @State private var showingRestoreAlert = false

    var body: some View {
        let totals = snapshotTotals(snapshot)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(snapshot.createdAt.formatted(
                    date: .long,
                    time: .standard
                ))
                .font(.title2.bold())

                Text(snapshot.reason)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    miniCard("Счета", totals.assets)
                    miniCard("Ещё придёт", totals.income)
                    miniCard("Ещё уйдёт", totals.expenses)
                    miniCard("Прогноз", totals.forecast)
                }

                GroupBox("Счета") {
                    VStack(spacing: 8) {
                        ForEach(snapshot.payload.accounts) { account in
                            HStack {
                                Text(account.name)
                                Spacer()
                                Text(AppFormatting.money(account.balance))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("Цели") {
                    VStack(spacing: 8) {
                        if snapshot.payload.goals.isEmpty {
                            Text("Целей в этом состоянии не было.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.payload.goals) { goal in
                                HStack {
                                    Text(goal.title)
                                    Spacer()
                                    Text("\(AppFormatting.money(goal.currentAmount)) / \(AppFormatting.money(goal.targetAmount))")
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("Активные пункты месяца") {
                    VStack(spacing: 8) {
                        ForEach(activeEntries(snapshot)) { entry in
                            HStack {
                                Image(systemName: isCompleted(entry, snapshot) ? "checkmark.circle.fill" : "circle")
                                Text(entry.title)
                                Spacer()
                                Text(entry.kind.rawValue)
                                    .foregroundStyle(.secondary)
                                Text(AppFormatting.money(entry.amount))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(.top, 6)
                }

                Button("Восстановить это состояние") {
                    showingRestoreAlert = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .alert("Восстановить снимок?", isPresented: $showingRestoreAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Восстановить", role: .destructive) {
                store.restore(snapshot)
            }
        } message: {
            Text("Текущее состояние сначала будет автоматически сохранено в истории.")
        }
    }

    private func miniCard(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(AppFormatting.money(value))
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func activeEntries(_ snapshot: FinanceSnapshot) -> [FinanceEntry] {
        snapshot.payload.entries.filter {
            $0.isActive(in: snapshot.payload.selectedMonth)
        }
        .sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind == .income
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func isCompleted(_ entry: FinanceEntry, _ snapshot: FinanceSnapshot) -> Bool {
        let key = EntryStatusKey(
            entryID: entry.id,
            year: snapshot.payload.selectedYear,
            month: snapshot.payload.selectedMonth
        ).stringValue
        return snapshot.payload.completion[key] ?? false
    }

    private func snapshotTotals(_ snapshot: FinanceSnapshot)
    -> (assets: Double, income: Double, expenses: Double, forecast: Double) {
        let assets = snapshot.payload.accounts
            .filter(\.includeInForecast)
            .reduce(0) { $0 + $1.balance }

        let month = snapshot.payload.selectedMonth
        let active = snapshot.payload.entries.filter { $0.isActive(in: month) }

        let income = active
            .filter { $0.kind == .income && !isCompleted($0, snapshot) }
            .reduce(0) { $0 + $1.amount }

        let expenses = active
            .filter { $0.kind == .expense && !isCompleted($0, snapshot) }
            .reduce(0) { $0 + $1.amount }

        return (assets, income, expenses, assets + income - expenses)
    }
}
