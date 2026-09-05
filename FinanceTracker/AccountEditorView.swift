import SwiftUI

struct AccountEditorView: View {
    @EnvironmentObject private var store: FinanceStore
    @Environment(\.dismiss) private var dismiss

    private let account: Account?

    @State private var name: String
    @State private var balanceText: String
    @State private var includeInForecast: Bool

    init(account: Account? = nil) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _balanceText = State(initialValue: account.map { String(format: "%.2f", $0.balance) } ?? "")
        _includeInForecast = State(initialValue: account?.includeInForecast ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(account == nil ? "Новый счёт" : "Редактировать счёт")
                .font(.title2.bold())

            Form {
                TextField("Название", text: $name)
                TextField("Текущий остаток, €", text: $balanceText)
                Toggle("Учитывать в общем прогнозе", isOn: $includeInForecast)
            }

            HStack {
                if let account {
                    Button("Удалить", role: .destructive) {
                        store.deleteAccount(account)
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
        .frame(width: 480)
    }

    private var normalizedBalance: Double? {
        Double(balanceText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        normalizedBalance != nil
    }

    private func save() {
        guard let balance = normalizedBalance else { return }

        if let account {
            store.updateAccount(
                account,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                balance: balance,
                includeInForecast: includeInForecast
            )
        } else {
            store.addAccount(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                balance: balance,
                includeInForecast: includeInForecast
            )
        }

        dismiss()
    }
}
