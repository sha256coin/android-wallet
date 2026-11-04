# Changelog

All notable changes to this project are documented in this file.

## [1.7.1] - Play Store versionCode 10

### Added

- Markets tab: the NestEx exchange (S256/USDT) and the S256/USDC pair on FynEx. The list now shows the newest listing first.

### Changed

- The status line at the top of the wallet scrolls by itself, slowly and smoothly in a loop, when its items do not fit the width. It pauses while you touch it (you can still drag it) and stays still when the phone asks for reduced motion.
- Camera scanner library mobile_scanner 7.4.2 -> 7.5.0.

## [1.7.0] - Play Store versionCode 9

The look of S256 web wallet 3.0 on the phone, faster sends from wallets with many coins, and a real balance chart.

### Fixed

- Sending from a wallet with many UTXOs took a long time: before signing, the app asked the node for every UTXO's script with a separate `gettxout` call, one after another (200 UTXOs meant 200 round trips, tens of seconds on mobile data). The script now comes from the `scantxoutset` answer the app already has, so a send needs no extra lookups. A script that is not the wallet address's own is not trusted and is still looked up. Advanced send (coin control) gets the same speed-up.
- Balance chart: the gridlines and their values used steps of a fifth of the highest balance, which gave uneven numbers. They are now round (1, 2 or 5 × 10ⁿ).

### Added

- A status line at the top of the wallet: connection, block height, network hashrate, peers and the S256 price. It reads the node every two minutes and turns amber when the node cannot be reached.
- 24h price change from the S256 explorer, on the Markets tab and next to the USD value, shown only while there is a live price (LiveCoinWatch has none while no market trades S256).

### Changed

- Balance card: amber corner brackets, the balance in large platinum figures with a slow sheen, the USD value and the last-traded date or 24h change under it, and the pending state as a badge.
- Balance chart: time along the bottom instead of transaction order, a stepped line (the balance only changes at a transaction), round gridlines with their values, green and red markers for coins in and out, and a readout with date, balance and change when you touch a transaction or slide along the chart. A dashed step at the right edge shows a pending total. The chart library (fl_chart) is no longer needed.
- Network Status screen: block height, hashrate, difficulty and peers as large figures, then the mempool and node details (with the best block).
- Every dialog has the same corner-bracket frame, and section titles are small mono labels ("// RECENT TRANSACTIONS"), as in the web wallet.
- Bottom bar: names under the icons (Wallet, Markets, Contacts, Settings) and an amber line over the open tab.
- Setup screen: the grid background and the coin inside a slowly turning ring instead of the photo. Animations stop when the phone asks for reduced motion.
- The background grid matches the website (48px cells with an amber glow, fading towards the bottom).
- The remaining fixed white, black, orange, green and cyan colours now use the app's colours. The receive QR code stays on pure white.
- Removed unused files: the background photo and two Roboto fonts (a smaller app).

## [1.6.6] - Play Store versionCode 8

### Added

- Payment requests are read in full. Scanning or pasting a `sha256coin:` payment request, or a link from the S256 web wallet (`https://sha256coin.eu/web-wallet/#pay=...`), fills in the address and the amount, and a card shows the requested amount, the name and the note. Same format and rules as web wallet 2.9.
- The name and note in a request are written by whoever made it, so they are shown as "not verified". A saved contact is shown as verified when the address matches, and a request that uses a saved contact's name for a different address gets a red warning. Hidden and text-direction characters are removed.
- Receive: sharing a payment request includes a web wallet pay link and the `sha256coin:` request itself, so it can be paid from the web wallet or pasted into this app.
- Address book: a Send button on each contact opens Send with the address filled in.
- Address book: scanning a QR with a name (for example `?label=miner-3`) fills in the name too, unless a contact already has that name.

- Live price is back: the S256 price from LiveCoinWatch (read through the S256 explorer, so no API key is in the app) shows under the balance as an approximate USD value, and on the Markets tab with 24h volume, market cap and liquidity. Nothing is shown while LiveCoinWatch has no price for S256.

### Changed

- New look that matches sha256coin.eu: graphite background with a faint grid, flat square cards with thin borders and small uppercase titles, a single amber accent instead of purple and cyan, and square buttons and inputs. Chakra Petch (headings and balance), IBM Plex Sans (text) and IBM Plex Mono (addresses) are bundled with the app. Secondary text is lighter for better contrast.
- Markets tab redesigned with the content of sha256coin.eu/markets: exchanges (FynEx, Rabid Rabbit) with pair, type and a ticker warning, the market data trackers (CoinCarp, CoinCodex, LiveCoinWatch), and four safety checks before using an exchange. The notices moved to the bottom.
- Balance chart: the explorer's per-transaction balance restarts at 0 on every page of 50 transactions, so the chart showed too low a line for wallets with many transactions. It is now drawn back from the real balance.
- Request Amount (Receive): the amount must be above 0 with at most 8 decimals, and is saved in a standard form (`01.50` becomes `1.5`). The note is limited to 200 characters.

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
