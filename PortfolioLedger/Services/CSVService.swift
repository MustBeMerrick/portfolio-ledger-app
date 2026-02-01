import Foundation

/// Service for exporting and importing CSV data
class CSVService {
    static let shared = CSVService()

    private init() {}

    // MARK: - Export

    func exportAll(dataStore: DataStore) {
        let urls = getExportURLs()

        do {
            // Export instruments
            let instrumentsCSV = exportInstruments(Array(dataStore.instruments.values))
            try instrumentsCSV.write(to: urls.instruments, atomically: true, encoding: .utf8)

            // Export transactions
            let transactionsCSV = exportTransactions(dataStore.transactions, instruments: dataStore.instruments)
            try transactionsCSV.write(to: urls.transactions, atomically: true, encoding: .utf8)

            print("Exported to:")
            print("Instruments: \(urls.instruments.path)")
            print("Transactions: \(urls.transactions.path)")
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func exportInstruments(_ instruments: [Instrument]) -> String {
        var csv = "id,type,symbol,underlyingSymbol,expiry,strike,callPut,multiplier\n"

        for instrument in instruments {
            csv += "\(instrument.id.uuidString),"
            csv += "\(instrument.type.rawValue),"

            if instrument.type == .equity {
                csv += "\"\(escapeCSV(instrument.symbol ?? ""))\","
                csv += ",,,,\n"
            } else {
                csv += ","
                csv += "\"\(escapeCSV(instrument.underlyingSymbol ?? ""))\","

                if let expiry = instrument.expiry {
                    let formatter = ISO8601DateFormatter()
                    csv += "\(formatter.string(from: expiry)),"
                } else {
                    csv += ","
                }

                csv += "\(instrument.strike?.description ?? ""),"
                csv += "\(instrument.callPut?.rawValue ?? ""),"
                csv += "\(instrument.multiplier?.description ?? "")\n"
            }
        }

        return csv
    }

    private func exportTransactions(_ transactions: [Transaction], instruments: [UUID: Instrument]) -> String {
        var csv = "id,instrumentId,timestamp,action,quantity,price,fees,notes,tags,linkGroupId,consumedByAssignment\n"

        for txn in transactions {
            let formatter = ISO8601DateFormatter()

            csv += "\(txn.id.uuidString),"
            csv += "\(txn.instrumentId.uuidString),"
            csv += "\(formatter.string(from: txn.timestamp)),"
            csv += "\(txn.action.rawValue),"
            csv += "\(txn.quantity),"
            csv += "\(txn.price),"
            csv += "\(txn.fees),"
            csv += "\"\(escapeCSV(txn.notes))\","
            csv += "\"\(txn.tags.joined(separator: ";"))\","
            csv += "\(txn.linkGroupId?.uuidString ?? ""),"
            csv += "\(txn.flags.consumedByAssignment)\n"
        }

        return csv
    }

    // MARK: - Import

    func importAll(instrumentsURL: URL, transactionsURL: URL) throws -> (instruments: [Instrument], transactions: [Transaction]) {
        let instruments = try importInstruments(from: instrumentsURL)
        let transactions = try importTransactions(from: transactionsURL)

        return (instruments, transactions)
    }

    private func importInstruments(from url: URL) throws -> [Instrument] {
        let csv = try String(contentsOf: url, encoding: .utf8)
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard lines.count > 1 else { return [] }

        var instruments: [Instrument] = []

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 3,
                  let id = UUID(uuidString: fields[0]),
                  let type = InstrumentType(rawValue: fields[1]) else {
                continue
            }

            if type == .equity {
                let instrument = Instrument(id: id, symbol: fields[2])
                instruments.append(instrument)
            } else if type == .option {
                guard fields.count >= 8,
                      let expiry = ISO8601DateFormatter().date(from: fields[4]),
                      let strike = Decimal(string: fields[5]),
                      let callPut = OptionType(rawValue: fields[6]),
                      let multiplier = Int(fields[7]) else {
                    continue
                }

                let instrument = Instrument(
                    id: id,
                    underlyingSymbol: fields[3],
                    expiry: expiry,
                    strike: strike,
                    callPut: callPut,
                    multiplier: multiplier
                )
                instruments.append(instrument)
            }
        }

        return instruments
    }

    private func importTransactions(from url: URL) throws -> [Transaction] {
        let csv = try String(contentsOf: url, encoding: .utf8)
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard lines.count > 1 else { return [] }

        var transactions: [Transaction] = []

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 11,
                  let id = UUID(uuidString: fields[0]),
                  let instrumentId = UUID(uuidString: fields[1]),
                  let timestamp = ISO8601DateFormatter().date(from: fields[2]),
                  let action = TransactionAction(rawValue: fields[3]),
                  let quantity = Decimal(string: fields[4]),
                  let price = Decimal(string: fields[5]),
                  let fees = Decimal(string: fields[6]) else {
                continue
            }

            let notes = fields[7]
            let tags = fields[8].components(separatedBy: ";").filter { !$0.isEmpty }
            let linkGroupId = fields[9].isEmpty ? nil : UUID(uuidString: fields[9])
            let consumedByAssignment = fields[10].lowercased() == "true"

            let transaction = Transaction(
                id: id,
                instrumentId: instrumentId,
                timestamp: timestamp,
                action: action,
                quantity: quantity,
                price: price,
                fees: fees,
                notes: notes,
                tags: tags,
                linkGroupId: linkGroupId,
                flags: TransactionFlags(consumedByAssignment: consumedByAssignment)
            )
            transactions.append(transaction)
        }

        return transactions
    }

    // MARK: - Helpers

    private func getExportURLs() -> (instruments: URL, transactions: URL) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        return (
            instruments: docs.appendingPathComponent("instruments.csv"),
            transactions: docs.appendingPathComponent("transactions.csv")
        )
    }

    private func escapeCSV(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\"\"")
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        fields.append(currentField)
        return fields
    }
}
