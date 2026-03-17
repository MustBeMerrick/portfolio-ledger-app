import SwiftUI

struct ClosePositionView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    let position: Position
    let instrument: Instrument
    let closeQuantity: Decimal

    @State private var closingPrice: String = ""
    @State private var fees: String = ""
    @State private var closeDate: Date = Date()
    @State private var notes: String = ""
    @State private var selectedOptionAction: TransactionAction

    init(position: Position, instrument: Instrument, closeQuantity: Decimal? = nil) {
        self.position = position
        self.instrument = instrument
        self.closeQuantity = closeQuantity ?? abs(position.quantity)
        // Default option closing action based on position side
        let defaultAction: TransactionAction = position.quantity < 0 ? .buyToClose : .sellToClose
        _selectedOptionAction = State(initialValue: defaultAction)
    }

    var closingAction: TransactionAction {
        if instrument.type == .option {
            return selectedOptionAction
        }
        // Equity: sell to close a long, buy to close a short
        return position.quantity < 0 ? .buy : .sell
    }

    private var optionClosingActions: [TransactionAction] {
        let marketClose: TransactionAction = position.quantity < 0 ? .buyToClose : .sellToClose
        return [marketClose, .expire, .assign]
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
                        Text(closeQuantity.description)
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
                    if instrument.type == .option {
                        Picker("Action", selection: $selectedOptionAction) {
                            ForEach(optionClosingActions, id: \.self) { action in
                                Text(labelFor(action)).tag(action)
                            }
                        }
                    } else {
                        HStack {
                            Text("Action:")
                            Spacer()
                            Text(actionLabel)
                                .fontWeight(.medium)
                        }
                    }

                    if closingAction != .expire && closingAction != .assign {
                        TextField(priceFieldLabel, text: $closingPrice)
                            .keyboardType(.decimalPad)

                        TextField("Fees", text: $fees)
                            .keyboardType(.decimalPad)
                    }

                    if closingAction != .expire && closingAction != .assign {
                        DatePicker("Close Date", selection: $closeDate, displayedComponents: [.date, .hourAndMinute])
                    }
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
        let action = closingAction
        let price: Decimal
        let feeAmount: Decimal

        let closeTimestamp: Date
        if action == .expire || action == .assign {
            // Expire and assign always close at $0 with no fees, at the option's expiry date
            price = 0
            feeAmount = 0
            closeTimestamp = instrument.expiry ?? closeDate
        } else {
            guard let parsedPrice = Decimal(string: closingPrice), parsedPrice >= 0 else {
                return
            }
            price = parsedPrice
            feeAmount = Decimal(string: fees) ?? 0
            closeTimestamp = closeDate
        }

        let quantity = closeQuantity

        if action == .assign {
            // Assignment requires generating both an option close AND an equity trade.
            // Use the position's averagePrice as the premium for computing effective equity price.
            guard let underlyingSymbol = instrument.underlyingSymbol else { return }
            let equityInstrument = dataStore.getOrCreateInstrument(symbol: underlyingSymbol)

            let syntheticOptionTxn = Transaction(
                instrumentId: position.instrumentId,
                timestamp: closeTimestamp,
                action: position.quantity < 0 ? .sellToOpen : .buyToOpen,
                quantity: quantity,
                price: position.averagePrice,
                fees: 0
            )

            guard let generated = try? LedgerEngine.generateAssignmentTransactions(
                optionTransaction: syntheticOptionTxn,
                instrument: instrument,
                assignmentDate: closeTimestamp,
                equityInstrument: equityInstrument
            ) else { return }

            dataStore.addTransactions([generated.optionClose, generated.equityTrade])
            dismiss()
            return
        }

        let transaction = Transaction(
            instrumentId: position.instrumentId,
            timestamp: closeTimestamp,
            action: action,
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
        labelFor(closingAction)
    }

    private func labelFor(_ action: TransactionAction) -> String {
        switch action {
        case .buyToClose:   return "Buy to Close"
        case .sellToClose:  return "Sell to Close"
        case .expire:       return "Expire (OTM)"
        case .assign:       return "Assign (ITM)"
        case .buy:          return "Buy"
        case .sell:         return "Sell"
        default:            return action.rawValue.uppercased()
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
