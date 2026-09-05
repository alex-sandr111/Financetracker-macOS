import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Обзор"
    case goals = "Цели"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.xaxis"
        case .goals: "target"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: FinanceStore

    @State private var selection: AppSection? = .dashboard
    @State private var showingNewEntry = false
    @State private var showingNewAccount = false
    @State private var showingHistory = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView(showingNewEntry: $showingNewEntry)
                case .goals:
                    GoalsView()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.makeManualSnapshot()
                } label: {
                    Label("Сохранить снимок", systemImage: "camera")
                }

                Button {
                    showingHistory = true
                } label: {
                    Label("История", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingNewAccount) {
            AccountEditorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
                .environmentObject(store)
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(AppSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Месяц") {
                HStack {
                    Button {
                        store.moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()

                    Text(AppFormatting.monthTitle(
                        year: store.selectedYear,
                        month: store.selectedMonth
                    ))
                    .fontWeight(.semibold)

                    Spacer()

                    Button {
                        store.moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderless)
            }

            Section {
                ForEach(store.accounts) { account in
                    AccountRow(account: account)
                }

                Button {
                    showingNewAccount = true
                } label: {
                    Label("Добавить счёт", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Счета")
                    Spacer()
                    Text(AppFormatting.money(store.totalAssets))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Финансы")
        .frame(minWidth: 310)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: FinanceStore
    @Binding var showingNewEntry: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppFormatting.monthTitle(
                    year: store.selectedYear,
                    month: store.selectedMonth
                ))
                .font(.largeTitle.bold())

                HStack(spacing: 12) {
                    SummaryCard(
                        title: "Сейчас на счетах",
                        value: store.totalAssets,
                        systemImage: "wallet.pass"
                    )
                    SummaryCard(
                        title: "Ещё придёт",
                        value: store.remainingIncome,
                        systemImage: "arrow.down.circle"
                    )
                    SummaryCard(
                        title: "Ещё уйдёт",
                        value: store.remainingExpenses,
                        systemImage: "arrow.up.circle"
                    )
                    SummaryCard(
                        title: "Прогноз на конец месяца",
                        value: store.forecast,
                        systemImage: "equal.circle",
                        emphasized: true
                    )
                }

                EntrySection(
                    title: "Доходы",
                    entries: store.activeIncomes,
                    emptyText: "На этот месяц доходы не запланированы."
                )

                EntrySection(
                    title: "Расходы",
                    entries: store.activeExpenses,
                    emptyText: "На этот месяц расходы не запланированы."
                )

                Button {
                    showingNewEntry = true
                } label: {
                    Label("Добавить доход или расход", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: Double
    let systemImage: String
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(emphasized ? .primary : .secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(AppFormatting.money(value))
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(emphasized ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
    }
}

struct EntrySection: View {
    let title: String
    let entries: [FinanceEntry]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2.bold())

            if entries.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        EntryRow(entry: entry)

                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.06))
                )
            }
        }
    }
}

struct EntryRow: View {
    @EnvironmentObject private var store: FinanceStore
    let entry: FinanceEntry

    @State private var showingEdit = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.toggleCompletion(entry)
            } label: {
                Image(systemName: store.isCompleted(entry) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .strikethrough(store.isCompleted(entry))
                    .foregroundStyle(store.isCompleted(entry) ? .secondary : .primary)

                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(AppFormatting.money(entry.amount))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(store.isCompleted(entry) ? .secondary : .primary)

            Button {
                showingEdit = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .sheet(isPresented: $showingEdit) {
            EntryEditorView(entry: entry)
                .environmentObject(store)
        }
    }
}

struct AccountRow: View {
    let account: Account
    @State private var showingEdit = false

    var body: some View {
        Button {
            showingEdit = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                    if !account.includeInForecast {
                        Text("Не входит в прогноз")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(AppFormatting.money(account.balance))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEdit) {
            AccountEditorView(account: account)
        }
    }
}
