import Foundation
import SwiftUI
import Combine

/// Main data store for the application
class DataStore: ObservableObject {
    static let shared = DataStore()

    // MARK: - Published State

    @Published var instruments: [UUID: Instrument] = [:]
    @Published var transactions: [Transaction] = []
    @Published var ledgerOutput: LedgerOutput = LedgerOutput()

    // MARK: - Initialization

    private init() {
        loadData()
        recomputeLedger()
    }

    // MARK: - Data Management

    func addInstrument(_ instrument: Instrument) {
        instruments[instrument.id] = instrument
        saveData()
    }

    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        recomputeLedger()
        saveData()
    }

    func addTransactions(_ newTransactions: [Transaction]) {
        transactions.append(contentsOf: newTransactions)
        recomputeLedger()
        saveData()
    }

    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        recomputeLedger()
        saveData()
    }

    // MARK: - Ledger Computation

    private func recomputeLedger() {
        ledgerOutput = LedgerEngine.process(
            transactions: transactions,
            instruments: instruments
        )
    }

    // MARK: - Helper Methods

    func getOrCreateInstrument(symbol: String) -> Instrument {
        // Check if equity instrument exists
        if let existing = instruments.values.first(where: {
            $0.type == .equity && $0.symbol == symbol
        }) {
            return existing
        }

        // Create new equity instrument
        let instrument = Instrument(symbol: symbol)
        addInstrument(instrument)
        return instrument
    }

    func getOrCreateOptionInstrument(
        underlyingSymbol: String,
        expiry: Date,
        strike: Decimal,
        callPut: OptionType,
        multiplier: Int = 100
    ) -> Instrument {
        // Check if option instrument exists
        if let existing = instruments.values.first(where: {
            $0.type == .option &&
            $0.underlyingSymbol == underlyingSymbol &&
            $0.expiry == expiry &&
            $0.strike == strike &&
            $0.callPut == callPut
        }) {
            return existing
        }

        // Create new option instrument
        let instrument = Instrument(
            underlyingSymbol: underlyingSymbol,
            expiry: expiry,
            strike: strike,
            callPut: callPut,
            multiplier: multiplier
        )
        addInstrument(instrument)
        return instrument
    }

    // MARK: - Persistence

    private var dataURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("portfolio_data.json")
    }

    private func saveData() {
        let data = PersistentData(
            instruments: Array(instruments.values),
            transactions: transactions
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: dataURL)
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    private func loadData() {
        guard FileManager.default.fileExists(atPath: dataURL.path) else {
            loadSampleData()
            return
        }

        do {
            let jsonData = try Data(contentsOf: dataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let data = try decoder.decode(PersistentData.self, from: jsonData)

            instruments = Dictionary(uniqueKeysWithValues: data.instruments.map { ($0.id, $0) })
            transactions = data.transactions
        } catch {
            print("Failed to load data: \(error)")
            loadSampleData()
        }
    }

    private func loadSampleData() {
        // Create sample instruments
        let aapl = Instrument(symbol: "AAPL")
        instruments[aapl.id] = aapl

        // No sample transactions - start fresh
        transactions = []
    }
}

// MARK: - Persistent Data Model

private struct PersistentData: Codable {
    let instruments: [Instrument]
    let transactions: [Transaction]

    init(instruments: [Instrument], transactions: [Transaction]) {
        self.instruments = instruments
        self.transactions = transactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instruments = try container.decode([Instrument].self, forKey: .instruments)
        transactions = try container.decode([Transaction].self, forKey: .transactions)
    }
}
