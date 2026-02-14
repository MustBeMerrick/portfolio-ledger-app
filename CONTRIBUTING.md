# Contributing to Portfolio Ledger

Thank you for your interest in contributing! This guide will help you get started.

## Core Principles

Before contributing, please understand the project's core values:

1. **Ledger Integrity**: Transactions are immutable; positions are computed
2. **FIFO Correctness**: Tax compliance is non-negotiable
3. **Simplicity**: Features should add value without complexity
4. **No Forecasting**: This is a journal, not a prediction engine

If a feature compromises any of these principles, it won't be accepted.

## Ways to Contribute

### 1. Bug Reports

Found a bug? Help us fix it:

- **Check existing issues** first to avoid duplicates
- **Include details**:
  - Steps to reproduce
  - Expected vs actual behavior
  - iOS version and device
  - Screenshots if relevant
- **Share sample data** (CSV export) if possible

### 2. Feature Requests

Have an idea? We'd love to hear it:

- **Explain the use case**: Why do you need this feature?
- **Describe the solution**: What should it do?
- **Consider alternatives**: Are there other ways to solve it?
- **Align with principles**: Does it fit the project's goals?

### 3. Code Contributions

Ready to code? Follow these steps:

#### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/portfolio-ledger-app.git
   cd portfolio-ledger-app
   ```
3. Set your development team in `Config/Local.xcconfig` (git-ignored):
   ```
   LOCAL_DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```
   Never change signing via Xcode's UI — it modifies the project file.
   See SETUP.md for details.
4. Create a branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

#### Development Guidelines

**Code Style**
- Follow Swift naming conventions
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small

**SwiftUI Best Practices**
- Prefer composition over inheritance
- Extract reusable components
- Use `@State`, `@Binding`, `@EnvironmentObject` appropriately
- Keep views simple and declarative

**Data Model Rules**
- Never mutate transactions after creation
- All derived data must come from LedgerEngine
- Keep models Codable for persistence
- Use Decimal for all financial calculations (never Double)

**Testing**
- Test LedgerEngine logic thoroughly
- Verify FIFO correctness
- Test edge cases (partial closes, assignments)
- Include CSV round-trip tests

#### Architecture Overview

```
Models (Codable, Immutable)
    ↓
Transactions (Persisted)
    ↓
LedgerEngine (Pure Functions)
    ↓
Derived Data (Lots, Positions, P/L)
    ↓
Views (SwiftUI, Read-only)
```

**Key Files**:
- `LedgerEngine.swift`: Core business logic
- `DataStore.swift`: State management
- `Transaction.swift`: Immutable ledger entries
- Views: UI components (no business logic)

#### Making Changes

1. **Edit the code**
2. **Test locally**:
   - Build in Xcode (Cmd+B)
   - Run on simulator (Cmd+R)
   - Test affected features
3. **Add CSV export/import tests** if touching data models
4. **Update documentation** if changing APIs or adding features

#### Commit Guidelines

Write clear commit messages:

```
Good:
- "Add option roll workflow"
- "Fix FIFO calculation for partial closes"
- "Improve dashboard P/L display"

Bad:
- "Update code"
- "Fix bug"
- "Changes"
```

Use this format:
```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Include context, reasoning, and any trade-offs.

Fixes #123
```

#### Pull Request Process

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a Pull Request**:
   - Go to GitHub
   - Click "New Pull Request"
   - Select your branch
   - Fill in the template:
     - What does this PR do?
     - Why is it needed?
     - How was it tested?
     - Screenshots (if UI changes)

3. **Code Review**:
   - Respond to feedback
   - Make requested changes
   - Push updates to your branch

4. **Merge**:
   - PR will be merged once approved
   - Your contribution will be credited

## Specific Contribution Areas

### High Priority

- **Test Coverage**: Add unit tests for LedgerEngine
- **Error Handling**: Better user feedback for invalid inputs
- **Documentation**: Improve code comments and guides
- **Performance**: Optimize for large transaction sets (10k+)

### Good First Issues

- Add input validation to trade entry forms
- Improve date picker UX
- Add more detailed P/L breakdowns
- Create sample data generators
- Write more comprehensive CSV import error handling

### Advanced Features (v2)

- Multi-leg option strategies
- Wash sale tracking
- Corporate action handling
- Tax form exports
- Advanced reporting

## Code Review Checklist

Before submitting, verify:

- [ ] Code builds without warnings
- [ ] No force unwraps (`!`) without safety checks
- [ ] Decimal used for all money values
- [ ] Transactions remain immutable
- [ ] FIFO logic is correct
- [ ] CSV export/import works (if touched)
- [ ] UI follows design principles
- [ ] Comments explain "why", not "what"
- [ ] No unnecessary dependencies added

## Questions?

- **Architecture**: Read README.md
- **Setup**: Read SETUP.md
- **Usage**: Read QUICKSTART.md
- **Still stuck?**: Open a discussion on GitHub

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

All contributors will be acknowledged in the README. Significant contributions may earn you maintainer status.

Thank you for helping make Portfolio Ledger better!
