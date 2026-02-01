# Quick Start Guide

Get Portfolio Ledger running in under 5 minutes.

## Prerequisites

- macOS with Xcode 26.0+ installed
- iOS 26.0+ simulator or device

## Run the App

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd portfolio-ledger-app
   ```

2. **Set your development team** (first time only)
   ```bash
   # Edit Config/Local.xcconfig and add your team ID:
   echo "LOCAL_DEVELOPMENT_TEAM = YOUR_TEAM_ID" > Config/Local.xcconfig
   ```
   Find your Team ID in Xcode → Settings → Accounts

3. **Open and run**
   ```bash
   open PortfolioLedger/PortfolioLedger.xcodeproj
   ```
   Then press Cmd+R to build and run

## First Steps

1. **Add an Account**: Tap Settings → Add Account
2. **Record a Trade**: Tap "+" on Dashboard → Buy/Sell Stock
3. **View Positions**: Check the Positions tab
4. **Review Ledger**: See all transactions in the Ledger tab

For detailed setup and troubleshooting, see **SETUP.md**.