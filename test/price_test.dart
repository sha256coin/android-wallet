import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:s256_wallet/models/price_info.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';

// The explorer's /api/price returns nulls while LiveCoinWatch has no rate for
// S256; the app must treat that as "no price", and keep the last price when a
// refresh fails.
void main() {
  group('PriceInfo', () {
    test('reads the explorer response', () {
      final p = PriceInfo.fromJson({'name': 'SHA256COIN', 'price': 0.0123, 'volume': 1500, 'cap': 2500000.5, 'liquidity': null});
      expect(p.hasPrice, isTrue);
      expect(p.price, 0.0123);
      expect(p.volume, 1500);
      expect(p.liquidity, isNull);
    });

    test('nulls, zero, negative and non-numbers are no price', () {
      expect(PriceInfo.fromJson({'price': null, 'volume': null, 'cap': null}).hasPrice, isFalse);
      expect(PriceInfo.fromJson({'price': 0}).hasPrice, isFalse);
      expect(PriceInfo.fromJson({'price': -1}).hasPrice, isFalse);
      expect(PriceInfo.fromJson({'price': '1.5'}).hasPrice, isFalse);
      expect(PriceInfo.fromJson({'price': double.nan}).hasPrice, isFalse);
    });

    test('formats small prices with more decimals', () {
      expect(PriceInfo.formatUsd(0.000123), '\$0.000123');
      expect(PriceInfo.formatUsd(0.0123), '\$0.0123');
      expect(PriceInfo.formatUsd(1.234), '\$1.23');
    });

    test('formats large amounts compactly', () {
      expect(PriceInfo.formatCompactUsd(950), '\$950.00');
      expect(PriceInfo.formatCompactUsd(12500), '\$12.50K');
      expect(PriceInfo.formatCompactUsd(3400000), '\$3.40M');
      expect(PriceInfo.formatCompactUsd(5600000000), '\$5.60B');
    });
  });

  group('BlockchainProvider.fetchPrice', () {
    Future<BlockchainProvider> fetched(BlockchainProvider bp, http.Response Function() answer) async {
      await http.runWithClient(() => bp.fetchPrice(), () => MockClient((_) async => answer()));
      return bp;
    }

    test('stores the price, and no price while the explorer has none', () async {
      final bp = BlockchainProvider();
      expect(bp.price, isNull);
      await fetched(bp, () => http.Response(jsonEncode({'price': null, 'volume': null, 'cap': null}), 200));
      expect(bp.price, isNull);
      await fetched(bp, () => http.Response(jsonEncode({'price': 0.05, 'volume': 10, 'cap': 100}), 200));
      expect(bp.price, 0.05);
    });

    test('keeps the last price when the request fails or the answer is garbage', () async {
      final bp = BlockchainProvider();
      await fetched(bp, () => http.Response(jsonEncode({'price': 0.05}), 200));
      await fetched(bp, () => http.Response('boom', 500));
      expect(bp.price, 0.05);
      await fetched(bp, () => http.Response('not json', 200));
      expect(bp.price, 0.05);
      await fetched(bp, () => http.Response(jsonEncode([1, 2]), 200));
      expect(bp.price, 0.05);
    });
  });
}
