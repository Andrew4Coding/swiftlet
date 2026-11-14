# Glossary

Domain terms. Use the **Code name** in Swift identifiers so specs and code read the same way.

| Term | Code name | Meaning |
|---|---|---|
| Transaction | `Transaction` | An expense, income or transfer |
| Category | `TransactionCategory` | Emoji and colour (legacy purpose and monthly budget fields are unused) |
| Wallet | `Wallet` | User-defined money source; balance is derived from transactions |
| Recurring transaction | `RecurringTransaction` | A schedule that materializes transactions |
| Money source | `MoneySource` | Legacy fixed wallet list, kept only for `WalletMigrator` |
