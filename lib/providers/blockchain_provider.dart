import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:s256_wallet/config.dart';

class BlockchainProvider with ChangeNotifier {
  String _timestamp = '';
  final List<dynamic> _transactions = [];
  final double _price = 0.0; // Price API disabled, keeping as final constant
  bool _isLoading = false;
  bool _hasMore = true;
  int _startIndex = 0;
  final int _limit = 50;

  String get timestamp => _timestamp;
  List get transactions => _transactions;
  double get price => _price;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> loadBlockchain(String? address) async {
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('HH:mm:ss').format(now);

    // Clear existing transactions and reset pagination to fetch latest
    _transactions.clear();
    _startIndex = 0;
    _hasMore = true;

    await fetchTransactions(address);
    _timestamp = formattedDate;
    notifyListeners();
  }

  Future<void> fetchPrice() async {
    // Price API disabled - S256 not listed on LiveCoinWatch yet
    // TODO: Re-enable when S256 gets listed on price tracking services
    /*
    const url = Config.liveCoinWatchUrl;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'content-type': 'application/json',
          'x-api-key': Config.liveCoinWatchApiKey,
        },
        body: json.encode({
          'currency': 'USD',
          'code': Config.s256Code,
          'meta': true,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Price fetch request timed out after 10 seconds');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // LiveCoinWatch returns the price in 'rate' field
        if (data['rate'] != null) {
          _price = (data['rate'] as num).toDouble();
        } else {
          throw Exception('Price data not available in response');
        }
      } else {
        throw Exception(
            'Failed to load price, Status Code: ${response.statusCode}');
      }
    } catch (e) {
      // Keep previous price if fetch fails
      debugPrint('Error fetching price: $e');
    } finally {
      notifyListeners();
    }
    */
    // Price fetching disabled for S256 - no price API available yet
    debugPrint('Price fetching disabled - S256 not listed on exchanges yet');
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
        throw Exception('Failed to load transactions');
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    } finally {
      await fetchPrice();
      _isLoading = false;
      notifyListeners();
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
