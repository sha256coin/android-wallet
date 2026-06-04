import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:s256_wallet/models/wallet_model.dart';
import 'package:s256_wallet/services/wallet_service.dart';
import 'package:s256_wallet/services/rpc_config_service.dart';

class WalletProvider with ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final WalletService _ws = WalletService();
  final RpcConfigService _rpcConfig = RpcConfigService();

  WalletModel? _wallet;
  bool _isLoading = false;
  String? _lastError;
  DateTime? _lastFetch;
  bool _isCurrentlySending = false;
  DateTime? _lastSendAttempt;

  // Pending transaction tracking (kept for UI compatibility)
  final Set<String> _pendingTxids = {};
  final Map<String, DateTime> _pendingTimestamps = {};
  final Map<String, PendingTransaction> _pendingTransactions = {};

  // Getters
  WalletModel? get wallet => _wallet;
  String? get privateKey => _wallet?.privateKey;
  String? get address => _wallet?.address;
  String? get mnemonic => _wallet?.mnemonic;
  WalletType? get walletType => _wallet?.type;
  double? get balance => _wallet?.balance;
  double? get unconfirmedBalance => _wallet?.unconfirmedBalance;
  List<Map<String, dynamic>>? get utxos => _lastUtxos;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>>? _lastUtxos;

  String? get lastError => _lastError;
  bool get hasPendingTransactions => _pendingTransactions.isNotEmpty || (_wallet?.isPending ?? false);
  int get pendingTransactionsCount => _pendingTransactions.length;

  // Display balance - shows actual spendable balance considering consumed UTXOs
  double? get displayBalance {
    if (_wallet == null) return 0.0;
    if (_pendingTransactions.isEmpty) {
      return _wallet!.balance + _wallet!.unconfirmedBalance;
    }

    // Start with confirmed balance
    double spendableBalance = _wallet!.balance;

    // Add expected change from pending transactions back to the wallet
    for (final tx in _pendingTransactions.values) {
      spendableBalance += tx.changeAmount;
    }

    return spendableBalance < 0 ? 0.0 : spendableBalance;
  }

  // Get list of pending transactions
  List<PendingTransaction> get pendingTransactionsList =>
      _pendingTransactions.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  WalletProvider();

  Future<void> loadWallet() async {
    try {
      _isLoading = true;
      notifyListeners();

      final privateKey = await _storage.read(key: 'key');
      final mnemonic = await _storage.read(key: 'mnemonic');
      final typeStr = await _storage.read(key: 'wallet_type');

      WalletType type = WalletType.wif;
      if (typeStr == 'seed') {
        type = WalletType.seed;
      } else if (typeStr == 'wif' || privateKey != null) {
        type = WalletType.wif;
      }

      if (privateKey != null) {
        final address = _ws.loadAddressFromKey(privateKey);
        if (address != null) {
          _wallet = WalletModel(
            address: address,
            privateKey: privateKey,
            mnemonic: mnemonic,
            type: type,
          );
          await fetchUtxos(force: true);
        }
      }
    } catch (e) {
      _lastError = 'Failed to load wallet: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWallet(String address, String privateKey,
      {String? mnemonic, WalletType type = WalletType.wif}) async {
    _wallet = WalletModel(
      address: address,
      privateKey: privateKey,
      mnemonic: mnemonic,
      type: type,
    );

    await _storage.write(key: 'key', value: privateKey);
    await _storage.write(
        key: 'wallet_type', value: type == WalletType.seed ? 'seed' : 'wif');

    if (mnemonic != null) {
      await _storage.write(key: 'mnemonic', value: mnemonic);
    } else {
      await _storage.delete(key: 'mnemonic');
    }

    await fetchUtxos(force: true);
    notifyListeners();
  }

  Future<void> deleteWallet() async {
    _wallet = null;
    _pendingTxids.clear();
    _pendingTimestamps.clear();
    _pendingTransactions.clear();
    await _storage.delete(key: 'key');
    await _storage.delete(key: 'mnemonic');
    await _storage.delete(key: 'wallet_type');
    notifyListeners();
  }

  void _cleanupPendingTransactions() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _pendingTimestamps.forEach((txid, timestamp) {
      if (now.difference(timestamp).inMinutes > 60) {
        toRemove.add(txid);
      }
    });

    for (final txid in toRemove) {
      _pendingTxids.remove(txid);
      _pendingTimestamps.remove(txid);
      _pendingTransactions.remove(txid);
    }
  }

  Future<void> fetchUtxos({bool force = false, bool silent = false}) async {
    if (_wallet == null) return;

    // Rate limiting
    if (!force && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch.inSeconds < 5) {
        return;
      }
    }

    try {
      if (!silent) {
        _isLoading = true;
        notifyListeners();
      }

      _cleanupPendingTransactions();

      final rpcUrl = await _rpcConfig.getRpcUrl();
      final rpcUser = await _rpcConfig.getRpcUser();
      final rpcPassword = await _rpcConfig.getRpcPassword();

      final utxos = await _ws.getUtxos(rpcUrl, rpcUser, rpcPassword, _wallet!.address);
      _lastUtxos = utxos;
      
      final balance = _ws.calculateBalance(utxos);
      final unconfirmed = _ws.calculateUnconfirmedBalance(utxos);
      final hasMempoolActivity = utxos.any((u) => u['confirmations'] == 0);

      // Check if any of our locally tracked pending transactions are now confirmed
      // (If they are not in the mempool anymore and not in the UTXO list with 0 confirmations)
      final mempoolTxidsInUtxos = utxos
          .where((u) => u['confirmations'] == 0 && u['txid'] != 'pending_marker')
          .map((u) => u['txid'] as String)
          .toSet();

      final confirmedTxs = <String>[];
      for (final txid in _pendingTxids) {
        // If it's not in mempool (via getUtxos logic), it might be confirmed or dropped
        // We'll check if it's in the confirmed UTXOs as well (not perfect but good enough)
        bool inConfirmedUtxos = utxos.any((u) => u['txid'] == txid && u['confirmations'] > 0);
        bool inMempool = mempoolTxidsInUtxos.contains(txid);
        
        if (inConfirmedUtxos) {
          confirmedTxs.add(txid);
        } else if (!inMempool) {
          // If it's not in mempool and not in confirmed UTXOs, it might be confirmed in a way
          // that doesn't create a UTXO for us (e.g. sweep to someone else), or still pending.
          // For now, let's keep it until it's actually seen as confirmed or timed out.
        }
      }

      for (final txid in confirmedTxs) {
        _pendingTxids.remove(txid);
        _pendingTimestamps.remove(txid);
        _pendingTransactions.remove(txid);
      }

      _wallet = _wallet!.copyWith(
        balance: balance,
        unconfirmedBalance: unconfirmed,
        isPending: hasMempoolActivity,
      );

      _lastFetch = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = 'Failed to fetch UTXOs: $e';
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendTransaction(
      String address,
      double amount,
      {double? feeRate}
      ) async {

    if (_wallet == null) {
      return {
        'success': false,
        'message': 'Wallet not initialized'
      };
    }

    if (_isCurrentlySending) {
      return {
        'success': false,
        'message': 'Transaction already in progress. Please wait.'
      };
    }

    if (_lastSendAttempt != null) {
      final timeSinceLastSend = DateTime.now().difference(_lastSendAttempt!);
      if (timeSinceLastSend.inSeconds < 3) {
        return {
          'success': false,
          'message': 'Please wait a moment before sending another transaction.'
        };
      }
    }

    _isCurrentlySending = true;
    _lastSendAttempt = DateTime.now();
    notifyListeners();

    try {
      final rpcUrl = await _rpcConfig.getRpcUrl();
      final rpcUser = await _rpcConfig.getRpcUser();
      final rpcPassword = await _rpcConfig.getRpcPassword();

      // We need to estimate change for our optimistic display balance
      // We'll call the service logic to create the transaction but we'll use its internal steps
      
      final result = await _ws.sendTransaction(
        rpcUrl,
        rpcUser,
        rpcPassword,
        _wallet!.privateKey,
        _wallet!.address,
        address,
        amount,
        feeRate: feeRate,
      );

      if (result['success']) {
        final txid = result['txid'] as String;
        final fee = result['fee'] as double;
        final change = result['change'] as double? ?? 0.0;

        _pendingTxids.add(txid);
        _pendingTimestamps[txid] = DateTime.now();
        _pendingTransactions[txid] = PendingTransaction(
          txid: txid,
          amount: amount,
          fee: fee,
          toAddress: address,
          timestamp: DateTime.now(),
          changeAmount: change,
        );

        _startSmartConfirmationChecking(txid);
        await fetchUtxos(force: true, silent: true);
        
        return {
          'success': true,
          'txid': txid,
          'fee': fee,
        };
      } else {
        return result;
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    } finally {
      _isCurrentlySending = false;
      notifyListeners();
    }
  }

  void _startSmartConfirmationChecking(String txid) async {
    final checkIntervals = [5, 10, 20, 40, 80, 160, 300, 600];

    for (int i = 0; i < checkIntervals.length; i++) {
      if (!_pendingTxids.contains(txid)) break;
      await Future.delayed(Duration(seconds: checkIntervals[i]));
      if (_pendingTxids.contains(txid)) {
        await fetchUtxos(force: true, silent: true);
      }
    }
  }

  Future<void> refreshBalance() async {
    await fetchUtxos(force: true);
  }

  Future<void> loadWifWallet(String wif) async {
    _isLoading = true;
    notifyListeners();

    try {
      final address = _ws.loadAddressFromKey(wif);
      if (address == null) {
        _lastError = 'Invalid WIF Private Key';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await saveWallet(address, wif, type: WalletType.wif);
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSeedWallet(String mnemonic) async {
    _isLoading = true;
    notifyListeners();

    try {
      final walletData = await _ws.getWalletFromMnemonic(mnemonic);
      if (walletData == null) {
        _lastError = 'Invalid Seed Phrase';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await saveWallet(walletData['address']!, walletData['privateKey']!,
          mnemonic: mnemonic, type: WalletType.seed);
    } catch (e) {
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateNewWifWallet() async {
    _isLoading = true;
    notifyListeners();

    final walletData = _ws.generateNewWallet();
    await saveWallet(walletData['address']!, walletData['privateKey']!,
        type: WalletType.wif);
  }

  Future<void> generateNewSeedWallet({int words = 12}) async {
    _isLoading = true;
    notifyListeners();

    final walletData = await _ws.generateNewSeedWallet(words: words);
    await saveWallet(walletData['address']!, walletData['privateKey']!,
        mnemonic: walletData['mnemonic'], type: WalletType.seed);
  }

  Future<Map<String, dynamic>?> getNetworkInfo() async {
    final rpcUrl = await _rpcConfig.getRpcUrl();
    final rpcUser = await _rpcConfig.getRpcUser();
    final rpcPassword = await _rpcConfig.getRpcPassword();
    return await _ws.getNetworkInfo(rpcUrl, rpcUser, rpcPassword);
  }

  // New function from web-wallet: Migrate from WIF to Seed
  Future<bool> migrateToSeed({int words = 12, bool skipSweep = false}) async {
    if (_wallet == null || _wallet!.type != WalletType.wif) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final oldWif = _wallet!.privateKey;
      final oldAddress = _wallet!.address;

      await refreshBalance();
      final currentBalance = _wallet!.balance;
      
      final walletData = await _ws.generateNewSeedWallet(words: words);
      final mnemonic = walletData['mnemonic']!;
      final newAddress = walletData['address']!;
      final newWif = walletData['privateKey']!;

      if (currentBalance > 0.00001 && !skipSweep) {
        final rpcUrl = await _rpcConfig.getRpcUrl();
        final rpcUser = await _rpcConfig.getRpcUser();
        final rpcPassword = await _rpcConfig.getRpcPassword();

        final result = await _ws.sendTransaction(
          rpcUrl,
          rpcUser,
          rpcPassword,
          oldWif,
          oldAddress,
          newAddress,
          currentBalance,
        );

        if (!result['success']) {
          _lastError = 'Migration failed: ${result['message']}';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        _pendingTxids.add(result['txid'] as String);
        _pendingTimestamps[result['txid'] as String] = DateTime.now();
        _pendingTransactions[result['txid'] as String] = PendingTransaction(
          txid: result['txid'] as String,
          amount: currentBalance,
          fee: result['fee'] ?? 0.0,
          toAddress: newAddress,
          timestamp: DateTime.now(),
          changeAmount: 0.0,
        );
      }

      await saveWallet(newAddress, newWif, mnemonic: mnemonic, type: WalletType.seed);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Migration error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

class PendingTransaction {
  final String txid;
  final double amount;
  final double fee;
  final String toAddress;
  final DateTime timestamp;
  final double changeAmount;

  PendingTransaction({
    required this.txid,
    required this.amount,
    required this.fee,
    required this.toAddress,
    required this.timestamp,
    this.changeAmount = 0.0,
  });
}
