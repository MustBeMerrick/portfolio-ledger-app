# Setup Guide

This repo already contains an Xcode project for the PortfolioLedger iOS app.
Do **not** create a new Xcode project — just open the existing one.

## Quick Start

1. Install Xcode 26.0+ from the App Store.

2. Configure signing (first time only):
   - Edit `Config/Local.xcconfig` and set your development team ID:
     ```
     LOCAL_DEVELOPMENT_TEAM = YOUR_TEAM_ID
     ```
   - Find your Team ID in Xcode → Settings → Accounts, or at
     https://developer.apple.com/account under Membership Details.
     It is a 10-character alphanumeric string (e.g. `A1B2C3D4E5`).

   > **Important:** Do NOT change signing settings through Xcode's
   > "Signing & Capabilities" UI. The Xcode GUI writes `DEVELOPMENT_TEAM`
   > directly into the `.pbxproj` file, which overrides the xcconfig value
   > and creates a diff in version control. Always set your team via
   > `Local.xcconfig` only.

3. Open the existing project:
   ```bash
   open PortfolioLedger/PortfolioLedger.xcodeproj
   ```

### Build Configuration

The project uses xcconfig files for build settings:

- **`Config/Base.xcconfig`**: Shared settings (bundle ID, deployment target, version)
- **`Config/Local.xcconfig`**: Your development team ID (git-ignored, customize per machine)
- **`PortfolioLedger/Shared.xcconfig`**: Includes both Base and Local configs

This setup keeps your personal signing settings out of version control.

## Build & Run

1. Pick a simulator (or a device).
2. Cmd+R

## Project Structure

```
portfolio-ledger-app/
├── Config/
│   ├── Base.xcconfig           # Shared build settings
│   └── Local.xcconfig          # Your dev team (git-ignored)
│
└── PortfolioLedger/
    ├── PortfolioLedger.xcodeproj/
    ├── Shared.xcconfig         # Includes Base & Local
    ├── Assets.xcassets/
    │
    ├── App/
    │   ├── PortfolioLedgerApp.swift
    │   └── ContentView.swift
    │
    ├── Models/
    │   ├── DerivedData.swift
    │   ├── Instrument.swift
    │   └── Transaction.swift
    │
    ├── Engine/
    │   └── LedgerEngine.swift
    │
    ├── Services/
    │   ├── DataStore.swift
    │   └── CSVService.swift
    │
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
    │       ├── ClosePositionView.swift
    │       └── TradeEntryMenuView.swift
    │
    └── Resources/
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
   - Verify `DataStore.shared` is initialized correctly
   - Ensure all `@EnvironmentObject` dependencies are provided

2. **Data not persisting**:
   - Check that the app has write permissions to Documents directory
   - Look for errors in DataStore's save/load methods

## Development Tips

### Running on Simulator

1. Select any iPhone/iPad simulator that meets the project’s deployment target
2. Press Cmd+R to run

### Running on Device

1. Connect your iPhone/iPad via USB
2. Select your device in Xcode
3. If you see "Signing" errors, verify your `Config/Local.xcconfig`
   contains the correct Team ID — do not use the Xcode Signing UI.
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

## .gitignore

The following are already git-ignored:

- `Config/Local.xcconfig` (developer-specific signing)
- `PortfolioLedger.xcodeproj/xcuserdata/`
- `PortfolioLedger.xcodeproj/project.xcworkspace/xcuserdata/`
- `.DS_Store`
- Xcode build artifacts

## Next Steps

Once the app is running:

1. **Add Your Accounts**: Settings → Add Account
2. **Enter Real Trades**: Use the "+" button to add historical trades
3. **Export Data**: Settings → Export CSV to backup your data
4. **Customize**: Modify views, add features, or adjust styling

## Additional Resources

- SwiftUI Documentation: https://developer.apple.com/documentation/swiftui
- Xcode Help: https://developer.apple.com/xcode

## Support

For issues or questions:
- Check the README.md for architecture details
- Review the source code
- Open an issue on GitHub
