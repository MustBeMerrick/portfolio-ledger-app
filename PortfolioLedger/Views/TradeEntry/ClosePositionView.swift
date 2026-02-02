import SwiftUI

struct ClosePositionView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    let position: Position
    let instrument: Instrument

    @State private var closingPrice: String = ""
    @State private var fees: String = ""
    @State private var closeDate: Date = Date()
    @State private var notes: String = ""

    var closingAction: TransactionAction {
        if instrument.type == .option {
            // If position quantity is negative, we're short (sold to open), so we buy to close
            // If position quantity is positive, we're long (bought to open), so we sell to close
            return position.quantity < 0 ? .buyToClose : .sellToClose
        }

        // Equity: sell to close a long, buy to close a short
        return position.quantity < 0 ? .buy : .sell
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Position") {
                    Text(instrument.displayName)
                        .font(.headline)

                    HStack {
                        Text("Quantity:")
                        Spacer()
                        Text(abs(position.quantity).description)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Position:")
                        Spacer()
                        Text(position.quantity < 0 ? "SHORT" : "LONG")
                            .fontWeight(.medium)
                            .foregroundColor(position.quantity < 0 ? .orange : .blue)
                    }
                }

                Section("Close Details") {
                    HStack {
                        Text("Action:")
                        Spacer()
                        Text(actionLabel)
                            .fontWeight(.medium)
                    }

                    TextField(priceFieldLabel, text: $closingPrice)
                        .keyboardType(.decimalPad)

                    TextField("Fees", text: $fees)
                        .keyboardType(.decimalPad)

                    DatePicker("Close Date", selection: $closeDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 60)
                }

                Section {
                    Button("Close Position") {
                        closePosition()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Close Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func closePosition() {
        guard let price = Decimal(string: closingPrice), price >= 0 else {
            return
        }

        let feeAmount = Decimal(string: fees) ?? 0
        let quantity = abs(position.quantity)

        let transaction = Transaction(
            instrumentId: position.instrumentId,
            timestamp: closeDate,
            action: closingAction,
            quantity: quantity,
            price: price,
            fees: feeAmount,
            notes: notes.isEmpty ? "Closed position" : notes,
            tags: ["close"]
        )

        dataStore.addTransaction(transaction)
        dismiss()
    }

    private var actionLabel: String {
        switch closingAction {
        case .buyToClose:
            return "Buy to Close"
        case .sellToClose:
            return "Sell to Close"
        case .buy:
            return "Buy"
        case .sell:
            return "Sell"
        default:
            return closingAction.rawValue.uppercased()
        }
    }

    private var priceFieldLabel: String {
        instrument.type == .option ? "Closing Price per Contract" : "Closing Price per Share"
    }
}

struct ClosePositionView_Previews: PreviewProvider {
    static var previews: some View {
        let instrument = Instrument(
            underlyingSymbol: "MSFT",
            expiry: Date(),
            strike: 500,
            callPut: .call
        )
        let position = Position(
            instrumentId: instrument.id,
            type: .option,
            quantity: -2,
            costBasis: -292,
            averagePrice: 1.46
        )

        return ClosePositionView(position: position, instrument: instrument)
            .environmentObject(DataStore.shared)
    }
}
