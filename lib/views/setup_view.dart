import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/services/wallet_service.dart';
import 'package:s256_wallet/services/biometric_service.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/widgets/button_widget.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class SetupView extends StatelessWidget {
  SetupView({super.key});

  final TextEditingController _recoverController = TextEditingController();
  final WalletService _walletService = WalletService();
  final BiometricService _biometricService = BiometricService();

  Future<void> _processWallet(BuildContext context, String privateKey, {bool isNewWallet = false}) async {
    final wp = Provider.of<WalletProvider>(context, listen: false);
    final address = _walletService.loadAddressFromKey(privateKey);
    
    if (address != null) {
      // Show private key dialog for new wallets
      if (isNewWallet) {
        final confirmed = await _showPrivateKeyDialog(context, privateKey, address);
        if (!confirmed) return;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Valid private key found!'),
            backgroundColor: Colors.green,
          ));
        }
      }

      if (!context.mounted) return;
      await wp.loadWifWallet(privateKey);

      if (context.mounted && wp.wallet != null) {
        final bp = Provider.of<BlockchainProvider>(context, listen: false);
        await bp.loadBlockchain(wp.wallet!.address);

        // Ask about biometric authentication
        await _askBiometricSetup(context);

        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Invalid private key found!'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _askBiometricSetup(BuildContext context) async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return;

    final types = await _biometricService.getAvailableBiometrics();
    final typeName = _biometricService.getBiometricTypeName(types);

    if (!context.mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 25, 25, 25),
          title: Row(
            children: [
              Icon(
                typeName.contains('Face') ? Icons.face : Icons.fingerprint,
                color: S256Colors.accent,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Secure Your Wallet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Would you like to enable $typeName to secure your wallet?',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'When enabled, you\'ll need to authenticate with $typeName each time you open the app.',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: S256Colors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (enable == true) {
      // Test authentication first
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Authenticate to enable $typeName',
      );

      if (authenticated) {
        await _biometricService.enableBiometric();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$typeName enabled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<bool> _showPrivateKeyDialog(BuildContext context, String privateKey, String address) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool hasConfirmed = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 25, 25, 25),
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save Your Private Key',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your wallet has been created! Write down your private key and store it safely.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '⚠️ CRITICAL WARNINGS:',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Never share this key with anyone\n• This is the ONLY way to recover your wallet\n• If you lose it, your funds are GONE FOREVER\n• Write it on paper and store it securely',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Address:',
                      style: TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: S256Colors.accent.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        address,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: S256Colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Private Key:',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        privateKey,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: hasConfirmed,
                          onChanged: (bool? value) {
                            setState(() {
                              hasConfirmed = value ?? false;
                            });
                          },
                          checkColor: Colors.black,
                          activeColor: Colors.orange,
                        ),
                        const Expanded(
                          child: Text(
                            'I have written down my private key',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: hasConfirmed
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasConfirmed ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('I Saved It - Continue'),
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }

  void _recoverWallet(BuildContext context) {
    final privateKey = _recoverController.text.trim();
    if (privateKey.isNotEmpty) {
      _processWallet(context, privateKey);
    }
  }

  Future<void> _generateWallet(BuildContext context) async {
    final privateKey = _walletService.generatePrivateKey();
    if (privateKey != null) {
      await _processWallet(context, privateKey, isNewWallet: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to generate wallet. Please try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/background.jpg',
                fit: BoxFit.cover,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          const SizedBox(height: 50),
                          const Text(
                            'S256 Wallet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Secure. Private. Fast.',
                            style: TextStyle(
                              color: S256Colors.accent,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 60),
                          
                          // Seed Phrase Section
                          const Text(
                            'Seed Phrase (Recommended)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Create a new wallet with a recovery phrase or restore an existing one.',
                            style: TextStyle(color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ButtonWidget(
                            text: 'Create New Seed',
                            isPrimary: true,
                            onPressed: () => Navigator.pushNamed(context, '/seed-setup'),
                          ),
                          const SizedBox(height: 12),
                          ButtonWidget(
                            text: 'Restore from Seed',
                            isPrimary: false,
                            onPressed: () => Navigator.pushNamed(context, '/seed-restore'),
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Advanced Section
                          ExpansionTile(
                            title: const Text(
                              'Advanced Options (WIF)',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            iconColor: Colors.white70,
                            collapsedIconColor: Colors.white70,
                            children: [
                              const SizedBox(height: 10),
                              const Text(
                                'Use a raw private key (WIF) to manage your wallet.',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _recoverController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter your private key (WIF)',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: S256Colors.accent),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ButtonWidget(
                                text: 'Recover with WIF',
                                isPrimary: true,
                                onPressed: () => _recoverWallet(context),
                              ),
                              const SizedBox(height: 12),
                              ButtonWidget(
                                text: 'Generate New WIF',
                                isPrimary: false,
                                onPressed: () => _generateWallet(context),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'Note: Always keep your recovery phrase and private keys secure. Anyone with these can access your funds.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        ),
      ),
    );
  }
}
