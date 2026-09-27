import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:s256_wallet/providers/blockchain_provider.dart';

// A refresh (app resume, timer, pull-to-refresh) must keep the current history
// on screen until the explorer answers, and keep it if the explorer fails.
void main() {
  const address = 's21qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';

  Map<String, dynamic> tx(String id) =>
      {'txid': id, 'timestamp': 1700000000, 'sent': 0, 'received': 1, 'balance': 1};

  // Explorer /ext/getaddresstxs/<address>/<start>/<limit> pages through
  // [history]; the fallback /api/address endpoint fails unless [fallback] is given.
  MockClient client(
    List<Map<String, dynamic>> history, {
    Future<http.Response>? wait,
    int status = 200,
    http.Response? fallback,
  }) =>
      MockClient((request) async {
        final path = request.url.pathSegments;
        if (path.contains('getaddresstxs')) {
          if (wait != null) return wait;
          if (status != 200) return http.Response('boom', status);
          final start = int.parse(path[path.length - 2]);
          final limit = int.parse(path.last);
          return http.Response(jsonEncode(history.skip(start).take(limit).toList()), 200);
        }
        return fallback ?? http.Response('boom', 500);
      });

  List<String> ids(BlockchainProvider bp) => bp.transactions.map((t) => t['txid'] as String).toList();

  Future<BlockchainProvider> loaded(List<Map<String, dynamic>> history) async {
    final bp = BlockchainProvider();
    await http.runWithClient(() => bp.loadBlockchain(address), () => client(history));
    return bp;
  }

  test('initial load fills the list', () async {
    final bp = await loaded([tx('a'), tx('b')]);
    expect(ids(bp), ['a', 'b']);
  });

  test('refresh keeps the list while waiting, then replaces it', () async {
    final bp = await loaded([tx('a')]);
    final gate = Completer<http.Response>();

    final refresh = http.runWithClient(
      () => bp.loadBlockchain(address),
      () => client(const [], wait: gate.future),
    );
    await Future<void>.delayed(Duration.zero);
    expect(ids(bp), ['a'], reason: 'must not flash an empty list');

    gate.complete(http.Response(jsonEncode([tx('new'), tx('a')]), 200));
    await refresh;
    expect(ids(bp), ['new', 'a']);
  });

  test('refresh keeps the previous list when explorer and fallback both fail', () async {
    final bp = await loaded([tx('a'), tx('b')]);
    await http.runWithClient(
      () => bp.loadBlockchain(address),
      () => client(const [], status: 500),
    );
    expect(ids(bp), ['a', 'b']);
  });

  test('refresh uses the fallback explorer API when the main one fails', () async {
    final bp = await loaded([tx('a')]);
    final fallback = http.Response(
      jsonEncode({
        'txCount': 1,
        'transactions': [
          {
            'txid': 'f',
            'blocktime': 1700000000,
            'confirmations': 3,
            'addressAmount': {'direction': 'in', 'net': 2},
          },
        ],
      }),
      200,
    );
    await http.runWithClient(
      () => bp.loadBlockchain(address),
      () => client(const [], status: 500, fallback: fallback),
    );
    expect(ids(bp), ['f']);
  });

  test('refresh to an empty history empties the list', () async {
    final bp = await loaded([tx('a')]);
    await http.runWithClient(() => bp.loadBlockchain(address), () => client(const []));
    expect(bp.transactions, isEmpty);
  });

  test('refresh restarts paging from the newest page', () async {
    final many = List.generate(120, (i) => tx('t$i'));
    final bp = await loaded(many);
    expect(bp.transactions, hasLength(50));

    // "Load more" fetches the next page.
    await http.runWithClient(() => bp.fetchTransactions(address), () => client(many));
    expect(bp.transactions, hasLength(100));

    await http.runWithClient(() => bp.loadBlockchain(address), () => client(many));
    expect(bp.transactions, hasLength(50));
    expect(bp.transactions.first['txid'], 't0');
    expect(bp.hasMore, isTrue);

    await http.runWithClient(() => bp.fetchTransactions(address), () => client(many));
    expect(bp.transactions[50]['txid'], 't50');
  });
}
