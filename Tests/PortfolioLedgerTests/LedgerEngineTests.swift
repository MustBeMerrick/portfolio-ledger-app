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
}
