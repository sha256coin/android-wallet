import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:s256_wallet/config.dart';
import 'package:s256_wallet/services/wallet_service.dart';

class BlockchainProvider with ChangeNotifier {
  String _timestamp = '';
  final List<dynamic> _transactions = [];
  final WalletService _walletService = WalletService();
  bool _isLoading = false;
  bool _hasMore = true;
  int _startIndex = 0;
  final int _limit = 50;
  int _txCount = 0;

  String get timestamp => _timestamp;
  List get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> loadBlockchain(String? address) async {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('HH:mm:ss').format(now);

    // A refresh (app resume, timer, pull-to-refresh) keeps the current list on
    // screen and replaces it only once the newest page has arrived. Clearing
    // it first made the wallet show "No Transactions Yet" until the explorer
    // answered, and kept it empty if the request failed.
    await _fetchPage(address, refresh: true);
    _timestamp = formattedDate;
    notifyListeners();
  }

  /// Loads the next page (infinite scroll).
  Future<void> fetchTransactions(String? address) =>
      _fetchPage(address, refresh: false);

  /// With [refresh], fetches the newest page and replaces the list in one step
  /// when the request succeeds; on failure the list stays as it was.
  Future<void> _fetchPage(String? address, {required bool refresh}) async {
    if (_isLoading || address == null) return;
    _isLoading = true;

    final start = refresh ? 0 : _startIndex;
    final url =
        '${Config.explorerUrl}${Config.getAddressTxsEndpoint}/$address/$start/$_limit';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Transaction fetch request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (refresh) _resetList();
        if (data.isEmpty) {
          _hasMore = false;
        } else {
          List<Map<String, dynamic>> castedData =
              data.whereType<Map<String, dynamic>>().toList();
          List<Map<String, dynamic>> transactions =
              splitTransactions(castedData);
          _transactions.addAll(transactions);
          _startIndex = start + _limit;
        }
      } else {
        await _fetchTransactionsViaHelper(address, start: start, refresh: refresh);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      await _fetchTransactionsViaHelper(address, start: start, refresh: refresh);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetList() {
    _transactions.clear();
    _startIndex = 0;
    _hasMore = true;
    _txCount = 0;
  }

  Future<void> _fetchTransactionsViaHelper(
    String address, {
    required int start,
    required bool refresh,
  }) async {
    try {
      final data = await _walletService.getTransactions(
        address,
        offset: start,
        limit: _limit,
      );

      if (refresh) _resetList();
      final rawList =
          (data['transactions'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      _txCount = data['txCount'] as int? ?? _txCount;

      if (rawList.isEmpty) {
        _hasMore = false;
        return;
      }

      final mapped = rawList.map((tx) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final direction = (tx['direction'] as String?) ?? 'received';
        final timestamp = tx['timestamp'] as int? ??
            (DateTime.now().millisecondsSinceEpoch ~/ 1000);

        return {
          'timestamp': timestamp,
          'txid': tx['txid'],
          'amount': direction == 'sent' ? -amount.abs() : amount.abs(),
          'balance': tx['balance'],
          'confirmations': tx['confirmations'],
        };
      }).toList();

      _transactions.addAll(mapped);
      _startIndex = start + _limit;
      _hasMore = _txCount > 0 ? _transactions.length < _txCount : rawList.length == _limit;
    } catch (e) {
      debugPrint('Fallback history helper failed: $e');
    }
  }

  List<Map<String, dynamic>> splitTransactions(
      List<Map<String, dynamic>> transactions) {
    List<Map<String, dynamic>> splitTxs = [];

    for (var tx in transactions) {
      // Convert to double to handle both int and double from API
      final sent = (tx['sent'] ?? 0).toDouble();
      final received = (tx['received'] ?? 0).toDouble();

      double amount;

      if (sent != 0 && received != 0) {
        // Both sent and received (self-send with change)
        amount = received - sent;
      } else if (received != 0) {
        // Only received (incoming transaction)
        amount = received;
      } else {
        // Only sent (outgoing transaction)
        amount = -sent;
      }

      splitTxs.add({
        'timestamp': tx['timestamp'],
        'txid': tx['txid'],
        'amount': amount,
        'balance': tx['balance'],
      });
    }

    return splitTxs;
  }

  void clearTransactions() {
    _transactions.clear();
    _startIndex = 0;
    _hasMore = true;
    notifyListeners();
  }
}
