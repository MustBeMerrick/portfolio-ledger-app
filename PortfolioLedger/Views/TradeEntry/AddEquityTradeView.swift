import SwiftUI

struct AddEquityTradeView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var symbol: String = ""
    @State private var action: TransactionAction = .buy
    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var fees: String = "0"
    @State private var notes: String = ""
    @State private var tradeDate: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section("Trade Details") {
                    Picker("Action", selection: $action) {
                        Text("Buy").tag(TransactionAction.buy)
                        Text("Sell").tag(TransactionAction.sell)
                    }
                    .pickerStyle(.segmented)

                    TextField("Symbol", text: $symbol)
                        .textInputAutocapitalization(.characters)

                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)

                    TextField("Price per Share", text: $price)
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
            .navigationTitle(action == .buy ? "Buy Equity" : "Sell Equity")
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
        guard !symbol.isEmpty,
              let qty = Decimal(string: quantity), qty > 0,
              let prc = Decimal(string: price), prc > 0 else {
            return false
        }
        return true
    }

    private func addTrade() {
        guard let qty = Decimal(string: quantity),
              let prc = Decimal(string: price) else {
            return
        }

        let feeAmount = Decimal(string: fees) ?? 0

        // Get or create instrument
        let instrument = dataStore.getOrCreateInstrument(symbol: symbol.uppercased())

        // Create transaction
        let transaction = Transaction(
            instrumentId: instrument.id,
            timestamp: tradeDate,
            action: action,
            quantity: qty,
            price: prc,
            fees: feeAmount,
            notes: notes
        )

        dataStore.addTransaction(transaction)
        dismiss()
    }
}

struct AddEquityTradeView_Previews: PreviewProvider {
    static var previews: some View {
        AddEquityTradeView()
            .environmentObject(DataStore.shared)
    }
}
