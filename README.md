# Portfolio Ledger

A tax-correct investment trade journal iOS app built with Swift and SwiftUI. Replaces spreadsheet-based trade tracking with a clean, ledger-first mobile experience optimized for manual trade entry.

## Overview

Portfolio Ledger is designed for active traders who need accurate FIFO cost basis tracking for equities and options. The app prioritizes correctness over convenience, treating every trade as an immutable ledger entry and computing all positions, lots, and P/L dynamically.

**This is not a broker replacement and not a forecasting tool.** It's a journal that gives you tax-accurate records and clear visibility into your realized and unrealized positions.

## Core Features

- **Immutable Ledger Architecture**: Every trade is a permanent record; positions and P/L are computed, never edited
- **FIFO Cost Basis Tracking**: Tax-compliant lot accounting for equities and options
- **Option Assignment Handling**: Automatic generation of equity trades at effective prices when options are assigned
- **Multiple Account Support**: Track trades across different brokerage accounts
- **CSV Export/Import**: Round-trip data portability
- **Clean, Minimal UI**: Robinhood-inspired design focused on information density and ease of use

## What's Included (MVP)

### Trade Types
- Equity buy/sell
- Single-leg option trades (buy/sell to open/close)
- Covered calls and covered puts
- Option assignment and exercise

### Views
- **Dashboard**: Total P/L, open positions summary, recent activity
- **Positions**: Grouped by underlying symbol with equity and option details
- **Ledger**: Chronological transaction history with search and filters
- **Underlier Detail**: Per-symbol view of positions, cost basis, and realized P/L

### Data Management
- Account management
- CSV export of accounts, instruments, and transactions
- CSV import with round-trip support
- Local persistence with JSON storage

## What's NOT Included (v1)

- Multi-leg options (spreads, iron condors, etc.)
- Wash sale tracking
- Corporate actions (splits, mergers, spinoffs)
- Dividends and interest
- Broker API integration
- Tax form generation (1099, Schedule D)
- Forecasting or projections

## Architecture

### Data Models

The app is built on three core data models:

1. **Account**: Represents a brokerage account
2. **Instrument**: Equity or option contract definition
3. **Transaction**: Immutable ledger entry for every trade

All other data (lots, positions, P/L) is derived by the LedgerEngine.

### LedgerEngine

The `LedgerEngine` is a pure Swift computation engine that processes transactions into:

- **Equity Lots**: FIFO lots tracking cost basis for open positions
- **Option Lots**: FIFO lots for open option contracts
- **Realized P/L**: Per-trade profit/loss records
- **Positions**: Current net positions by instrument
- **Underlier Summaries**: Aggregated view by underlying symbol

The engine handles:
- FIFO lot consumption for partial position closes
- Option premium accounting
- Assignment workflow (option close + equity trade generation)

### File Structure

```
PortfolioLedger/
├── Models/
│   ├── Account.swift
│   ├── Instrument.swift
│   ├── Transaction.swift
│   └── DerivedData.swift
├── Engine/
│   └── LedgerEngine.swift
├── Views/
│   ├── DashboardView.swift
│   ├── PositionsView.swift
│   ├── TransactionsView.swift
│   ├── UnderlierDetailView.swift
│   ├── SettingsView.swift
│   └── TradeEntry/
│       ├── AddEquityTradeView.swift
│       ├── AddOptionTradeView.swift
│       ├── AssignOptionView.swift
│       └── TradeEntryMenuView.swift
├── ViewModels/
├── Services/
│   ├── DataStore.swift
│   └── CSVService.swift
├── App/
│   ├── PortfolioLedgerApp.swift
│   └── ContentView.swift
└── Resources/
```

## FIFO Rules

### Equities
1. Every buy creates a new FIFO lot
2. Every sell consumes the oldest open lot first
3. Buy fees increase cost basis
4. Sell fees reduce proceeds
5. Realized P/L = proceeds - cost basis (per consumed lot)

### Options
1. Sell-to-open and buy-to-open create contract lots
2. Buy-to-close consumes sell-to-open lots (FIFO)
3. Sell-to-close consumes buy-to-open lots (FIFO)
4. Premium is the transaction amount (price × contracts)

### Assignment
When an option is assigned:
- **Covered Put**: Generates equity BUY at `strike - (premium per share)`
- **Covered Call**: Generates equity SELL at `strike + (premium per share)`

The option position is closed, and the premium is marked as consumed. The generated equity trade uses an effective price that preserves tax-accurate cost basis.

## Getting Started

### Requirements
- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+

### Building the App

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/portfolio-ledger-app.git
   cd portfolio-ledger-app
   ```

2. Open in Xcode:
   - Create a new iOS App project in Xcode
   - Replace the default files with the `PortfolioLedger/` directory contents
   - Build and run on simulator or device

3. Or use the files directly:
   - The code is organized in a module-like structure
   - All Swift files can be added to an Xcode project
   - No external dependencies required

### First Steps

1. **Add an Account**: Go to Settings → Add Account
2. **Enter Your First Trade**: Use the "+" button on the Dashboard
3. **View Positions**: Check the Positions tab to see your holdings
4. **Review Ledger**: All transactions appear in the Ledger tab

## Usage Examples

### Recording an Equity Purchase
1. Tap "+" → "Buy/Sell Stock"
2. Select account
3. Enter symbol, quantity, price, and fees
4. Tap "Add"

### Selling a Covered Call
1. Tap "+" → "Option Trade"
2. Select "Sell to Open"
3. Enter underlying symbol, strike, expiry, contracts, and premium
4. Tap "Add"

### Processing Option Assignment
1. Find the option transaction in the Ledger
2. Tap to view details
3. Select "Assign Option"
4. Choose assignment date
5. Review the generated equity trade preview
6. Confirm

The app automatically:
- Closes the option position at $0
- Creates an equity trade at the effective price
- Marks the option premium as consumed

## Data Export/Import

### Export
1. Go to Settings → Export CSV
2. Files are saved to the app's Documents directory:
   - `accounts.csv`
   - `instruments.csv`
   - `transactions.csv`

### Import
1. Place CSV files in the app's Documents directory
2. Go to Settings → Import CSV
3. Select the files to import

CSV files use standard formatting and can be edited in spreadsheet software for bulk operations.

## Design Philosophy

The app follows these principles:

1. **Ledger Integrity**: No direct editing of positions or cost basis
2. **Tax Correctness**: FIFO lot accounting matches IRS requirements
3. **Minimal UI**: Information density without clutter
4. **Fast Entry**: Optimized workflows for common operations
5. **No Forecasting**: Show actual data, not projections

The visual design is inspired by modern fintech apps (Robinhood, Wealthfront) with:
- Clean typography (SF Pro)
- Minimal chrome and borders
- Card-based layouts
- Green/red for P/L
- Subtle shadows and plenty of whitespace

## Development Roadmap

### Potential v2 Features
- Multi-leg option strategies
- Wash sale detection and tracking
- Corporate action handling
- Dividend and interest tracking
- Real-time price integration
- Advanced filtering and search
- Tax form exports

### Known Limitations
- No wash sale adjustments
- No support for short stock positions
- No automatic broker syncing
- Options are single-leg only

## Contributing

This is a personal project, but contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

Please maintain the core principles:
- Ledger immutability
- FIFO correctness
- Simplicity over features

## License

MIT License - see LICENSE file for details

## Acknowledgments

Built to replace a Numbers spreadsheet with 200+ rows of manual FIFO calculations. Inspired by the need for tax-correct trade tracking without the complexity of enterprise portfolio software.

## Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Check the documentation in this README
- Review the source code (it's heavily commented)

## Technical Notes

### Data Persistence
- All data is stored locally in JSON format
- File location: `~/Documents/portfolio_data.json`
- No cloud sync (intentional for privacy)

### Performance
- Ledger recomputation happens on every transaction change
- Optimized for up to 10,000 transactions
- No pagination required for typical use cases

### Testing
The app includes:
- Pure functional LedgerEngine (easily testable)
- Sample data generation for development
- CSV round-trip testing capability

---

**Built with Swift and SwiftUI. Designed for traders who care about correctness.**
