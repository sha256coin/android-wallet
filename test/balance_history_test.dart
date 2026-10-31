import 'package:flutter_test/flutter_test.dart';
import 'package:s256_wallet/models/price_info.dart';
import 'package:s256_wallet/widgets/balance_chart.dart';

/// A row of BlockchainProvider.transactions: signed net amount, seconds.
Map<String, dynamic> tx(double amount, int day) => {
      'txid': 'a' * 64,
      'amount': amount,
      'timestamp': DateTime.utc(2026, 10, day).millisecondsSinceEpoch ~/ 1000,
    };

void main() {
  group('BalanceHistory.fromExplorer', () {
    test('walks back from the confirmed balance, newest first', () {
      // Oldest to newest: +100, +50, -30 -> 120.
      final h = BalanceHistory.fromExplorer([tx(-30, 3), tx(50, 2), tx(100, 1)], confirmedBalance: 120);
      expect(h.start, 0);
      expect(h.points.map((p) => p.balance), [100, 150, 120]);
      expect(h.points.map((p) => p.change), [100, 50, -30]);
      expect(h.points.first.time!.toUtc(), DateTime.utc(2026, 10, 1));
      expect(h.timed, isTrue);
    });

    test('with only the newest transactions loaded it starts at the earlier balance', () {
      final h = BalanceHistory.fromExplorer([tx(-25, 9), tx(10, 8)], confirmedBalance: 1000);
      expect(h.start, 1015);
      expect(h.points.map((p) => p.balance), [1025, 1000]);
    });

    test('a pending total different from the confirmed balance is kept', () {
      final h = BalanceHistory.fromExplorer([tx(10, 8)], confirmedBalance: 10, totalBalance: 15);
      expect(h.pendingTotal, 15);
      expect(BalanceHistory.fromExplorer([tx(10, 8)], confirmedBalance: 10, totalBalance: 10).pendingTotal, isNull);
    });

    test('no rounding drift over many transactions, never below zero', () {
      final h = BalanceHistory.fromExplorer([for (var i = 0; i < 100; i++) tx(0.1, 1 + i % 28)], confirmedBalance: 10);
      expect(h.start, 0);
      expect(BalanceHistory.fromExplorer([tx(50, 1)], confirmedBalance: 20).start, 0);
    });
  });

  group('axis', () {
    test('round steps around the data', () {
      final r = niceRange(29027.8, 29152.8);
      expect((r.min, r.max, r.step), (29000, 29200, 50));
      final flat = niceRange(500, 500);
      expect(flat.max, greaterThan(flat.min));
    });

    test('compact labels follow the step', () {
      expect(compactAmount(29050, 50), '29.05K');
      expect(compactAmount(1250000, 50000), '1.25M');
      expect(compactAmount(0.5, 0.1), '0.5');
    });
  });

  group('PriceInfo.change24h', () {
    test('read for a live price, also when negative', () {
      expect(PriceInfo.fromJson({'price': 0.05, 'change24h': -2.35}).change24h, -2.35);
      expect(PriceInfo.fromJson({'price': 0.05, 'change24h': 1.5}).change24h, 1.5);
      expect(PriceInfo.fromJson({'price': 0.05, 'change24h': null}).change24h, isNull);
      expect(PriceInfo.fromJson({'price': 0.05, 'change24h': '5'}).change24h, isNull);
    });

    test('never for a last traded price', () {
      expect(PriceInfo.fromJson({'price': 0.05, 'change24h': 3.1, 'lastTraded': 1792295700000}).change24h, isNull);
    });

    test('formatted with a sign', () {
      expect(PriceInfo.formatChange(2.345), '+2.35%');
      expect(PriceInfo.formatChange(-1.2), '−1.20%');
    });
  });
}
