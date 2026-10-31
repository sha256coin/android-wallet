// main.dart - Fixed for Flutter 3.35.3
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/providers/addressbook_provider.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/views/setup_view.dart';
import 'package:s256_wallet/views/biometric_gate.dart';
import 'package:s256_wallet/services/rpc_config_service.dart';

void main() async {
  // Catch all errors in main and show them
  try {
    await _runApp();
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('💥 FATAL ERROR: $e');
      print('Stack trace: $stackTrace');
    }
    // Show error in UI
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                const Text('App Initialization Failed',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 20),
                Text('Error: $e',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print('🚀 Starting S256 Wallet...');
  }

  // Initialize RPC credentials in secure storage
  try {
    if (kDebugMode) {
      print('📡 Initializing RPC config...');
    }
    final rpcConfig = RpcConfigService();
    await rpcConfig.initializeRpcCredentials();
    if (kDebugMode) {
      print('✅ RPC config initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ RPC config error: $e');
    }
    // Continue - RPC errors shouldn't crash the app
  }

  // Enable edge-to-edge display for Android 15+ compatibility
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Add system UI customization with edge-to-edge support
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Light icons on dark background
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Note: Removed orientation restrictions to support large screen devices
  // (tablets, foldables) as required by Android 16+
  // The app now supports all orientations for better user experience

  // Initialize providers with error handling
  if (kDebugMode) {
    print('📦 Creating providers...');
  }
  final wp = WalletProvider();
  final bp = BlockchainProvider();

  // The start screen only waits for the wallet to load from secure storage
  // (local and fast). UTXOs and explorer history used to load here too, one
  // after the other, so the splash lasted as long as the slowest server. They
  // now load in parallel in the background while the wallet screen shows its
  // loading skeleton.
  try {
    if (kDebugMode) {
      print('💼 Loading wallet...');
    }
    await wp.loadWallet();
    if (kDebugMode) {
      print('✅ Providers initialized');
    }
    unawaited(_initialNetworkSync(wp, bp));
  } catch (e) {
    if (kDebugMode) {
      print('❌ Provider initialization error: $e');
    }
    // Continue anyway - the app can handle missing data
  }

  // Add error handling for Flutter framework
  if (kDebugMode) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
  } else {
    FlutterError.onError = (details) {
      // In release mode, log to your crash reporting service
      debugPrint('Flutter error: ${details.exception}');
    };
  }

  if (kDebugMode) {
    print('🎨 Starting Flutter app...');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: wp),
        ChangeNotifierProvider<BlockchainProvider>.value(value: bp),
        ChangeNotifierProvider<AddressbookProvider>(
          create: (_) => AddressbookProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initialNetworkSync(WalletProvider wp, BlockchainProvider bp) async {
  if (wp.address == null) return;
  try {
    await Future.wait([
      wp.fetchUtxos(force: true),
      bp.loadBlockchain(wp.address),
    ]);
  } catch (e) {
    if (kDebugMode) {
      print('❌ Initial network sync failed: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wp, child) {
        final initialRoute = wp.privateKey != null ? '/home' : '/setup';

    return MaterialApp(
      title: 'S256 Wallet',
      debugShowCheckedModeBanner: false,

      // S256 "Digital Platinum" theme (see lib/theme/s256_theme.dart)
      theme: S256Theme.dark,
      darkTheme: S256Theme.dark,

      themeMode: ThemeMode.dark, // Always use dark theme

      initialRoute: initialRoute,
      routes: {
        '/setup': (context) => SetupView(),
        '/home': (context) => const BiometricGate(),
      },

      // Add navigation observer for debugging
      navigatorObservers: kDebugMode ? [_DebugNavigatorObserver()] : [],
    );
      },
    );
  }
}

// Simple navigation observer for debugging
class _DebugNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: Popped ${route.settings.name}');
  }
}