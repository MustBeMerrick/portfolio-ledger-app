# Quick Start Guide

Get up and running with Portfolio Ledger in 5 minutes.

## Installation

### Prerequisites
- Mac with macOS 13+ (Ventura or later)
- Xcode 14+
- iOS device or simulator running iOS 16+

### Steps

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd portfolio-ledger-app
   ```

2. **Create Xcode Project**:
   - Open Xcode
   - File → New → Project
   - Choose iOS → App
   - Name: `PortfolioLedger`
   - Interface: SwiftUI, Language: Swift
   - Save in this directory
   - Delete auto-generated ContentView.swift and PortfolioLedgerApp.swift
   - Add the `PortfolioLedger/` folder to the project

3. **Build and Run**:
   - Select iPhone 14 Pro simulator
   - Press Cmd+R
   - App launches with a sample account

## First Use

### 1. Add Your Brokerage Account

- Tap **Settings** tab
- Tap **Add Account**
- Fill in:
  - Name: "My Brokerage" (or your broker name)
  - Broker: "Interactive Brokers" (or your broker)
  - Currency: "USD"
- Tap **Save**

### 2. Record Your First Trade

#### Buy Stock
- Tap **Dashboard** tab
- Tap the **+** button
- Select **Buy/Sell Stock**
- Fill in:
  - Account: Select your account
  - Action: **Buy**
  - Symbol: AAPL
  - Quantity: 100
  - Price per Share: 150.00
  - Fees: 1.00
  - Trade Date: (today)
- Tap **Add**

#### View Your Position
- Tap **Positions** tab
- See AAPL listed with:
  - 100 shares
  - Avg Cost: $150.01/share
  - Total Basis: $15,001.00

### 3. Sell Some Shares (FIFO)

- Tap **+** → **Buy/Sell Stock**
- Fill in:
  - Action: **Sell**
  - Symbol: AAPL
  - Quantity: 50
  - Price per Share: 155.00
  - Fees: 1.00
- Tap **Add**

#### Check Realized P/L
- Tap **Dashboard**
- See your realized P/L: **$248.50**
  - Calculation: (155 × 50 - 1) - (150.01 × 50) = $248.50

### 4. Sell a Covered Call

- Tap **+** → **Option Trade**
- Fill in:
  - Action: **Sell to Open**
  - Underlying: AAPL
  - Type: **Call**
  - Strike: 160.00
  - Expiry: (30 days from today)
  - Contracts: 1
  - Premium: 3.50 (per contract)
  - Fees: 0.65
- Tap **Add**

#### View in Positions
- Tap **Positions** → AAPL
- See:
  - 50 shares (equity)
  - 1 option contract (call, short)

### 5. Option Assignment (Advanced)

If your call gets assigned:

- Go to **Ledger** tab
- Find your "Sell to Open" transaction
- Tap on it
- Tap **Assign Option** (if available)
- Select assignment date
- Review the preview:
  - Option closes at $0
  - 100 shares sold at $163.50 (strike + premium per share)
- Tap **Confirm**

The app automatically:
- Closes your option position
- Sells 100 shares at the effective price
- Calculates correct FIFO P/L

## Common Workflows

### Recording Multiple Buys (DCA)

1. Buy 100 shares @ $150
2. Buy 50 shares @ $145
3. Sell 75 shares @ $155

The app will consume:
- First 50 from the $150 lot
- Next 25 from the $145 lot
- Remaining positions: 75 shares (50 @ $150, 25 @ $145)

### Tracking Covered Call Wheel

1. Sell Cash-Secured Put (Sell to Open Put)
2. If assigned: Use **Assign Option** → Generates stock purchase
3. Sell Covered Call (Sell to Open Call)
4. If assigned: Use **Assign Option** → Generates stock sale
5. Repeat

All P/L is automatically calculated with correct cost basis.

## Data Management

### Export Your Data

- Settings → **Export CSV**
- Files saved to app's Documents folder:
  - `accounts.csv`
  - `instruments.csv`
  - `transactions.csv`

### Import Data

- Place CSV files in Documents folder
- Settings → **Import CSV**
- Select files to import

## Tips

### Speed Up Entry

- Use iOS keyboard shortcuts
- The app remembers last-used account
- Symbol field auto-capitalizes
- Date defaults to today

### Check Your Numbers

- Dashboard shows total P/L
- Positions shows cost basis
- Ledger shows all trades chronologically
- Underlier view shows per-symbol breakdown

### Understand FIFO

- Oldest shares sell first
- Cost basis is weighted average across lots
- Each trade's P/L is independent
- Total P/L = sum of all realized P/L

## Troubleshooting

### Trade Not Showing
- Check Positions tab (might be offset by another trade)
- Verify instrument matches (symbols are case-sensitive)
- Look in Ledger for the transaction

### P/L Doesn't Match Expectations
- Review FIFO rules (oldest lots sell first)
- Check fees (they affect P/L)
- Verify prices and quantities
- Look at individual lot consumption in code

### App Crashes
- Check console for errors
- Ensure valid decimal inputs
- Verify all required fields are filled

## Next Steps

- Read [README.md](README.md) for architecture details
- See [SETUP.md](SETUP.md) for Xcode project setup
- Review source code for customization
- Add your historical trades
- Export regularly for backups

## Example Data Set

Try this sequence to understand the app:

```
1. Buy 100 AAPL @ 150.00
2. Buy 100 AAPL @ 145.00
3. Sell 150 AAPL @ 155.00
4. Sell to Open 1 AAPL Call, Strike 160, Premium 3.50
5. Assign the call
```

Expected results:
- Equity P/L from sells: ~$912
- Option premium: $350
- Final position: Flat (no shares)
- Total realized P/L: ~$1,262

---

**You're ready to track your trades with tax-accurate precision!**
