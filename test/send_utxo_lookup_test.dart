import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:s256_wallet/services/s256_signer.dart';
import 'package:s256_wallet/services/wallet_service.dart';

// A send from a wallet with many UTXOs used to look up every UTXO's
// scriptPubKey with its own gettxout call, although scantxoutset had already
// returned it: hundreds of round trips before the transaction was signed.
void main() {
  final service = WalletService();
  final wallet = service.generateNewWallet();
  final address = wallet['address']!;
  final ownScript = HEX.encode(S256Signer.scriptFromAddress(address));

  /// Runs [body] against a mocked node with [utxoCount] UTXOs of 1 S256 each;
  /// returns how often each RPC method was called.
  Future<Map<String, int>> withNode(int utxoCount, Future<void> Function() body,
      {String? scanScript}) async {
    final calls = <String, int>{};
    final client = MockClient((req) async {
      final method = (jsonDecode(req.body) as Map)['method'] as String;
      calls[method] = (calls[method] ?? 0) + 1;
      final Object? result = switch (method) {
        'scantxoutset' => {
            'success': true,
            'unspents': [
              for (var i = 0; i < utxoCount; i++)
                {
                  'txid': i.toRadixString(16).padLeft(64, '0'),
                  'vout': 0,
                  'scriptPubKey': scanScript ?? ownScript,
                  'amount': 1.0,
                  'height': 100,
                },
            ],
          },
        'getblockcount' => 200,
        'getrawmempool' => <String>[],
        'gettxout' => {
            'scriptPubKey': {'hex': ownScript},
          },
        'sendrawtransaction' => 'ab' * 32,
        _ => null,
      };
      return http.Response(jsonEncode({'result': result, 'error': null, 'id': 1}), 200);
    });
    await http.runWithClient(body, () => client);
    return calls;
  }

  test('getUtxos keeps the scriptPubKey from scantxoutset', () async {
    late List<Map<String, dynamic>> utxos;
    await withNode(3, () async {
      utxos = await service.getUtxos('http://127.0.0.1/ok', '', '', address);
    });
    expect(utxos, hasLength(3));
    expect(utxos.map((u) => u['scriptPubKey']), everyElement(ownScript));
  });

  test('a script that is not the address\'s own is not trusted', () async {
    late List<Map<String, dynamic>> utxos;
    await withNode(2, () async {
      utxos = await service.getUtxos('http://127.0.0.1/ok', '', '', address);
    }, scanScript: '0014${'00' * 20}');
    expect(utxos.map((u) => u['scriptPubKey']), everyElement(isNull));
  });

  test('a send from 200 UTXOs makes no gettxout calls', () async {
    late Map<String, dynamic> result;
    final calls = await withNode(200, () async {
      result = await service.sendTransaction(
        'http://127.0.0.1/ok', '', '',
        wallet['privateKey']!, address, address, 0.5,
        feeRate: 0.0001,
      );
    });
    expect(result['success'], isTrue, reason: '$result');
    expect(calls['gettxout'], isNull);
    expect(calls['sendrawtransaction'], 1);
  });

  // Advanced send: the coin-control list comes from getUtxos and the user's
  // picks are passed back as preSelectedUtxos.
  test('an advanced send with picked UTXOs makes no gettxout calls', () async {
    late Map<String, dynamic> result;
    final calls = await withNode(50, () async {
      final all = await service.getUtxos('http://127.0.0.1/ok', '', '', address);
      final picked = [all[3], all[7]];
      result = await service.sendTransaction(
        'http://127.0.0.1/ok', '', '',
        wallet['privateKey']!, address, address, 1.5,
        feeRate: 0.0001,
        preSelectedUtxos: picked,
      );
    });
    expect(result['success'], isTrue, reason: '$result');
    expect(calls['gettxout'], isNull);
  });

  test('picked UTXOs without a script are still looked up', () async {
    late Map<String, dynamic> result;
    final calls = await withNode(5, () async {
      final picked = [
        for (final txid in ['01' * 32, '02' * 32])
          {'txid': txid, 'vout': 0, 'amount': 1.0, 'height': 100, 'confirmations': 101},
      ];
      result = await service.sendTransaction(
        'http://127.0.0.1/ok', '', '',
        wallet['privateKey']!, address, address, 1.5,
        feeRate: 0.0001,
        preSelectedUtxos: picked,
      );
    });
    expect(result['success'], isTrue, reason: '$result');
    expect(calls['gettxout'], 2);
  });
}
