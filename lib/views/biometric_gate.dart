import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s256_wallet/services/biometric_service.dart';
import 'package:s256_wallet/views/home_view.dart';
import 'package:s256_wallet/widgets/app_background.dart';

/// Guards the wallet with the device's biometric lock (when enabled in
/// Settings).
///
/// - App start: the home screen is built only after the first unlock.
/// - Return from the background: a lock screen is pushed on the ROOT
///   navigator, on top of every open screen and dialog (Send, Receive,
///   Settings, ...). Previously the lock replaced only this widget, so screens
///   opened on top of the home screen stayed visible, and the home screen was
///   rebuilt on every resume (its refresh could be lost). The screens below
///   the lock now stay as they were and are shown again after unlocking.
class BiometricGate extends StatefulWidget {
  /// The screen behind the lock. Replaceable in tests.
  final Widget home;

  /// Replaceable in tests; defaults to the device's biometric lock.
  final BiometricService? biometricService;

  const BiometricGate({super.key, this.home = const HomeView(), this.biometricService});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> with WidgetsBindingObserver {
  late final BiometricService _biometricService = widget.biometricService ?? BiometricService();
  bool _unlocked = false;
  bool _wentToBackground = false;
  bool _lockShown = false;
  // Cached so the lock can be pushed on the first frame after resuming,
  // without an async check that would briefly show the screen underneath.
  // Refreshed every time the app goes to the background (Settings may change it).
  bool _lockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLockEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshLockEnabled() async {
    try {
      _lockEnabled = await _biometricService.isBiometricEnabled();
    } catch (_) {
      // Keep the last known value.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Only a real trip to the background counts (paused), not "inactive",
    // which the biometric prompt itself causes.
    if (state == AppLifecycleState.paused && _unlocked) {
      _wentToBackground = true;
      _refreshLockEnabled();
    }

    if (state == AppLifecycleState.resumed && _wentToBackground) {
      _wentToBackground = false;
      if (_unlocked && _lockEnabled && !_lockShown) _showResumeLock();
    }
  }

  Future<void> _showResumeLock() async {
    _lockShown = true;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (routeContext, _, __) => PopScope(
          // The system back button must not close the lock.
          canPop: false,
          child: _LockScreen(
            biometricService: _biometricService,
            onUnlocked: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    );
    _lockShown = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return _LockScreen(
        biometricService: _biometricService,
        onUnlocked: () {
          if (mounted) setState(() => _unlocked = true);
          _refreshLockEnabled();
        },
      );
    }
    return widget.home;
  }
}

/// Asks for the biometric unlock and calls [onUnlocked] on success, or at once
/// when the lock is off or unavailable on this device.
class _LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final BiometricService biometricService;

  const _LockScreen({required this.onUnlocked, required this.biometricService});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  BiometricService get _biometricService => widget.biometricService;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      // First check if biometric is enabled
      final isEnabled = await _biometricService.isBiometricEnabled();

      if (!isEnabled) {
        // Not enabled, allow access
        widget.onUnlocked();
        return;
      }

      // Check if biometric is actually available on device
      final isAvailable = await _biometricService.isBiometricAvailable();

      if (!isAvailable) {
        // Biometric was enabled but device doesn't support it anymore
        // (e.g., emulator without biometric setup)
        // Disable it and allow access
        await _biometricService.disableBiometric();
        widget.onUnlocked();
        return;
      }

      // Now try to authenticate
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to access your wallet',
      );

      if (authenticated) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    } catch (e) {
      // If there's an error, show failed state
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        body: AppBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: S256Colors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Authenticating...',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Failed',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to authenticate',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isAuthenticating = true);
                  _authenticate();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: S256Colors.accent,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text(
                  'Exit App',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
