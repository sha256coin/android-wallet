# Changelog

All notable changes to this project are documented in this file.

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
