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
        
        guard let expiry = formatter.date(from: "02/20/2026") else {
            XCTFail("Invalid expiry date")
            return
        }
        guard let sellDate = formatter.date(from: "02/17/2026") else {
            XCTFail("Invalid sell date")
            return
        }
        
        let instrumentId = UUID()
        let metaCall = Instrument(
            id: instrumentId,
            underlyingSymbol: "META",
            expiry: expiry,
            strike: 405,
            callPut: .call
        )

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
        XCTAssertEqual(output.realizedPLs[0].quantity, 3)
        XCTAssertEqual(output.realizedPLs[0].costBasis, 0)
        XCTAssertEqual(output.realizedPLs[0].proceeds, Decimal(string: "1.17")! * 3 * 100)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, Decimal(string: "1.17")! * 3 * 100)

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].premium, Decimal(string: "1.17")! * 3 * 100)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 3)
    }

    // MARK: - Additional Equity Tests

    func testEquityFIFOAcrossMultipleLots() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )

        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 100,
            price: 20,
            fees: 0
        )

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sell,
            quantity: 150,
            price: 25,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].quantity, 100)
        XCTAssertEqual(output.realizedPLs[0].costBasis, 1000)  // 100 * $10
        XCTAssertEqual(output.realizedPLs[0].proceeds, 2500)   // 100 * $25
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 1500)
        XCTAssertEqual(output.realizedPLs[1].quantity, 50)
        XCTAssertEqual(output.realizedPLs[1].costBasis, 1000)  // 50/100 * $2000
        XCTAssertEqual(output.realizedPLs[1].proceeds, 1250)   // 50 * $25
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 250)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 1750)

        XCTAssertEqual(output.equityLots.count, 2)
        XCTAssertEqual(output.equityLots[0].remainingQuantity, 0)   // lot 1 fully consumed
        XCTAssertEqual(output.equityLots[1].remainingQuantity, 50)  // lot 2 partially consumed
    }

    func testEquityClosingAllSharesSetsLotIsOpenFalse() {
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
            quantity: 100,
            price: 15,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.equityLots.count, 1)
        XCTAssertEqual(output.equityLots[0].remainingQuantity, 0)
        XCTAssertFalse(output.equityLots[0].isOpen)
        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 500)  // 100 * ($15 - $10)
    }

    func testEquityBuyFeesIncreaseCostBasis() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 5
        )

        let output = LedgerEngine.process(
            transactions: [buy],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.equityLots.count, 1)
        XCTAssertEqual(output.equityLots[0].costBasis, 1005)  // 100 * $10 + $5 fee
        XCTAssertEqual(output.realizedPLs.count, 0)
    }

    func testEquitySellFeesReduceProceeds() {
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
            quantity: 100,
            price: 15,
            fees: 5
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].proceeds, 1495)   // 100 * $15 - $5 fee
        XCTAssertEqual(output.realizedPLs[0].costBasis, 1000)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 495)
    }

    func testEquityBuyOnlyProducesNoRealizedPL() {
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

        let output = LedgerEngine.process(
            transactions: [buy],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.equityLots.count, 1)
        XCTAssertTrue(output.equityLots[0].isOpen)
    }

    func testEquityPositionQuantityAfterPartialSell() {
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

        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].quantity, 60)
        XCTAssertEqual(output.positions[0].type, .equity)
    }

    // MARK: - Additional Option Tests

    func testOptionBuyToOpenSellToCloseProducesCorrectPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 2,
            price: Decimal(string: "1.50")!,
            fees: 0
        )

        let sellToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToClose,
            quantity: 2,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, sellToClose],
            instruments: [instrumentId: option]
        )

        // BTO records immediate P/L: -(2 * 1.50 * 100) = -$300
        // STC records P/L: +(2 * 2.00 * 100) = +$400
        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, -300)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 400)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 100)

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
    }

    func testOptionSellToOpenWithFeesReducesRealizedPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 400,
            callPut: .put
        )

        // Without fees: (2 * 1.50) * 100 = $300; with $0.50 fee: (2 * 1.50 - 0.50) * 100 = $250
        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 2,
            price: Decimal(string: "1.50")!,
            fees: Decimal(string: "0.50")!
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].proceeds, 250)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 250)
        XCTAssertEqual(output.optionLots[0].premium, 250)
    }

    func testOptionPartialClose() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 150,
            callPut: .put
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 3,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 1,
            price: Decimal(string: "0.25")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        // STO: 3 * $1.00 * 100 = $300; BTC 1: -(1 * $0.25 * 100) = -$25
        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 300)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, -25)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 275)

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 2)
    }

    func testShortOptionPositionUsesNegativeQuantityAndCostBasis() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 350,
            callPut: .put
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 2,
            price: Decimal(string: "1.50")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].type, .option)
        XCTAssertEqual(output.positions[0].quantity, -2)
        XCTAssertEqual(output.positions[0].costBasis, -300)
        XCTAssertEqual(output.positions[0].averagePrice, 150)
    }

    func testLongOptionPositionUsesPositiveQuantityAndCostBasis() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 350,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 3,
            price: Decimal(string: "1.25")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].type, .option)
        XCTAssertEqual(output.positions[0].quantity, 3)
        XCTAssertEqual(output.positions[0].costBasis, 375)
        XCTAssertEqual(output.positions[0].averagePrice, 125)
    }

    func testPartialOptionCloseUpdatesRemainingPositionCostBasis() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 150,
            callPut: .put
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 3,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 1,
            price: Decimal(string: "0.25")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].quantity, -2)
        XCTAssertEqual(NSDecimalNumber(decimal: output.positions[0].costBasis).doubleValue, -200, accuracy: 0.000001)
        XCTAssertEqual(NSDecimalNumber(decimal: output.positions[0].averagePrice).doubleValue, 100, accuracy: 0.000001)
    }

    func testOffsettingOpenOptionLotsProduceZeroNetPosition() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "TSLA",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 250,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 1,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, sellToOpen],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].quantity, 0)
        XCTAssertEqual(output.positions[0].costBasis, 0)
        XCTAssertEqual(output.positions[0].averagePrice, 0)
    }

    func testOptionNilMultiplierFallsBackToDefaultHundred() {
        let instrumentId = UUID()
        var option = Instrument(
            id: instrumentId,
            underlyingSymbol: "NVDA",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 900,
            callPut: .call
        )
        option.multiplier = nil

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 2,
            price: Decimal(string: "1.50")!,
            fees: 0
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 1,
            price: Decimal(string: "0.50")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 300)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, -50)
        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].quantity, -1)
        XCTAssertEqual(output.positions[0].costBasis, -150)
    }

    // MARK: - P/L Summary Tests

    func testPLSummaryAggregatesEquityAndOptionPL() {
        let equityId = UUID()
        let msft = Instrument(id: equityId, symbol: "MSFT")

        let optionId = UUID()
        let option = Instrument(
            id: optionId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 400,
            callPut: .call
        )

        // Equity: buy 100 @ $10, sell 100 @ $12 → $200 profit
        let equityBuy = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )
        let equitySell = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sell,
            quantity: 100,
            price: 12,
            fees: 0
        )

        // Option: STO 1 contract @ $0.50 → 1 * $0.50 * 100 = $50 profit
        let optionSTO = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "0.50")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [equityBuy, equitySell, optionSTO],
            instruments: [equityId: msft, optionId: option]
        )

        XCTAssertEqual(output.plSummary.equityRealizedPL, 200)
        XCTAssertEqual(output.plSummary.optionRealizedPL, 50)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 250)
    }

    // MARK: - Multi-Instrument Tests

    func testMultipleInstrumentPositionsAreIsolated() {
        let msftId = UUID()
        let msft = Instrument(id: msftId, symbol: "MSFT")

        let aaplId = UUID()
        let aapl = Instrument(id: aaplId, symbol: "AAPL")

        let msftBuy = Transaction(
            instrumentId: msftId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )
        let msftSell = Transaction(
            instrumentId: msftId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sell,
            quantity: 50,
            price: 20,
            fees: 0
        )
        let aaplBuy = Transaction(
            instrumentId: aaplId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .buy,
            quantity: 200,
            price: 5,
            fees: 0
        )
        let aaplSell = Transaction(
            instrumentId: aaplId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_300),
            action: .sell,
            quantity: 100,
            price: 8,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [msftBuy, msftSell, aaplBuy, aaplSell],
            instruments: [msftId: msft, aaplId: aapl]
        )

        XCTAssertEqual(output.realizedPLs.count, 2)

        let msftPL = output.realizedPLs.first { $0.instrumentId == msftId }
        let aaplPL = output.realizedPLs.first { $0.instrumentId == aaplId }
        XCTAssertEqual(msftPL?.realizedPL, 500)  // 50 * ($20 - $10)
        XCTAssertEqual(aaplPL?.realizedPL, 300)  // 100 * ($8 - $5)

        XCTAssertEqual(output.positions.count, 2)
        let msftPos = output.positions.first { $0.instrumentId == msftId }
        let aaplPos = output.positions.first { $0.instrumentId == aaplId }
        XCTAssertEqual(msftPos?.quantity, 50)
        XCTAssertEqual(aaplPos?.quantity, 100)
    }

    // MARK: - Holding Period Tests

    func testHoldingPeriodCalculation() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 0),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 30 * 86400),  // 30 days later
            action: .sell,
            quantity: 100,
            price: 15,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].holdingDays, 30)
    }

    // MARK: - Edge Case Tests

    func testEmptyTransactionsProducesEmptyOutput() {
        let output = LedgerEngine.process(
            transactions: [],
            instruments: [:]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.equityLots.count, 0)
        XCTAssertEqual(output.optionLots.count, 0)
        XCTAssertEqual(output.positions.count, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 0)
    }

    func testUnknownInstrumentTransactionIsSkipped() {
        let unknownInstrumentId = UUID()
        let buy = Transaction(
            instrumentId: unknownInstrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy],
            instruments: [:]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.equityLots.count, 0)
        XCTAssertEqual(output.optionLots.count, 0)
        XCTAssertEqual(output.positions.count, 0)
        XCTAssertEqual(output.underlierSummaries.count, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 0)
    }

    func testEquitySellWithoutOpenLotsProducesNoOutputChanges() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sell,
            quantity: 50,
            price: 15,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.equityLots.count, 0)
        XCTAssertEqual(output.positions.count, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 0)
    }

    func testOptionCloseWithoutOpenLotsProducesNoOutputChanges() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToClose,
            quantity: 1,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.optionLots.count, 0)
        XCTAssertEqual(output.positions.count, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 0)
    }

    func testInvalidOptionCloseSideDoesNotConsumeLot() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 2,
            price: Decimal(string: "1.25")!,
            fees: 0
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 2,
            price: Decimal(string: "0.50")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, -250)
        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 2)

        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].quantity, 2)
        XCTAssertEqual(output.positions[0].costBasis, 250)
    }

    func testInvalidActionForEquityInstrumentIsIgnored() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let invalidOptionStyleAction = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 1,
            price: 10,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [invalidOptionStyleAction],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.equityLots.count, 0)
        XCTAssertEqual(output.positions.count, 0)
    }

    func testInvalidActionForOptionInstrumentIsIgnored() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .put
        )

        let invalidEquityStyleAction = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 2,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [invalidEquityStyleAction],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 0)
        XCTAssertEqual(output.optionLots.count, 0)
        XCTAssertEqual(output.positions.count, 0)
    }

    func testEquitySellSkipsClosedLotsAndBreaksAfterQuantitySatisfied() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 10,
            price: 10,
            fees: 0
        )
        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 10,
            price: 20,
            fees: 0
        )
        let buy3 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .buy,
            quantity: 10,
            price: 30,
            fees: 0
        )
        let sell1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_300),
            action: .sell,
            quantity: 15,
            price: 40,
            fees: 0
        )
        let sell2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_400),
            action: .sell,
            quantity: 5,
            price: 50,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2, buy3, sell1, sell2],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.equityLots.count, 3)
        XCTAssertEqual(output.equityLots[0].remainingQuantity, 0)
        XCTAssertEqual(output.equityLots[1].remainingQuantity, 0)
        XCTAssertEqual(output.equityLots[2].remainingQuantity, 10)
        XCTAssertEqual(output.positions.count, 1)
        XCTAssertEqual(output.positions[0].quantity, 10)
        XCTAssertEqual(output.positions[0].costBasis, 300)
    }

    func testOptionCloseSkipsClosedLotsAndBreaksAfterQuantitySatisfied() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AMD",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 180,
            callPut: .put
        )

        let sto1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "1.00")!,
            fees: 0
        )
        let sto2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "2.00")!,
            fees: 0
        )
        let sto3 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "3.00")!,
            fees: 0
        )
        let btc1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_300),
            action: .buyToClose,
            quantity: 2,
            price: Decimal(string: "0.50")!,
            fees: 0
        )
        let btc2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_400),
            action: .buyToClose,
            quantity: 1,
            price: Decimal(string: "0.25")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sto1, sto2, sto3, btc1, btc2],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.optionLots.count, 3)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
        XCTAssertEqual(output.optionLots[1].remainingQuantity, 0)
        XCTAssertEqual(output.optionLots[2].remainingQuantity, 0)
        XCTAssertEqual(output.positions.count, 0)
        XCTAssertEqual(output.realizedPLs.count, 6)
    }

    func testChronologicalOrderingRegardlessOfInputOrder() {
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
            quantity: 100,
            price: 15,
            fees: 0
        )

        // Pass sell before buy in the array; engine must sort by timestamp
        let output = LedgerEngine.process(
            transactions: [sell, buy],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 500)  // 100 * ($15 - $10)
    }

    func testDecimalPrecisionWithSmallPriceAndLargeQuantity() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: Decimal(string: "1000.5")!,
            price: Decimal(string: "0.001")!,
            fees: 0
        )

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sell,
            quantity: Decimal(string: "500.5")!,
            price: Decimal(string: "0.002")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].quantity, Decimal(string: "500.5")!)
        XCTAssertTrue(output.realizedPLs[0].realizedPL > 0)  // sold at higher price than purchased
    }

    // MARK: - Assignment Tests

    func testAssignmentGeneratesCorrectEquityTransaction() {
        let optionId = UUID()
        let equityId = UUID()

        let putOption = Instrument(
            id: optionId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 100,
            callPut: .put
        )
        let msft = Instrument(id: equityId, symbol: "MSFT")

        let stoTransaction = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 2,
            price: 0,
            fees: 0
        )

        let (optionClose, equityTrade) = try! LedgerEngine.generateAssignmentTransactions(
            optionTransaction: stoTransaction,
            instrument: putOption,
            assignmentDate: Date(timeIntervalSince1970: 1_750_000_000),
            equityInstrument: msft
        )

        // Option close: buyToClose at $0 (assignment)
        XCTAssertEqual(optionClose.action, .buyToClose)
        XCTAssertEqual(optionClose.price, 0)
        XCTAssertEqual(optionClose.quantity, 2)

        // Equity trade: buy shares (put assignment)
        XCTAssertEqual(equityTrade.action, .buy)
        XCTAssertEqual(equityTrade.quantity, 200)  // 2 contracts * 100 multiplier
        XCTAssertEqual(equityTrade.price, 100)     // strike - premiumPerShare(0) = 100

        // Both transactions share a linkGroupId
        XCTAssertNotNil(optionClose.linkGroupId)
        XCTAssertEqual(optionClose.linkGroupId, equityTrade.linkGroupId)
    }

    func testEquitySellAcrossMultipleLotsProducesMultipleRealizedPLs() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 10,
            fees: 0
        )

        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 50,
            price: 20,
            fees: 0
        )

        // Sell 100 — fully consumes both lots
        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sell,
            quantity: 100,
            price: 30,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].costBasis, 500)   // 50 * $10
        XCTAssertEqual(output.realizedPLs[0].proceeds, 1500)   // 50 * $30
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 1000)
        XCTAssertEqual(output.realizedPLs[1].costBasis, 1000)  // 50 * $20
        XCTAssertEqual(output.realizedPLs[1].proceeds, 1500)   // 50 * $30
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 500)

        XCTAssertFalse(output.equityLots[0].isOpen)
        XCTAssertFalse(output.equityLots[1].isOpen)
    }

    func testPLSummaryEquityRealizedPLIsolated() {
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
            quantity: 100,
            price: 15,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.plSummary.equityRealizedPL, 500)
        XCTAssertEqual(output.plSummary.optionRealizedPL, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 500)
    }

    func testOptionBuyToOpenThenSellToCloseNetPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 2,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let sellToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToClose,
            quantity: 2,
            price: Decimal(string: "2.50")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, sellToClose],
            instruments: [instrumentId: option]
        )

        // BTO: -(2 * $1.00 * 100) = -$200; STC: +(2 * $2.50 * 100) = +$500; net = $300
        XCTAssertEqual(output.plSummary.totalRealizedPL, 300)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
    }

    func testOptionBuyToOpenCreatesLotWithCorrectPremium() {
        // BTO uses cash-basis accounting: records an immediate negative P/L (premium paid)
        // and creates an open long lot
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 3,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 3)
        XCTAssertTrue(output.optionLots[0].isLong)
        XCTAssertEqual(output.optionLots[0].premium, 300)  // 3 * $1.00 * 100
    }

    func testOptionPartialSellToClose() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let buyToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 4,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        // Close 2 of 4 contracts
        let sellToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToClose,
            quantity: 2,
            price: Decimal(string: "1.50")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, sellToClose],
            instruments: [instrumentId: option]
        )

        // STC: +(2 * $1.50 * 100) = +$300
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 300)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 2)
    }

    func testOptionBuyToCloseWithFeesReducesRealizedPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 400,
            callPut: .call
        )

        // STO 1 @ $2.00, no fees → +$200
        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        // BTC 1 @ $0.50 with $1.50 fees → netAmount = 0.50 + 1.50 = $2.00, scaled = $200
        // Without fees BTC would cost $50; $1.50 in fees raises it to $200, zeroing net P/L
        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 1,
            price: Decimal(string: "0.50")!,
            fees: Decimal(string: "1.50")!
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[1].costBasis, 200)    // (0.50 + 1.50) * 100
        XCTAssertEqual(output.realizedPLs[1].realizedPL, -200)  // fees consumed all gains
        XCTAssertEqual(output.plSummary.totalRealizedPL, 0)     // $200 STO - $200 BTC = $0
    }

    func testOptionFullBuyToCloseClosesLot() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 150,
            callPut: .call
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 3,
            price: Decimal(string: "1.50")!,
            fees: 0
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 3,
            price: Decimal(string: "0.25")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
        XCTAssertFalse(output.optionLots[0].isOpen)
    }

    func testPLSummaryOptionRealizedPLIsolated() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.plSummary.optionRealizedPL, 200)  // 1 * $2.00 * 100
        XCTAssertEqual(output.plSummary.equityRealizedPL, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 200)
    }

    func testCallAssignmentGeneratesCorrectEquityTransaction() {
        let optionId = UUID()
        let equityId = UUID()

        let callOption = Instrument(
            id: optionId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )
        let aapl = Instrument(id: equityId, symbol: "AAPL")

        let stoTransaction = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: 0,
            fees: 0
        )

        let (optionClose, equityTrade) = try! LedgerEngine.generateAssignmentTransactions(
            optionTransaction: stoTransaction,
            instrument: callOption,
            assignmentDate: Date(timeIntervalSince1970: 1_750_000_000),
            equityInstrument: aapl
        )

        // Option close: buyToClose at $0
        XCTAssertEqual(optionClose.action, .buyToClose)
        XCTAssertEqual(optionClose.price, 0)

        // Equity trade: sell shares (call assignment = stock is called away)
        XCTAssertEqual(equityTrade.action, .sell)
        XCTAssertEqual(equityTrade.quantity, 100)  // 1 contract * 100 multiplier
        XCTAssertEqual(equityTrade.price, 200)     // strike + premiumPerShare(0) = 200

        XCTAssertNotNil(optionClose.linkGroupId)
        XCTAssertEqual(optionClose.linkGroupId, equityTrade.linkGroupId)
    }

    func testAssignmentThrowsForInvalidInstrument() {
        let equityId = UUID()
        let msft = Instrument(id: equityId, symbol: "MSFT")

        let transaction = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: 1,
            fees: 0
        )

        XCTAssertThrowsError(try LedgerEngine.generateAssignmentTransactions(
            optionTransaction: transaction,
            instrument: msft,
            assignmentDate: Date(timeIntervalSince1970: 1_750_000_000),
            equityInstrument: msft
        )) { error in
            XCTAssertEqual(error as? LedgerEngineError, .invalidOptionInstrumentForAssignment)
        }
    }

    func testUnderlierSummaryGroupsEquityAndOptions() {
        let equityId = UUID()
        let aapl = Instrument(id: equityId, symbol: "AAPL")

        let optionId = UUID()
        let aaplCall = Instrument(
            id: optionId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        let equityBuy = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 150,
            fees: 0
        )

        let optionSTO = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToOpen,
            quantity: 2,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [equityBuy, optionSTO],
            instruments: [equityId: aapl, optionId: aaplCall]
        )

        let summary = output.underlierSummaries["AAPL"]
        XCTAssertNotNil(summary)
        XCTAssertNotNil(summary?.equityPosition)
        XCTAssertEqual(summary?.optionPositions.count, 1)
        XCTAssertEqual(summary?.totalEquityShares, 100)
    }

    func testUnderlierSummaryTotalRealizedPL() {
        let equityId = UUID()
        let aapl = Instrument(id: equityId, symbol: "AAPL")

        let optionId = UUID()
        let aaplCall = Instrument(
            id: optionId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .call
        )

        // Equity: $200 profit
        let equityBuy = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 10,
            fees: 0
        )
        let equitySell = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sell,
            quantity: 100,
            price: 12,
            fees: 0
        )

        // Option: $50 profit (STO 1 @ $0.50)
        let optionSTO = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "0.50")!,
            fees: 0
        )

        let instruments: [UUID: Instrument] = [equityId: aapl, optionId: aaplCall]
        let output = LedgerEngine.process(
            transactions: [equityBuy, equitySell, optionSTO],
            instruments: instruments
        )

        let aaplPLs = output.realizedPLs.filter { pl in
            instruments[pl.instrumentId]?.underlyingTicker == "AAPL"
        }
        let summary = output.underlierSummaries["AAPL"]
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalRealizedPL(from: aaplPLs), 250)  // $200 equity + $50 option
    }

    func testSameDayTradeHasZeroHoldingDays() {
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

        // Sell a few hours later on the same day
        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000 + 3600),
            action: .sell,
            quantity: 100,
            price: 15,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        XCTAssertEqual(output.realizedPLs.count, 1)
        XCTAssertEqual(output.realizedPLs[0].holdingDays, 0)
    }

    func testOptionSellThenBuyBackProducesNetPositiveRealizedPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .put
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 2,
            price: Decimal(string: "1.50")!,
            fees: 0
        )

        let buyToClose = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToClose,
            quantity: 2,
            price: Decimal(string: "0.25")!,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, buyToClose],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 300)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, -50)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 250)

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
    }
}
