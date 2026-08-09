import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:s256_wallet/models/wallet_model.dart';
import 'package:s256_wallet/services/wallet_service.dart';
import 'package:s256_wallet/services/rpc_config_service.dart';

class WalletProvider with ChangeNotifier {
  static const int _maxMigrationSweepInputs = 120;
  static const int _maxMigrationSweepVbytes = 90000;
  static const int _maxCoinControlUtxos = 1500;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final WalletService _ws = WalletService();
  final RpcConfigService _rpcConfig = RpcConfigService();

  WalletModel? _wallet;
  bool _isLoading = false;
  String? _lastError;
  DateTime? _lastFetch;
  bool _isCurrentlySending = false;
  DateTime? _lastSendAttempt;
  String _message = '';

  // Pending transaction tracking (kept for UI compatibility)
  final Set<String> _pendingTxids = {};
  final Map<String, DateTime> _pendingTimestamps = {};
  final Map<String, PendingTransaction> _pendingTransactions = {};

  // Coin control and advanced send state
  List<Map<String, dynamic>> _availableUtxos = [];
  Set<String> _selectedUtxoKeys = {};
  bool _isLoadingUtxos = false;
  int _utxoPage = 0;
  int _coinControlTruncatedCount = 0;
  static const int _utxosPerPage = 15;
  double _feeRate = 0.00001;
  bool _isFetchingFeeRate = false;
  bool _feeRateReady = false;
  bool _usingManualFeeRate = false;
  String _feeRateSource = 'unavailable';
  double? _feeBaselineRate;
  double? _feeEstimatedRate;
  double? _feeSanityCeiling;
  String _feeRateStatusMessage = 'Fee estimate not requested yet.';
  String? _feeEstimateError;

  // Getters
  WalletModel? get wallet => _wallet;
  String? get privateKey => _wallet?.privateKey;
  String? get address => _wallet?.address;
  String? get mnemonic => _wallet?.mnemonic;
  WalletType? get walletType => _wallet?.type;
  WalletService get walletService => _ws;
  double? get balance => _wallet?.balance;
  double? get unconfirmedBalance => _wallet?.unconfirmedBalance;
  List<Map<String, dynamic>>? get utxos => _lastUtxos;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get availableUtxos => _availableUtxos;
  Set<String> get selectedUtxoKeys => _selectedUtxoKeys;
  bool get isLoadingUtxos => _isLoadingUtxos;
  int get utxoPage => _utxoPage;
  int get coinControlTruncatedCount => _coinControlTruncatedCount;
  int get utxoPageCount =>
      _availableUtxos.isEmpty ? 1 : (_availableUtxos.length / _utxosPerPage).ceil();
  List<Map<String, dynamic>> get currentPageUtxos {
    final start = _utxoPage * _utxosPerPage;
    final end = (start + _utxosPerPage).clamp(0, _availableUtxos.length);
    return _availableUtxos.sublist(start, end);
  }
  String get message => _message;
  double get feeRate => _feeRate;
  bool get isFetchingFeeRate => _isFetchingFeeRate;
  bool get feeRateReady => _feeRateReady;
  bool get usingManualFeeRate => _usingManualFeeRate;
  String get feeRateSource => _feeRateSource;
  double? get feeBaselineRate => _feeBaselineRate;
  double? get feeEstimatedRate => _feeEstimatedRate;
  double? get feeSanityCeiling => _feeSanityCeiling;
  String get feeRateStatusMessage => _feeRateStatusMessage;
  bool get feeEstimateAvailable => _feeRateReady;
  bool get isFeeEstimateLoading => _isFetchingFeeRate;
  String? get feeEstimateError => _feeRateReady ? null : _feeEstimateError;

  double get selectedUtxoTotal => _availableUtxos
      .where((u) => _selectedUtxoKeys.contains('${u['txid']}:${u['vout']}'))
      .fold(0.0, (sum, u) => sum + (u['amount'] as num).toDouble());

  int get selectedUtxoCount => _selectedUtxoKeys.length;

  List<Map<String, dynamic>> get selectedUtxoList => _availableUtxos
      .where((u) => _selectedUtxoKeys.contains('${u['txid']}:${u['vout']}'))
      .toList();

  double get estimatedFee {
    if (_selectedUtxoKeys.isEmpty) return 0.0;
    final inputCount = _selectedUtxoKeys.length;
    final txSize = 10 + (inputCount * 148) + 2 * 34;
    return double.parse((_feeRate * txSize / 1000).toStringAsFixed(8));
  }

  double get estimatedNetSend {
    final net = selectedUtxoTotal - estimatedFee;
    return net > 0 ? net : 0.0;
  }

  double get estimatedSimpleFee =>
      double.parse((_feeRate * 226 / 1000).toStringAsFixed(8));

  List<Map<String, dynamic>>? _lastUtxos;

  String? get lastError => _lastError;
  bool get hasPendingTransactions => pendingTransactionsCount > 0;
  
  int get pendingTransactionsCount {
    // 1. Get unique TXIDs from the actual network mempool (via _lastUtxos)
    final mempoolTxids = _lastUtxos
            ?.where((u) => u['confirmations'] == 0 && u['txid'] != 'pending_marker')
            .map((u) => u['txid'] as String)
            .toSet() ??
        {};

    // 2. Get TXIDs from our local optimistic tracking
    final localTxids = _pendingTransactions.keys.toSet();

    // 3. The total count is the union of both (to avoid double counting)
    int count = mempoolTxids.union(localTxids).length;

    // 4. If the mempool has activity but no specific TXIDs are found yet (force-yellow logic), count it as 1
    if (count == 0 && (_lastUtxos?.any((u) => u['txid'] == 'pending_marker') ?? false)) {
      count = 1;
    }

    return count;
  }

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
    // Switching wallet identity must reset transient runtime state so old
    // wallet activity does not leak into the new wallet UI.
    _pendingTxids.clear();
    _pendingTimestamps.clear();
    _pendingTransactions.clear();
    _availableUtxos = [];
    _selectedUtxoKeys = {};
    _isLoadingUtxos = false;
    _utxoPage = 0;
    _lastUtxos = null;
    _lastFetch = null;
    _isCurrentlySending = false;
    _lastSendAttempt = null;
    _message = '';
    _lastError = null;

    _feeRate = 0.00001;
    _isFetchingFeeRate = false;
    _feeRateReady = false;
    _usingManualFeeRate = false;
    _feeRateSource = 'unavailable';
    _feeBaselineRate = null;
    _feeEstimatedRate = null;
    _feeSanityCeiling = null;
    _feeRateStatusMessage = 'Fee estimate not requested yet.';
    _feeEstimateError = null;

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

  void clearMessage() {
    _message = '';
    notifyListeners();
  }

  Future<bool> fetchFeeRate() async {
    _isFetchingFeeRate = true;
    _feeRateReady = false;
    _usingManualFeeRate = false;
    _feeRateSource = 'fetching';
    _feeBaselineRate = null;
    _feeEstimatedRate = null;
    _feeSanityCeiling = null;
    _feeRateStatusMessage = 'Fetching fee estimate from node...';
    _feeEstimateError = null;
    notifyListeners();

    try {
      final rpcUrl = await _rpcConfig.getRpcUrl();
      final rpcUser = await _rpcConfig.getRpcUser();
      final rpcPassword = await _rpcConfig.getRpcPassword();

      final feeResult = await _ws.resolveFeeRate(
        rpcUrl,
        rpcUser,
        rpcPassword,
      );

      if (feeResult['success'] == true) {
        _feeRate = (feeResult['feeRate'] as num).toDouble();
        _feeRateReady = true;
        _feeRateSource = (feeResult['source'] as String?) ?? 'estimated';
        _feeBaselineRate = (feeResult['baselineFeeRate'] as num?)?.toDouble();
        _feeEstimatedRate = (feeResult['estimatedFeeRate'] as num?)?.toDouble();
        _feeSanityCeiling = (feeResult['sanityCeiling'] as num?)?.toDouble();

        switch (_feeRateSource) {
          case 'clamped':
            _feeRateStatusMessage =
                (feeResult['message'] as String?) ?? 'Smart fee outlier detected. Using node baseline fee.';
            break;
          case 'baseline':
            _feeRateStatusMessage =
                (feeResult['message'] as String?) ?? 'Using node baseline fee.';
            break;
          case 'manual':
            _feeRateStatusMessage =
                'Using manual fee rate (${_feeRate.toStringAsFixed(8)} S256/kvB).';
            break;
          case 'estimated':
          default:
            _feeRateStatusMessage = 'Fee estimate ready from node.';
            break;
        }

        _feeEstimateError = null;
        return true;
      }

      _feeRate = 0.0;
      _feeRateReady = false;
      _feeRateSource = 'unavailable';
      _feeBaselineRate = null;
      _feeEstimatedRate = null;
      _feeSanityCeiling = null;
      _feeRateStatusMessage =
          (feeResult['message'] as String?) ?? 'Fee estimation unavailable. Manual fee required.';
      _feeEstimateError = _feeRateStatusMessage;
      return false;
    } catch (_) {
      _feeRate = 0.0;
      _feeRateReady = false;
      _feeRateSource = 'unavailable';
      _feeBaselineRate = null;
      _feeEstimatedRate = null;
      _feeSanityCeiling = null;
      _feeRateStatusMessage = 'Fee estimation unavailable. Enter a manual fee when sending.';
      _feeEstimateError = _feeRateStatusMessage;
      return false;
    } finally {
      _isFetchingFeeRate = false;
      notifyListeners();
    }
  }

  void setManualFeeRate(double feeRateCoinPerKb) {
    _feeRate = feeRateCoinPerKb;
    _feeRateReady = true;
    _usingManualFeeRate = true;
    _feeRateSource = 'manual';
    _feeBaselineRate = null;
    _feeEstimatedRate = null;
    _feeSanityCeiling = null;
    _feeRateStatusMessage =
        'Using manual fee rate (${feeRateCoinPerKb.toStringAsFixed(8)} S256/kvB).';
    _feeEstimateError = null;
    notifyListeners();
  }

  Future<void> fetchUtxosForCoinControl() async {
    if (_wallet == null) return;
    _isLoadingUtxos = true;
    _availableUtxos = [];
    _selectedUtxoKeys = {};
    _utxoPage = 0;
    _coinControlTruncatedCount = 0;
    notifyListeners();

    try {
      final rpcUrl = await _rpcConfig.getRpcUrl();
      final rpcUser = await _rpcConfig.getRpcUser();
      final rpcPassword = await _rpcConfig.getRpcPassword();

      final all = await _ws.getUtxos(rpcUrl, rpcUser, rpcPassword, _wallet!.address);
      _availableUtxos = all
          .where((u) =>
              u['txid'] != 'pending_marker' && (u['confirmations'] as int) > 0)
          .toList();
      _availableUtxos.sort((a, b) =>
          (b['amount'] as num).toDouble().compareTo((a['amount'] as num).toDouble()));

      if (_availableUtxos.length > _maxCoinControlUtxos) {
        _coinControlTruncatedCount = _availableUtxos.length - _maxCoinControlUtxos;
        _availableUtxos = _availableUtxos.sublist(0, _maxCoinControlUtxos);
      }

      await fetchFeeRate();
    } catch (_) {
    } finally {
      _isLoadingUtxos = false;
      notifyListeners();
    }
  }

  void toggleUtxo(String key) {
    if (_selectedUtxoKeys.contains(key)) {
      _selectedUtxoKeys.remove(key);
    } else {
      _selectedUtxoKeys.add(key);
    }
    notifyListeners();
  }

  void selectAllUtxos() {
    _selectedUtxoKeys = _availableUtxos.map((u) => '${u['txid']}:${u['vout']}').toSet();
    notifyListeners();
  }

  void clearUtxoSelection() {
    _selectedUtxoKeys = {};
    notifyListeners();
  }

  void resetCoinControl() {
    _availableUtxos = [];
    _selectedUtxoKeys = {};
    _isLoadingUtxos = false;
    _utxoPage = 0;
    _coinControlTruncatedCount = 0;
    notifyListeners();
  }

  void setUtxoPage(int page) {
    if (page < 0 || page >= utxoPageCount) return;
    _utxoPage = page;
    notifyListeners();
  }

  Future<bool> validateAddress(String address) async {
    if (address.isEmpty) return false;
    try {
      final rpcUrl = await _rpcConfig.getRpcUrl();
      final rpcUser = await _rpcConfig.getRpcUser();
      final rpcPassword = await _rpcConfig.getRpcPassword();
      final result = await _ws.rpcRequest(
        rpcUrl,
        rpcUser,
        rpcPassword,
        'validateaddress',
        [address],
      );
      return result != null &&
          result['result'] != null &&
          result['result']['isvalid'] == true;
    } catch (_) {
      return false;
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
      {double? feeRate,
      double? manualFeeRateCoinPerKb,
      bool preferBatchSend = true,
      bool isSweep = false,
      List<Map<String, dynamic>>? preSelectedUtxos}
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
    _message = '⏳ Sending transaction...';
    notifyListeners();

    try {
      final rpcUrl = await _rpcConfig.getRpcUrl();
      final rpcUser = await _rpcConfig.getRpcUser();
      final rpcPassword = await _rpcConfig.getRpcPassword();

      final effectiveFeeRate = feeRate ?? manualFeeRateCoinPerKb;

      final batchPreview = await assessBatchSendCandidate(
        address,
        amount,
        manualFeeRateCoinPerKb: effectiveFeeRate,
        preSelectedUtxos: preSelectedUtxos,
      );

      final nearSweepCandidate = batchPreview['nearSweep'] == true;
      if (preferBatchSend &&
          batchPreview['isCandidate'] == true &&
          nearSweepCandidate) {
        final confirmedUtxos =
            await _getConfirmedUtxosForSend(preSelectedUtxos: preSelectedUtxos);
        if (confirmedUtxos.isNotEmpty) {
          final batchResult = await _sendSweepInBatches(
            rpcUrl: rpcUrl,
            rpcUser: rpcUser,
            rpcPassword: rpcPassword,
            toAddress: address,
            confirmedUtxos: confirmedUtxos,
            feeRate: effectiveFeeRate,
          );

          if (batchResult['success'] == true) {
            final txids = (batchResult['batchTxids'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .where((txid) => txid.isNotEmpty)
                .toList();

            _message =
                '✅ Batch send complete: ${txids.length} transaction${txids.length == 1 ? '' : 's'} broadcasted.';
            await fetchUtxos(force: true, silent: true);
            notifyListeners();

            Future.delayed(const Duration(seconds: 5), () {
              if (_message.contains('✅')) {
                _message = '';
                notifyListeners();
              }
            });

            return batchResult;
          }

          _message = '❌ ${batchResult['message'] ?? 'Batch send failed'}';
          notifyListeners();
          return batchResult;
        }
      }

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
        feeRate: effectiveFeeRate,
        isSweep: isSweep,
        preSelectedUtxos: preSelectedUtxos,
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

        _message = '✅ Sent! TXID: $txid';
        Future.delayed(const Duration(seconds: 5), () {
          if (_message.contains('✅')) {
            _message = '';
            notifyListeners();
          }
        });
        
        return {
          'success': true,
          'txid': txid,
          'fee': fee,
        };
      } else {
        _message = '❌ ${result['message'] ?? 'Transaction failed'}';
        return result;
      }
    } catch (e) {
      _message = '❌ ${e.toString()}';
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    } finally {
      _isCurrentlySending = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> assessBatchSendCandidate(
    String toAddress,
    double amount, {
    double? manualFeeRateCoinPerKb,
    List<Map<String, dynamic>>? preSelectedUtxos,
  }) async {
    if (_wallet == null || amount <= 0) {
      return {
        'isCandidate': false,
        'reason': 'invalid-state',
      };
    }

    final confirmedUtxos =
        await _getConfirmedUtxosForSend(preSelectedUtxos: preSelectedUtxos);

    if (confirmedUtxos.isEmpty) {
      return {
        'isCandidate': false,
        'reason': 'no-utxos',
      };
    }

    final confirmedTotal = confirmedUtxos.fold<double>(
      0.0,
      (sum, u) => sum + (u['amount'] as num).toDouble(),
    );
    final nearSweep = amount >= (confirmedTotal - 0.00001);

    final sortedAmounts = confirmedUtxos
        .map((u) => (u['amount'] as num).toDouble())
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int toSats(double v) => (v * 1e8).round();
    int estimateFeeSats(double feeRate, int vbytes) =>
        (feeRate * vbytes / 1000 * 1e8).round();

    final feeRate =
        manualFeeRateCoinPerKb ?? (_feeRate > 0 ? _feeRate : 0.00001);
    final isDestLegacy = !toAddress.toLowerCase().startsWith('s2');
    final destOutputSize = isDestLegacy ? 34 : 31;
    const changeOutputSize = 31;

    int predictedInputCount;
    int predictedVbytes;

    if (nearSweep) {
      predictedInputCount = sortedAmounts.length;
      predictedVbytes = 11 + (predictedInputCount * 68) + destOutputSize;
    } else {
      final targetSats = toSats(amount);
      var used = 0;
      var inputSumSats = 0;
      while (used < sortedAmounts.length) {
        inputSumSats += toSats(sortedAmounts[used]);
        used += 1;
        final txSize = 11 + (used * 68) + destOutputSize + changeOutputSize;
        final feeSats = estimateFeeSats(feeRate, txSize);
        if (inputSumSats >= targetSats + feeSats) {
          break;
        }
      }
      predictedInputCount = used;
      predictedVbytes =
          11 + (predictedInputCount * 68) + destOutputSize + changeOutputSize;
    }

    final exceedsInputs = predictedInputCount > _maxMigrationSweepInputs;
    final exceedsVbytes = predictedVbytes > _maxMigrationSweepVbytes;
    final sweepTrigger = nearSweep &&
        (sortedAmounts.length > _maxMigrationSweepInputs ||
            (11 + (sortedAmounts.length * 68) + 31) >
                _maxMigrationSweepVbytes);
    // Current batch implementation broadcasts full-chunk sweeps, so only offer
    // batch for near-sweep scenarios where full-balance movement is expected.
    final isCandidate = nearSweep && (sweepTrigger || exceedsInputs || exceedsVbytes);

    final chunkSize = _maxSweepInputsPerBatchTx();
    final estimatedBatchCount = predictedInputCount <= 0
        ? 1
        : ((predictedInputCount + chunkSize - 1) ~/ chunkSize);
    final singleFee = feeRate * predictedVbytes / 1000;
    final estimatedTotalBatchFee = singleFee * estimatedBatchCount;

    final reason = sweepTrigger
        ? 'sweep-too-large'
        : exceedsInputs
            ? 'input-count'
            : exceedsVbytes
                ? 'tx-size'
                : 'none';

    return {
      'isCandidate': isCandidate,
      'reason': reason,
      'nearSweep': nearSweep,
      'predictedInputCount': predictedInputCount,
      'predictedVbytes': predictedVbytes,
      'estimatedBatchCount': estimatedBatchCount,
      'estimatedSingleFee': double.parse(singleFee.toStringAsFixed(8)),
      'estimatedTotalBatchFee':
          double.parse(estimatedTotalBatchFee.toStringAsFixed(8)),
      'estimatedNetDelivered':
          double.parse((amount - estimatedTotalBatchFee).toStringAsFixed(8)),
      'confirmedUtxoCount': confirmedUtxos.length,
      'confirmedTotal': double.parse(confirmedTotal.toStringAsFixed(8)),
    };
  }

  int _maxSweepInputsPerBatchTx() {
    final maxByVbytes = ((_maxMigrationSweepVbytes - 42) ~/ 68);
    if (maxByVbytes <= 0) return 1;
    return maxByVbytes < _maxMigrationSweepInputs
        ? maxByVbytes
        : _maxMigrationSweepInputs;
  }

  List<List<Map<String, dynamic>>> _chunkUtxosForSweep(
    List<Map<String, dynamic>> confirmedUtxos,
  ) {
    final chunkSize = _maxSweepInputsPerBatchTx();
    final sorted = List<Map<String, dynamic>>.from(confirmedUtxos)
      ..sort((a, b) => ((b['amount'] as num).toDouble())
          .compareTo((a['amount'] as num).toDouble()));

    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < sorted.length; i += chunkSize) {
      final end = (i + chunkSize < sorted.length) ? i + chunkSize : sorted.length;
      chunks.add(sorted.sublist(i, end));
    }
    return chunks;
  }

  Future<List<Map<String, dynamic>>> _getConfirmedUtxosForSend({
    List<Map<String, dynamic>>? preSelectedUtxos,
  }) async {
    if (preSelectedUtxos != null && preSelectedUtxos.isNotEmpty) {
      return preSelectedUtxos
          .where((u) =>
              u['txid'] != 'pending_marker' &&
              ((u['confirmations'] as int?) ?? 0) > 0)
          .map((u) => Map<String, dynamic>.from(u))
          .toList();
    }

    if (_wallet == null) {
      return [];
    }

    final rpcUrl = await _rpcConfig.getRpcUrl();
    final rpcUser = await _rpcConfig.getRpcUser();
    final rpcPassword = await _rpcConfig.getRpcPassword();
    final all = await _ws.getUtxos(rpcUrl, rpcUser, rpcPassword, _wallet!.address);
    return all
        .where((u) =>
            u['txid'] != 'pending_marker' &&
            ((u['confirmations'] as int?) ?? 0) > 0)
        .map((u) => Map<String, dynamic>.from(u))
        .toList();
  }

  Future<Map<String, dynamic>> _sendSweepInBatches({
    required String rpcUrl,
    required String rpcUser,
    required String rpcPassword,
    required String toAddress,
    required List<Map<String, dynamic>> confirmedUtxos,
    double? feeRate,
  }) async {
    if (_wallet == null) {
      return {
        'success': false,
        'message': 'Wallet not initialized',
      };
    }

    final chunks = _chunkUtxosForSweep(confirmedUtxos);
    if (chunks.isEmpty) {
      return {
        'success': false,
        'message': 'No confirmed UTXOs available for batch send.',
      };
    }

    final txids = <String>[];
    double totalFee = 0.0;
    double grossSent = 0.0;

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkAmount = chunk.fold<double>(
        0.0,
        (sum, u) => sum + (u['amount'] as num).toDouble(),
      );

      _message = '⏳ Broadcasting batch ${i + 1}/${chunks.length}...';
      notifyListeners();

      final result = await _ws.sendTransaction(
        rpcUrl,
        rpcUser,
        rpcPassword,
        _wallet!.privateKey,
        _wallet!.address,
        toAddress,
        chunkAmount,
        feeRate: feeRate,
        preSelectedUtxos: chunk,
      );

      if (result['success'] != true) {
        final baseMessage = (result['message'] as String?) ??
            'Unknown error while broadcasting batch ${i + 1}.';
        return {
          'success': false,
          'batched': true,
          'batchTxids': txids,
          'completedBatches': txids.length,
          'totalBatches': chunks.length,
          'requiresManualFee': result['requiresManualFee'] == true,
          'feeEstimationFailed': result['feeEstimationFailed'] == true,
          'message': 'Batch ${i + 1}/${chunks.length} failed after '
              '${txids.length} successful batch(es). $baseMessage',
        };
      }

      final txid = (result['txid'] as String?) ?? '';
      if (txid.isNotEmpty) {
        txids.add(txid);
        _pendingTxids.add(txid);
        _pendingTimestamps[txid] = DateTime.now();
        _pendingTransactions[txid] = PendingTransaction(
          txid: txid,
          amount: chunkAmount,
          fee: (result['fee'] as num?)?.toDouble() ?? 0.0,
          toAddress: toAddress,
          timestamp: DateTime.now(),
          changeAmount: 0.0,
        );
      }

      final fee = (result['fee'] as num?)?.toDouble() ?? 0.0;
      totalFee += fee;
      grossSent += chunkAmount;
    }

    return {
      'success': true,
      'batched': true,
      'batchTxids': txids,
      'batchCount': chunks.length,
      'grossAmount': grossSent,
      'fee': totalFee,
      'netAmount': grossSent - totalFee,
    };
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

  Future<bool> runMigrationStoragePreflight() async {
    try {
      await _storage.write(
        key: 'migration_preflight',
        value: DateTime.now().toIso8601String(),
      );
      await _storage.delete(key: 'migration_preflight');
      return true;
    } catch (e) {
      _lastError = 'Migration failed: secure storage is unavailable. $e';
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
