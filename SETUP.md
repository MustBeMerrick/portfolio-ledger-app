# Setup Guide

This guide will help you create an Xcode project and build the Portfolio Ledger iOS app.

## Quick Start (Xcode Project)

### Option 1: Create New Xcode Project

1. **Open Xcode** and select "Create a new Xcode project"

2. **Choose Template**:
   - Select "iOS" → "App"
   - Click "Next"

3. **Project Settings**:
   - Product Name: `PortfolioLedger`
   - Team: Select your development team
   - Organization Identifier: `com.yourname.portfolioledger`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Storage: `None`
   - Click "Next"

4. **Save Location**:
   - Choose this repository directory
   - Click "Create"

5. **The project is already set up!**:
   - All source files are in the `PortfolioLedger/` directory
   - The Xcode project file is `PortfolioLedger/PortfolioLedger.xcodeproj`
   - Just open the project and build!

6. **Configure Info.plist** (if needed):
   - The Info.plist in Resources/ contains the necessary configuration
   - Xcode 14+ typically generates this automatically

7. **Build and Run**:
   - Select an iOS simulator or device
   - Press Cmd+R to build and run

### Option 2: Using Swift Package Manager

You can also use this as a Swift package:

```bash
# Navigate to the project directory
cd portfolio-ledger-app

# Build the package
swift build

# Run tests (if you add them)
swift test
```

Note: The Package.swift is configured for library development. For the iOS app, use Option 1.

## Project Structure in Xcode

After adding files, your Xcode project should look like this:

```
PortfolioLedger (project)
├── App
│   ├── PortfolioLedgerApp.swift
│   └── ContentView.swift
├── Models
│   ├── Account.swift
│   ├── Instrument.swift
│   ├── Transaction.swift
│   └── DerivedData.swift
├── Engine
│   └── LedgerEngine.swift
├── Views
│   ├── DashboardView.swift
│   ├── PositionsView.swift
│   ├── TransactionsView.swift
│   ├── UnderlierDetailView.swift
│   ├── SettingsView.swift
│   └── TradeEntry
│       ├── AddEquityTradeView.swift
│       ├── AddOptionTradeView.swift
│       ├── AssignOptionView.swift
│       └── TradeEntryMenuView.swift
├── ViewModels (empty for now)
├── Services
│   ├── DataStore.swift
│   └── CSVService.swift
└── Resources
    └── Info.plist
```

## Troubleshooting

### Build Errors

If you see compilation errors:

1. **"Cannot find type X in scope"**:
   - Make sure all files are added to the target
   - Check that all files are in the same module
   - Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)

2. **"Multiple commands produce..."**:
   - Check for duplicate file references
   - Remove duplicate files from Build Phases → Compile Sources

3. **SwiftUI Preview Issues**:
   - Previews may not work initially
   - Build the project first (Cmd+B)
   - Try Resume Preview or restart Xcode

### Runtime Issues

1. **App crashes on launch**:
   - Check the debug console for errors
   - Verify DataStore.shared is initialized correctly
   - Ensure all @EnvironmentObject dependencies are provided

2. **Data not persisting**:
   - Check that the app has write permissions to Documents directory
   - Look for errors in DataStore's save/load methods

## Development Tips

### Running on Simulator

1. Select iPhone 14 Pro or later (iOS 16+)
2. Press Cmd+R to run
3. Use Cmd+Shift+H to go home
4. Use Debug → Location to test location features (if needed)

### Running on Device

1. Connect your iPhone/iPad via USB
2. Select your device in Xcode
3. If you see "Signing" errors:
   - Go to project settings → Signing & Capabilities
   - Select your Team
   - Xcode will automatically fix signing
4. Press Cmd+R to run

### Testing Data Entry

The app starts with a sample account. To test:

1. Add a few equity trades (Buy → Sell)
2. Add an option trade (Sell to Open)
3. View the Dashboard to see P/L
4. Check Positions to see FIFO lots
5. Go to Ledger to see all transactions

### Viewing Persisted Data

Data is saved to:
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/portfolio_data.json
```

To find it:
1. Run the app in simulator
2. Print the Documents directory in DataStore
3. Open in Finder using Cmd+Shift+G

## Next Steps

Once the app is running:

1. **Add Your Accounts**: Settings → Add Account
2. **Enter Real Trades**: Use the "+" button to add historical trades
3. **Export Data**: Settings → Export CSV to backup your data
4. **Customize**: Modify views, add features, or adjust styling

## Additional Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Xcode Help](https://developer.apple.com/xcode/)

## Support

For issues or questions:
- Check the README.md for architecture details
- Review the source code (it's documented)
- Open an issue on GitHub
