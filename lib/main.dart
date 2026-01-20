// main.dart - Fixed for Flutter 3.35.3
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  try {
    if (kDebugMode) {
      print('💼 Loading wallet...');
    }
    await wp.loadWallet();
    if (wp.address != null) {
      if (kDebugMode) {
        print('📥 Fetching UTXOs...');
      }
      await wp.fetchUtxos(force: true);
      if (kDebugMode) {
        print('⛓️  Loading blockchain...');
      }
      await bp.loadBlockchain(wp.address);
    }
    if (kDebugMode) {
      print('✅ Providers initialized');
    }
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
      ],
      child: const MyApp(),
    ),
  );
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

      // Material 3 theme with S256 brand colors
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b0f14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFa300ff),      // S256 Purple
          secondary: Color(0xFF00d4ff),    // S256 Cyan
          tertiary: Color(0xFFffd700),     // S256 Gold
          surface: Color(0xFF1a1f2e),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF0b0f14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1a1f2e),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFa300ff).withValues(alpha: 0.15),
            ),
          ),
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0b0f14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFa300ff),      // S256 Purple
          secondary: Color(0xFF00d4ff),    // S256 Cyan
          tertiary: Color(0xFFffd700),     // S256 Gold
          surface: Color(0xFF1a1f2e),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF0b0f14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1a1f2e),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFa300ff).withValues(alpha: 0.15),
            ),
          ),
        ),
      ),

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