# Changelog

All notable changes to this project are documented in this file.

## [1.6.5] - Play Store versionCode 7

### Security

- Fingerprint lock now covers every screen. Before, returning to the app locked only the home screen: a screen opened on top of it (Send, Receive, Settings, a dialog) stayed visible and usable without unlocking. The lock is now shown on top of everything, the back button cannot close it, and the screen you were on comes back unchanged after unlocking.

### Fixed

- Address book export on Android could leave old data at the end of the file when saving over an older, longer export, so the file could not be imported again. Export now writes through the app itself with truncation and checks the saved size. Import recovers files damaged this way when the export at the start is complete and its contact count matches.
- Transaction history no longer flashes "No Transactions Yet" on refresh. The list stays on screen until fresh data arrives, and stays when the explorer cannot be reached (the fallback explorer API no longer reports a failed request as an empty history).
- Startup: the start screen waited for the UTXOs and then the transaction history, one after the other. It now waits only for the wallet to load from the device; balance and history load in parallel afterwards while the wallet screen shows its loading placeholders.

### Changed

- Android build: Gradle 9.8.0, Android Gradle Plugin 9.4.1, Kotlin 2.4.20; Flutter package updates (flutter_secure_storage 11.2.0, mobile_scanner 7.4.2 and others).

## [1.6] - 2026-08-02

### Added

- Batch-send candidate assessment and decision flow in mobile send UX.
- Retry-as-batch prompt path for likely single-transaction size/mempool failures.
- Batch-aware send acknowledgements with txid list handling.
- Partial-batch migration safety flow with backup guidance and follow-up actions.
- Recovery dialog path when migration tx broadcast succeeds but post-broadcast finalization fails (with TXID copy support).
- Compact confirmation label formatting (`K/M/B/T`) for advanced send UTXO rows.

### Changed

- Migration sweep path now routes through provider send flow with batch support enabled.
- Post-migration wallet load now resets transient runtime send state for cleaner switching.
- Remaining-funds migration guidance expanded with manual transfer instructions and retry option.
- Address Book tab added to bottom navigation for direct in-app access.
- Receive QR rendering switched to static display and bounded responsive sizing for better tablet scan fit.
- Removed unused provider-level `migrateToSeed` path to keep Settings migration as the single active flow.

### Fixed

- Send view parity and wiring stabilized against duplicated/legacy flow drift.
- Address book export flow now writes reliably to selected file path.
- Manual-fee and retry-as-batch send branches now surface accurate failure/cancel messaging.

## [1.5] - 2026-06-22

### Added

- Fully non-custodial mobile transaction flow with local signing.
- Advanced send mode with coin control (manual UTXO selection).
- Send preview panel with selected inputs, amount, estimated fee, and expected change.
- Added in-app Regulatory Notice view and navigation from Settings/About.

### Changed

- Address validation alignment for modern and legacy formats in send flow.
- Exchange view redesigned as informational/compliance-oriented surface.
- Privacy policy metadata refreshed (updated date + revision tag).

### Fixed

- Improved pending-transaction handling for selected confirmed/free UTXOs.
