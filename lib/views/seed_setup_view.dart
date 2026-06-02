import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/services/wallet_service.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/widgets/button_widget.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class SeedSetupView extends StatefulWidget {
  final bool isRestore;
  const SeedSetupView({super.key, this.isRestore = false});

  @override
  State<SeedSetupView> createState() => _SeedSetupViewState();
}

class _SeedSetupViewState extends State<SeedSetupView> {
  final WalletService _ws = WalletService();
  String? _mnemonic;
  List<String> _words = [];
  int _wordCount = 12;
  int _currentStep = 0; // 0: Choose/Input, 1: Display/Verify, 2: Finalize
  
  final List<TextEditingController> _wordControllers = List.generate(24, (_) => TextEditingController());
  final List<int> _verifyIndices = [];
  final Map<int, TextEditingController> _verifyControllers = {};

  @override
  void initState() {
    super.initState();
    if (!widget.isRestore) {
      _generateMnemonic();
    }
  }

  void _generateMnemonic() {
    setState(() {
      _mnemonic = _ws.generateMnemonic(strength: _wordCount == 12 ? 128 : 256);
      _words = _mnemonic!.split(' ');
    });
  }

  void _startVerification() {
    _verifyIndices.clear();
    _verifyControllers.clear();
    
    // Pick 3 random indices to verify
    final random = List.generate(_words.length, (index) => index);
    random.shuffle();
    _verifyIndices.addAll(random.take(3).toList()..sort());
    
    for (var index in _verifyIndices) {
      _verifyControllers[index] = TextEditingController();
    }
    
    setState(() {
      _currentStep = 1;
    });
  }

  bool _verifyWords() {
    for (var index in _verifyIndices) {
      if (_verifyControllers[index]!.text.trim().toLowerCase() != _words[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _finalizeWallet() async {
    if (_mnemonic == null) return;
    
    final privateKeyBytes = _ws.derivePrivateKeyFromMnemonic(_mnemonic!);
    final wif = _ws.getWifFromPrivateKey(privateKeyBytes);
    final address = _ws.loadAddressFromKey(wif);

    if (address != null) {
      final wp = Provider.of<WalletProvider>(context, listen: false);
      await wp.saveWallet(address, wif, mnemonic: _mnemonic, type: WalletType.seed);
      
      await wp.fetchUtxos(force: true);
      
      if (!mounted) return;
      final bp = Provider.of<BlockchainProvider>(context, listen: false);
      await bp.loadBlockchain(address);
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _restoreWallet() {
    final enteredWords = _wordControllers
        .take(_wordCount)
        .map((c) => c.text.trim().toLowerCase())
        .toList();
    
    if (enteredWords.any((w) => w.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all words'), backgroundColor: Colors.red),
      );
      return;
    }

    final mnemonic = enteredWords.join(' ');
    if (_ws.validateMnemonic(mnemonic)) {
      setState(() {
        _mnemonic = mnemonic;
        _words = enteredWords;
        _finalizeWallet();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid seed phrase. Please check the words.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.isRestore ? 'Restore Wallet' : 'New Seed Phrase'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: widget.isRestore ? _buildRestoreUI() : _buildGenerateUI(),
        ),
      ),
    );
  }

  Widget _buildGenerateUI() {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Recovery Phrase',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Write down these words in the correct order and store them in a safe place.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _wordCountChip(12),
              const SizedBox(width: 12),
              _wordCountChip(24),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildWordGrid()),
          const SizedBox(height: 24),
          ButtonWidget(
            text: 'I have written it down',
            isPrimary: true,
            onPressed: _startVerification,
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify Backup',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter the requested words from your phrase to confirm you\'ve backed it up.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ..._verifyIndices.map((index) => Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: TextField(
              controller: _verifyControllers[index],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Word #${index + 1}',
                labelStyle: const TextStyle(color: S256Colors.accent),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: S256Colors.accent)),
              ),
            ),
          )),
          const Spacer(),
          ButtonWidget(
            text: 'Verify & Continue',
            isPrimary: true,
            onPressed: () {
              if (_verifyWords()) {
                _finalizeWallet();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect words. Please check your backup.'), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      );
    }
  }

  Widget _buildRestoreUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Restore from Seed',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your 12 or 24-word recovery phrase to restore your wallet.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _wordCountChip(12),
            const SizedBox(width: 12),
            _wordCountChip(24),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _wordCount,
            itemBuilder: (context, index) {
              return TextField(
                controller: _wordControllers[index],
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '${index + 1}',
                  hintStyle: const TextStyle(color: Colors.white24),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        ButtonWidget(
          text: 'Restore Wallet',
          isPrimary: true,
          onPressed: _restoreWallet,
        ),
      ],
    );
  }

  Widget _wordCountChip(int count) {
    bool selected = _wordCount == count;
    return GestureDetector(
      onTap: () {
        setState(() {
          _wordCount = count;
          if (!widget.isRestore) _generateMnemonic();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? S256Colors.accent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count Words',
          style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildWordGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _words.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                ),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _words[index],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
