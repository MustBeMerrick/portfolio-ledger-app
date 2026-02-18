import XCTest
@testable import PortfolioLedger

final class LedgerEngineTests: XCTestCase {
    func testEquityBuyThenPartialSellProducesFIFORealizedPL() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sell,
            quantity: 40,
            price: 15,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].quantity, 40)
        XCTAssertEqual(output.realizedPLs[0].costBasis, 400)
        XCTAssertEqual(output.realizedPLs[0].proceeds, 600)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 200)

        XCTAssertEqual(output.equityLots.count, 1)
        XCTAssertEqual(output.equityLots[0].remainingQuantity, 60)
    }
    
    func testOptionSellProducesCorrectRealizedPL() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let expiry = formatter.date(from: "02/20/2026")
        let sellDate = formatter.date(from: "02/17/2026")
        
        let instrumentId = UUID()
        let metaCall = Instrument(id: instrumentId, underlyingSymbol: "META", expiry: expiry, strike: 405, callPut: .call)

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: sellDate,
            action: .sellToOpen,
            quantity: 3,
            price: 1.17,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sell],
            instruments: [instrumentId: metaCall]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].quantity, 40)
        XCTAssertEqual(output.realizedPLs[0].costBasis, 400)
        XCTAssertEqual(output.realizedPLs[0].proceeds, 600)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 200)

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 60)
    }
}
