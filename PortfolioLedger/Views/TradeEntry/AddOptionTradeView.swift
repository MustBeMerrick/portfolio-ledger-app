import SwiftUI

struct AddOptionTradeView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var underlyingSymbol: String = ""
    @State private var action: TransactionAction = .sellToOpen
    @State private var optionType: OptionType = .call
    @State private var strike: String = ""
    @State private var expiry: Date = Date().addingTimeInterval(30 * 86400) // 30 days from now
    @State private var quantity: String = ""
    @State private var premium: String = ""
    @State private var fees: String = "0"
    @State private var notes: String = ""
    @State private var tradeDate: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section("Option Details") {
                    Picker("Action", selection: $action) {
                        Text("Sell to Open").tag(TransactionAction.sellToOpen)
                        Text("Buy to Open").tag(TransactionAction.buyToOpen)
                        Text("Buy to Close").tag(TransactionAction.buyToClose)
                        Text("Sell to Close").tag(TransactionAction.sellToClose)
                    }

                    TextField("Underlying Symbol", text: $underlyingSymbol)
                        .textInputAutocapitalization(.characters)

                    Picker("Type", selection: $optionType) {
                        Text("Call").tag(OptionType.call)
                        Text("Put").tag(OptionType.put)
                    }
                    .pickerStyle(.segmented)

                    TextField("Strike Price", text: $strike)
                        .keyboardType(.decimalPad)

                    DatePicker("Expiry Date", selection: $expiry, displayedComponents: .date)
                }

                Section("Trade Details") {
                    TextField("Contracts", text: $quantity)
                        .keyboardType(.decimalPad)

                    TextField("Premium per Contract", text: $premium)
                        .keyboardType(.decimalPad)

                    TextField("Fees", text: $fees)
                        .keyboardType(.decimalPad)

                    DatePicker("Trade Date", selection: $tradeDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Option Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTrade()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard !underlyingSymbol.isEmpty,
              let _ = Decimal(string: strike),
              let qty = Decimal(string: quantity), qty > 0,
              let prem = Decimal(string: premium), prem > 0 else {
            return false
        }
        return true
    }

    private func addTrade() {
        guard let stk = Decimal(string: strike),
              let qty = Decimal(string: quantity),
              let prem = Decimal(string: premium) else {
            return
        }

        let feeAmount = Decimal(string: fees) ?? 0

        // Get or create option instrument
        let instrument = dataStore.getOrCreateOptionInstrument(
            underlyingSymbol: underlyingSymbol.uppercased(),
            expiry: expiry,
            strike: stk,
            callPut: optionType
        )

        // Create transaction
        let transaction = Transaction(
            instrumentId: instrument.id,
            timestamp: tradeDate,
            action: action,
            quantity: qty,
            price: prem,
            fees: feeAmount,
            notes: notes
        )

        dataStore.addTransaction(transaction)
        dismiss()
    }
}

struct AddOptionTradeView_Previews: PreviewProvider {
    static var previews: some View {
        AddOptionTradeView()
            .environmentObject(DataStore.shared)
    }
}
