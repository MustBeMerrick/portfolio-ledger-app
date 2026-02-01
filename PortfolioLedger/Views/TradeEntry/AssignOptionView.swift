import SwiftUI

struct AssignOptionView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    let optionTransaction: Transaction
    let optionInstrument: Instrument

    @State private var assignmentDate: Date = Date()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section("Option Being Assigned") {
                    Text(optionInstrument.displayName)
                        .font(.headline)

                    HStack {
                        Text("Contracts:")
                        Spacer()
                        Text(optionTransaction.quantity.description)
                    }

                    HStack {
                        Text("Premium Received:")
                        Spacer()
                        Text("$\(optionTransaction.price.description)")
                    }
                }

                Section("Assignment Details") {
                    DatePicker("Assignment Date", selection: $assignmentDate, displayedComponents: [.date])

                    if let strike = optionInstrument.strike,
                       let callPut = optionInstrument.callPut,
                       let multiplier = optionInstrument.multiplier {

                        let shareQty = optionTransaction.quantity * Decimal(multiplier)
                        let premiumPerShare = optionTransaction.price / Decimal(multiplier)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("This will generate:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if callPut == .put {
                                HStack {
                                    Text("BUY \(shareQty.description) shares")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("@ $\((strike - premiumPerShare).description)")
                                }
                            } else {
                                HStack {
                                    Text("SELL \(shareQty.description) shares")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("@ $\((strike + premiumPerShare).description)")
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                Section {
                    Button("Process Assignment") {
                        showingConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Option Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Assignment", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm") {
                    processAssignment()
                }
            } message: {
                Text("This will close the option position and create an equity trade. This cannot be undone.")
            }
        }
    }

    private func processAssignment() {
        // Get underlying equity instrument
        guard let underlyingSymbol = optionInstrument.underlyingSymbol else { return }

        let equityInstrument = dataStore.getOrCreateInstrument(symbol: underlyingSymbol)

        // Generate assignment transactions
        let (optionClose, equityTrade) = LedgerEngine.generateAssignmentTransactions(
            optionTransaction: optionTransaction,
            instrument: optionInstrument,
            assignmentDate: assignmentDate,
            equityInstrument: equityInstrument
        )

        // Add both transactions
        dataStore.addTransactions([optionClose, equityTrade])

        dismiss()
    }
}

struct AssignOptionView_Previews: PreviewProvider {
    static var previews: some View {
        let instrument = Instrument(
            underlyingSymbol: "AAPL",
            expiry: Date(),
            strike: 150,
            callPut: .put
        )
        let txn = Transaction(
            instrumentId: instrument.id,
            action: .sellToOpen,
            quantity: 1,
            price: 2.50
        )

        return AssignOptionView(
            optionTransaction: txn,
            optionInstrument: instrument
        )
        .environmentObject(DataStore.shared)
    }
}
