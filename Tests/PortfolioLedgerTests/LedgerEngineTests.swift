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

    // MARK: - Expire Tests

    func testShortOptionExpireClosesLotWithZeroPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .put
        )

        // Sell to open: premium captured immediately (+$100)
        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        // Option expires OTM: no additional P/L
        let expire = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .expire,
            quantity: 1,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, expire],
            instruments: [instrumentId: option]
        )

        // STO P/L: +$100; expire P/L: $0
        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 100)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 100)

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
        XCTAssertFalse(output.optionLots[0].isOpen)

        // No equity position created
        XCTAssertEqual(output.positions.filter { $0.type == .equity }.count, 0)
    }

    func testLongOptionExpireClosesLotWithZeroPL() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 400,
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

        let expire = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .expire,
            quantity: 2,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, expire],
            instruments: [instrumentId: option]
        )

        // BTO P/L: -$300; expire P/L: $0; net: -$300 (lost the premium)
        XCTAssertEqual(output.realizedPLs.count, 2)
        XCTAssertEqual(output.realizedPLs[0].realizedPL, -300)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 0)
        XCTAssertEqual(output.plSummary.totalRealizedPL, -300)

        XCTAssertFalse(output.optionLots[0].isOpen)
        XCTAssertEqual(output.positions.filter { $0.type == .equity }.count, 0)
    }

    func testExpirePartiallyClosesMultipleContracts() {
        let instrumentId = UUID()
        let option = Instrument(
            id: instrumentId,
            underlyingSymbol: "TSLA",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 300,
            callPut: .call
        )

        let sellToOpen = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 3,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        // Only 2 of 3 contracts expire (partial expiry)
        let expire = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .expire,
            quantity: 2,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, expire],
            instruments: [instrumentId: option]
        )

        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertEqual(output.optionLots[0].remainingQuantity, 1)
        XCTAssertTrue(output.optionLots[0].isOpen)
    }

    // MARK: - Assign Tests

    func testShortPutAssignedAutoBuysEquityAtStrike() {
        let optionId = UUID()
        let equityId = UUID()

        let putOption = Instrument(
            id: optionId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 150,
            callPut: .put
        )
        let aapl = Instrument(id: equityId, symbol: "AAPL")

        // STO put: premium received +$200 (2 * $1.00 * 100)
        let sellToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 2,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        // Put assigned: must buy 200 shares at $150 strike
        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 2,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, assign],
            instruments: [optionId: putOption, equityId: aapl]
        )

        // Option lot closed
        XCTAssertEqual(output.optionLots.count, 1)
        XCTAssertFalse(output.optionLots[0].isOpen)

        // Equity position created: 200 shares @ $150
        let equityPos = output.positions.first { $0.type == .equity }
        XCTAssertNotNil(equityPos)
        XCTAssertEqual(equityPos?.quantity, 200)   // 2 contracts * 100 multiplier
        XCTAssertEqual(equityPos?.costBasis, 30000) // 200 * $150

        // P/L: STO +$200, assign option leg $0
        XCTAssertEqual(output.realizedPLs[0].realizedPL, 200)
        XCTAssertEqual(output.realizedPLs[1].realizedPL, 0)
        XCTAssertEqual(output.plSummary.optionRealizedPL, 200)
    }

    func testShortCallAssignedAutoSellsEquityAtStrike() {
        let optionId = UUID()
        let equityId = UUID()

        let callOption = Instrument(
            id: optionId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 400,
            callPut: .call
        )
        let msft = Instrument(id: equityId, symbol: "MSFT")

        // Buy 100 shares @ $350 first (covered call position)
        let equityBuy = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 350,
            fees: 0
        )

        // STO call: premium received +$50 (1 * $0.50 * 100)
        let sellToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "0.50")!,
            fees: 0
        )

        // Call assigned: 100 shares sold at $400 strike
        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 1,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [equityBuy, sellToOpen, assign],
            instruments: [optionId: callOption, equityId: msft]
        )

        // Option lot closed
        XCTAssertFalse(output.optionLots[0].isOpen)

        // Equity lot consumed (shares called away)
        XCTAssertFalse(output.equityLots[0].isOpen)

        // Equity sell P/L: 100 * ($400 - $350) = $5,000
        let equityRealizedPL = output.realizedPLs.filter { $0.instrumentId == equityId }
        XCTAssertEqual(equityRealizedPL.first?.realizedPL, 5000)  // 100 * (400 - 350)

        // Option P/L: +$50 (STO) + $0 (assign leg)
        XCTAssertEqual(output.plSummary.optionRealizedPL, 50)
        XCTAssertEqual(output.plSummary.equityRealizedPL, 5000)
        XCTAssertEqual(output.plSummary.totalRealizedPL, 5050)

        // No open equity position remains
        XCTAssertTrue(output.positions.filter { $0.type == .equity }.isEmpty)
    }

    func testLongPutExercisedAutoSellsEquityAtStrike() {
        let optionId = UUID()
        let equityId = UUID()

        let putOption = Instrument(
            id: optionId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 200,
            callPut: .put
        )
        let aapl = Instrument(id: equityId, symbol: "AAPL")

        // Buy 100 shares @ $210
        let equityBuy = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 210,
            fees: 0
        )

        // BTO put (protective put): premium paid -$100 (1 * $1.00 * 100)
        let buyToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buyToOpen,
            quantity: 1,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        // Exercise put: sell 100 shares at $200 strike
        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 1,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [equityBuy, buyToOpen, assign],
            instruments: [optionId: putOption, equityId: aapl]
        )

        // Option lot closed
        XCTAssertFalse(output.optionLots[0].isOpen)

        // Equity lot consumed (shares sold at strike)
        XCTAssertFalse(output.equityLots[0].isOpen)

        // Equity P/L: 100 * ($200 - $210) = -$1,000
        let equityPLs = output.realizedPLs.filter { $0.instrumentId == equityId }
        XCTAssertEqual(equityPLs.first?.realizedPL, -1000)

        // Option P/L: -$100 (BTO) + $0 (assign leg) = -$100
        XCTAssertEqual(output.plSummary.optionRealizedPL, -100)
        XCTAssertEqual(output.plSummary.equityRealizedPL, -1000)
        // Net: put protected from further loss (paid $100 premium to limit loss to $1,100 total)
        XCTAssertEqual(output.plSummary.totalRealizedPL, -1100)
    }

    func testLongCallExercisedAutoBuysEquityAtStrike() {
        let optionId = UUID()
        let equityId = UUID()

        let callOption = Instrument(
            id: optionId,
            underlyingSymbol: "TSLA",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 250,
            callPut: .call
        )
        let tsla = Instrument(id: equityId, symbol: "TSLA")

        // BTO call: premium paid -$200 (2 * $1.00 * 100)
        let buyToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buyToOpen,
            quantity: 2,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        // Exercise call: buy 200 shares at $250 strike
        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 2,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buyToOpen, assign],
            instruments: [optionId: callOption, equityId: tsla]
        )

        // Option lot closed
        XCTAssertFalse(output.optionLots[0].isOpen)

        // Equity position created: 200 shares @ $250
        let equityPos = output.positions.first { $0.type == .equity }
        XCTAssertNotNil(equityPos)
        XCTAssertEqual(equityPos?.quantity, 200)
        XCTAssertEqual(equityPos?.costBasis, 50000)  // 200 * $250
    }

    func testCallAssignmentWithMultipleEquityLotsConsumesFIFO() {
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

        // Buy lot 1: 50 shares @ $100
        let buy1 = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 100,
            fees: 0
        )

        // Buy lot 2: 50 shares @ $150
        let buy2 = Transaction(
            instrumentId: equityId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 50,
            price: 150,
            fees: 0
        )

        // STO call covering all 100 shares (1 contract = 100 shares)
        let sellToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "2.00")!,
            fees: 0
        )

        // Call assigned: 100 shares called away at $200
        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 1,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2, sellToOpen, assign],
            instruments: [optionId: callOption, equityId: aapl]
        )

        // Both equity lots fully consumed (FIFO)
        XCTAssertEqual(output.equityLots.count, 2)
        XCTAssertFalse(output.equityLots[0].isOpen)
        XCTAssertFalse(output.equityLots[1].isOpen)

        // Two equity realized P/L entries (one per lot consumed)
        let equityPLs = output.realizedPLs.filter { $0.instrumentId == equityId }
        XCTAssertEqual(equityPLs.count, 2)
        XCTAssertEqual(equityPLs[0].realizedPL, 5000)  // 50 * ($200 - $100)
        XCTAssertEqual(equityPLs[1].realizedPL, 2500)  // 50 * ($200 - $150)

        // No open equity position remains
        XCTAssertTrue(output.positions.filter { $0.type == .equity }.isEmpty)
    }

    func testAssignWithNoEquityInstrumentClosesOptionLotOnly() {
        // If the equity instrument isn't registered, the option lot is still closed
        // but no equity transaction is generated
        let optionId = UUID()

        let putOption = Instrument(
            id: optionId,
            underlyingSymbol: "AAPL",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 150,
            callPut: .put
        )

        let sellToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 1,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 1,
            price: 0,
            fees: 0
        )

        // Only the option instrument is registered — no equity instrument
        let output = LedgerEngine.process(
            transactions: [sellToOpen, assign],
            instruments: [optionId: putOption]
        )

        // Option lot is still closed
        XCTAssertFalse(output.optionLots[0].isOpen)

        // No equity lots or positions created
        XCTAssertEqual(output.equityLots.count, 0)
        XCTAssertTrue(output.positions.filter { $0.type == .equity }.isEmpty)
    }

    func testAssignLotIsClosedAfterAssignment() {
        let optionId = UUID()
        let equityId = UUID()

        let putOption = Instrument(
            id: optionId,
            underlyingSymbol: "MSFT",
            expiry: Date(timeIntervalSince1970: 1_800_000_000),
            strike: 300,
            callPut: .put
        )
        let msft = Instrument(id: equityId, symbol: "MSFT")

        let sellToOpen = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .sellToOpen,
            quantity: 3,
            price: Decimal(string: "1.00")!,
            fees: 0
        )

        let assign = Transaction(
            instrumentId: optionId,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            action: .assign,
            quantity: 3,
            price: 0,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [sellToOpen, assign],
            instruments: [optionId: putOption, equityId: msft]
        )

        XCTAssertEqual(output.optionLots[0].remainingQuantity, 0)
        XCTAssertFalse(output.optionLots[0].isOpen)
        XCTAssertEqual(output.positions.filter { $0.type == .option }.count, 0)
    }

    // MARK: - Issue #14: Separate trades must not be consolidated

    /// Two separate buys for the same equity must produce two distinct lots,
    /// each linked to its own transaction.  This is the core invariant that
    /// lets the UI display individual trades rather than a merged row.
    func testTwoSeparateBuysProduceTwoDistinctLots() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 400,
            fees: 0
        )

        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 50,
            price: 410,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2],
            instruments: [instrumentId: msft]
        )

        // Engine must produce exactly two lots — one per transaction
        XCTAssertEqual(output.equityLots.count, 2)

        let lot1 = output.equityLots.first { $0.transactionId == buy1.id }
        let lot2 = output.equityLots.first { $0.transactionId == buy2.id }

        XCTAssertNotNil(lot1, "No lot found linked to buy1")
        XCTAssertNotNil(lot2, "No lot found linked to buy2")

        XCTAssertEqual(lot1?.originalQuantity, 50)
        XCTAssertEqual(lot1?.remainingQuantity, 50)
        XCTAssertEqual(lot1?.pricePerShare, 400)

        XCTAssertEqual(lot2?.originalQuantity, 50)
        XCTAssertEqual(lot2?.remainingQuantity, 50)
        XCTAssertEqual(lot2?.pricePerShare, 410)

        // Both lots belong to the same instrument
        XCTAssertEqual(lot1?.instrumentId, instrumentId)
        XCTAssertEqual(lot2?.instrumentId, instrumentId)
    }

    /// The consolidated position for two separate buys must reflect the
    /// combined quantity and weighted-average cost — one Position per instrument.
    func testTwoSeparateBuysProduceOneAggregatePosition() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 400,
            fees: 0
        )

        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 50,
            price: 410,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2],
            instruments: [instrumentId: msft]
        )

        let equityPositions = output.positions.filter { $0.type == .equity }
        XCTAssertEqual(equityPositions.count, 1, "Must produce exactly one aggregate equity position")

        let position = equityPositions[0]
        XCTAssertEqual(position.quantity, 100)              // 50 + 50
        XCTAssertEqual(position.costBasis, 40_500)          // 50*400 + 50*410
        XCTAssertEqual(position.averagePrice, 405)          // 40500 / 100
    }

    /// The underlier summary must show the same aggregate numbers as the position.
    func testTwoSeparateBuysUnderlierSummaryIsAggregate() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 400,
            fees: 0
        )

        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 50,
            price: 410,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2],
            instruments: [instrumentId: msft]
        )

        let summary = output.underlierSummaries["MSFT"]
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalEquityShares, 100)
        XCTAssertEqual(summary?.totalEquityCostBasis, 40_500)
        XCTAssertEqual(summary?.averageEquityCost, 405)
    }

    /// Partially consuming a buy lot must leave the lot open with the correct
    /// remaining quantity, and produce a P/L record scoped to only the closed shares.
    /// The view relies on lot.isOpen + lot.remainingQuantity to render the open-remainder
    /// sub-row, and on realizedPLs scoped to openTransactionId for the closed-portion row.
    func testPartialSellLeavesLotOpenWithCorrectRemainder() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        // Use 100 shares so the partial-consumption ratio (50/100) is exactly representable
        let buy = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 100,
            price: 170,
            fees: 0
        )

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .sell,
            quantity: 50,
            price: 200,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy, sell],
            instruments: [instrumentId: msft]
        )

        // Lot must remain open with 50 shares left
        XCTAssertEqual(output.equityLots.count, 1)
        let lot = output.equityLots[0]
        XCTAssertTrue(lot.isOpen)
        XCTAssertEqual(lot.remainingQuantity, 50)
        XCTAssertEqual(lot.transactionId, buy.id)

        // P/L must reflect only the 50 closed shares, linked to the buy
        XCTAssertEqual(output.realizedPLs.count, 1)
        let pl = output.realizedPLs[0]
        XCTAssertEqual(pl.quantity, 50)
        XCTAssertEqual(pl.openTransactionId, buy.id)
        XCTAssertEqual(pl.transactionId, sell.id)
        XCTAssertEqual(pl.costBasis, 8_500)   // 50/100 * (100*170)
        XCTAssertEqual(pl.proceeds, 10_000)   // 50 * 200
        XCTAssertEqual(pl.realizedPL, 1_500)
    }

    /// When a single sell spans two buy lots (FIFO), each lot must produce its own
    /// P/L record with openTransactionId pointing back to the correct buy.
    /// This is the key engine invariant behind the assignment-split display.
    func testSellAcrossMultipleLotsProducesSeparatePLPerLot() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 150,
            fees: 0
        )

        // Use 100 shares for buy2 so 50/100 is exactly representable
        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 100,
            price: 170,
            fees: 0
        )

        // Sell 100: fully consumes lot1 (50) + partially consumes lot2 (50 of 100)
        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sell,
            quantity: 100,
            price: 200,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2, sell],
            instruments: [instrumentId: msft]
        )

        // Two P/L records — one per lot consumed
        XCTAssertEqual(output.realizedPLs.count, 2)

        let pl1 = output.realizedPLs.first { $0.openTransactionId == buy1.id }
        let pl2 = output.realizedPLs.first { $0.openTransactionId == buy2.id }

        XCTAssertNotNil(pl1, "No P/L found linked to buy1")
        XCTAssertNotNil(pl2, "No P/L found linked to buy2")

        // lot1: fully consumed — 50 shares
        XCTAssertEqual(pl1?.quantity, 50)
        XCTAssertEqual(pl1?.costBasis, 7_500)    // 50 * 150
        XCTAssertEqual(pl1?.proceeds, 10_000)    // 50 * 200
        XCTAssertEqual(pl1?.realizedPL, 2_500)
        XCTAssertEqual(pl1?.transactionId, sell.id)

        // lot2: partially consumed — 50 of 100 shares
        XCTAssertEqual(pl2?.quantity, 50)
        XCTAssertEqual(pl2?.costBasis, 8_500)    // 50/100 * (100*170)
        XCTAssertEqual(pl2?.proceeds, 10_000)    // 50 * 200
        XCTAssertEqual(pl2?.realizedPL, 1_500)
        XCTAssertEqual(pl2?.transactionId, sell.id)

        // Both P/Ls link to the same sell transaction
        XCTAssertEqual(pl1?.transactionId, pl2?.transactionId)

        // lot1 fully consumed, lot2 has 50 shares remaining
        let lot1 = output.equityLots.first { $0.transactionId == buy1.id }
        let lot2 = output.equityLots.first { $0.transactionId == buy2.id }
        XCTAssertFalse(lot1?.isOpen ?? true)
        XCTAssertTrue(lot2?.isOpen ?? false)
        XCTAssertEqual(lot2?.remainingQuantity, 50)
    }

    /// When a sell closes shares from multiple lots, each RealizedPL record must
    /// carry the correct openTransactionId pointing back to the buy it came from.
    func testRealizedPLLinksToCorrectOpeningTransaction() {
        let instrumentId = UUID()
        let msft = Instrument(id: instrumentId, symbol: "MSFT")

        let buy1 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            action: .buy,
            quantity: 50,
            price: 400,
            fees: 0
        )

        let buy2 = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            action: .buy,
            quantity: 50,
            price: 410,
            fees: 0
        )

        let sell = Transaction(
            instrumentId: instrumentId,
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            action: .sell,
            quantity: 50,
            price: 450,
            fees: 0
        )

        let output = LedgerEngine.process(
            transactions: [buy1, buy2, sell],
            instruments: [instrumentId: msft]
        )

        // Selling 50 shares closes the first lot (FIFO)
        XCTAssertEqual(output.realizedPLs.count, 1)
        let pl = output.realizedPLs[0]

        // Closing transaction must reference the sell
        XCTAssertEqual(pl.transactionId, sell.id)

        // Opening transaction must reference the first buy (FIFO)
        XCTAssertEqual(pl.openTransactionId, buy1.id)

        XCTAssertEqual(pl.quantity, 50)
        XCTAssertEqual(pl.costBasis, 20_000)    // 50 * 400
        XCTAssertEqual(pl.proceeds, 22_500)     // 50 * 450
        XCTAssertEqual(pl.realizedPL, 2_500)

        // First lot fully consumed, second lot still open
        let lot1 = output.equityLots.first { $0.transactionId == buy1.id }
        let lot2 = output.equityLots.first { $0.transactionId == buy2.id }
        XCTAssertEqual(lot1?.remainingQuantity, 0)
        XCTAssertEqual(lot2?.remainingQuantity, 50)
    }
}
