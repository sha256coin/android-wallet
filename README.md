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

- Create new wallet or recover from private key (WIF)
- Send and receive S256
- QR code scanning (supports BIP21 URI format)
- Transaction history with confirmation tracking
- Biometric authentication (fingerprint/face)
- Secure private key storage

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run in development (uses public RPC)
flutter run

# Build APK
flutter build apk

# Build with custom RPC
flutter build apk --dart-define-from-file=dart_defines.json
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
- RPC credentials injected at build time, never hardcoded
- No personal data collected

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
