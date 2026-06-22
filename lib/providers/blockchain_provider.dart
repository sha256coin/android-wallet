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

    // Clear existing transactions and reset pagination to fetch latest
    _transactions.clear();
    _startIndex = 0;
    _hasMore = true;
    _txCount = 0;

    await fetchTransactions(address);
    _timestamp = formattedDate;
    notifyListeners();
  }

  Future<void> fetchTransactions(String? address) async {
    if (_isLoading || address == null) return;
    _isLoading = true;

    final url =
        '${Config.explorerUrl}${Config.getAddressTxsEndpoint}/$address/$_startIndex/$_limit';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Transaction fetch request timed out after 15 seconds');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          _hasMore = false;
        } else {
          List<Map<String, dynamic>> castedData =
              data.whereType<Map<String, dynamic>>().toList();
          List<Map<String, dynamic>> transactions =
              splitTransactions(castedData);
          _transactions.addAll(transactions);
          _startIndex += _limit;
        }
      } else {
        await _fetchTransactionsViaHelper(address);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      await _fetchTransactionsViaHelper(address);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchTransactionsViaHelper(String address) async {
    try {
      final data = await _walletService.getTransactions(
        address,
        offset: _startIndex,
        limit: _limit,
      );

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
      _startIndex += _limit;
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
