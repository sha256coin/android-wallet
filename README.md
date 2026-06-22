# S256 Wallet

<p align="center">
  <img src="public/s256_wallet_icon.png" alt="S256 Wallet" width="128">
</p>

<p align="center">
  <strong>Mobile wallet for SHA256coin (S256)</strong><br>
  Built with Flutter for Android & iOS
</p>

<p align="center">
  <a href="https://sha256coin.eu">Website</a> •
  <a href="https://explorer.sha256coin.eu">Explorer</a>
</p>

## Features

- **BIP39 Seed Phrase Support**: Create or restore wallets using 12 or 24-word recovery phrases.
- **Cross-Platform Compatibility**: Uses standard derivation path `m/44'/0'/0'/0/0` (same as Web Wallet 2.0).
- **Advanced Recovery**: Support for raw private key (WIF) recovery and generation.
- **Fully Non-Custodial Sending**: Transactions are built and signed locally on-device before broadcast.
- **Send and Receive**: Seamless S256 transfers with support for modern and legacy address formats.
- **Advanced Send (Coin Control)**: Manual UTXO selection with input scanning, select-all/clear, and confirmation-aware filtering.
- **Transaction Preview**: Clear pre-send summary of selected inputs, send amount, estimated fee, and expected change.
- **QR Code Scanning**: Supports BIP21 URI format for easy payments.
- **Transaction Tracking**: Real-time history with smart confirmation tracking.
- **Flexible Pending Logic**: Sending is not blocked globally by pending transactions when selected UTXOs are free to spend.
- **Compliance Surfaces**: In-app Regulatory Notice and updated About/Exchange informational views.
- **Biometric Security**: Protect your wallet and recovery phrase with fingerprint or face recognition.
- **Secure Storage**: Sensitive keys and mnemonics are stored in encrypted secure storage.

## Release 1.5

Release date: 2026-06-22

- Fully non-custodial mobile transaction flow with local signing.
- Advanced send mode with coin control (manual UTXO selection).
- Send preview panel with selected inputs, amount, estimated fee, and expected change.
- Address validation alignment for modern and legacy formats in send flow.
- Improved pending-transaction handling for selected confirmed/free UTXOs.
- Exchange view redesigned as informational/compliance-oriented surface.
- Added in-app Regulatory Notice view and navigation from Settings/About.
- Privacy policy metadata refreshed (updated date + revision tag).

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run in development (uses public RPC)
flutter run

# Build APK
flutter build apk

# Build with custom RPC
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define-from-file=dart_defines.json
```

## Configuration

The wallet connects to the public RPC proxy at `https://sha256coin.eu/rpc` by default (no authentication required).

For custom RPC node, create `dart_defines.json`:

```json
{
  "RPC_URL": "http://your-rpc:port",
  "RPC_USER": "your_user",
  "RPC_PASSWORD": "your_password"
}
```

## Build for Production

```bash
# Android APK
flutter build apk --release --dart-define-from-file=dart_defines.json

# Android App Bundle (Play Store)
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --dart-define-from-file=dart_defines.json

# iOS
flutter build ios --release --dart-define-from-file=dart_defines.json
```

Output locations:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## Security

- Private keys stored in encrypted secure storage (Keychain/KeyStore)
- Optional biometric authentication
- Transaction signing is performed locally (non-custodial flow)
- RPC credentials injected at build time, never hardcoded
- No account registration or direct identity data collection
- See in-app Privacy Policy for current data-processing details and revision date

**Never commit `dart_defines.json` or `.env` to version control.**

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

For bugs or feature requests, please open an issue.

## License

MIT
