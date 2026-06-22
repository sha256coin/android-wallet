import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:bech32/bech32.dart';
import 'package:base_x/base_x.dart';
import 'package:hex/hex.dart';
import 'package:s256_wallet/config.dart';
import 'package:s256_wallet/services/rpc_config_service.dart';
import 'package:s256_wallet/services/s256_signer.dart';

class WalletService {
  final BaseXCodec base58 =
      BaseXCodec('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz');
  final RpcConfigService _rpcConfig = RpcConfigService();

  static const String addressPrefix = Config.addressPrefix;
  static const int networkPrefix = Config.networkPrefix;

  // Generate a new wallet
  Map<String, String> generateNewWallet() {
    final random = Random.secure();
    final privateKeyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privateKeyBytes[i] = random.nextInt(256);
    }

    final wif = _privateKeyToWif(privateKeyBytes);
    final address = loadAddressFromKey(wif);

    return {
      'privateKey': wif,
      'address': address ?? '',
    };
  }

  // Generate a new Seed Phrase wallet
  Future<Map<String, String>> generateNewSeedWallet({int words = 12}) async {
    final int strength = words == 24 ? 256 : 128;
    final mnemonic = bip39.generateMnemonic(strength: strength);
    return (await getWalletFromMnemonic(mnemonic))!;
  }

  // Mnemonic generation
  String generateMnemonic({int strength = 128}) {
    return bip39.generateMnemonic(strength: strength);
  }

  // Check if mnemonic is valid
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  // Generate a new private key (WIF)
  String? generatePrivateKey() {
    final wallet = generateNewWallet();
    return wallet['privateKey'];
  }

  Future<Map<String, String>?> getWalletFromMnemonic(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) return null;

    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);

    final child = root.derivePath("m/44'/0'/0'/0/0");
    final privateKey = child.privateKey!;

    final wif = _privateKeyToWif(privateKey);
    final address = loadAddressFromKey(wif);

    return {
      'mnemonic': mnemonic,
      'privateKey': wif,
      'address': address ?? '',
    };
  }

  // Derive private key from mnemonic (legacy support if needed)
  Uint8List derivePrivateKeyFromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/0'/0'/0/0");
    return child.privateKey!;
  }

  // Get WIF from private key
  String getWifFromPrivateKey(Uint8List privateKey) {
    return _privateKeyToWif(privateKey);
  }

  String? loadAddressFromKey(String wifPrivateKey) {
    try {
      final privateKey = _wifToPrivateKey(wifPrivateKey);
      final node = bip32.BIP32.fromPrivateKey(privateKey, Uint8List(32));
      final pubKey = node.publicKey;
      final pubKeyHash = _pubKeyToP2WPKH(pubKey);

      return _encodeBech32Address(addressPrefix, 0, pubKeyHash);
    } catch (e) {
      return null;
    }
  }

  String _privateKeyToWif(Uint8List privateKey) {
    final extended = Uint8List(1 + privateKey.length + 1);
    extended[0] = networkPrefix;
    extended.setRange(1, 1 + privateKey.length, privateKey);
    extended[extended.length - 1] = 0x01; // Compressed flag

    final checksum = _calculateChecksum(extended);
    final withChecksum = Uint8List(extended.length + checksum.length);
    withChecksum.setRange(0, extended.length, extended);
    withChecksum.setRange(extended.length, withChecksum.length, checksum);

    return base58.encode(withChecksum);
  }

  Uint8List _wifToPrivateKey(String wif) {
    final bytes = base58.decode(wif);
    final keyWithChecksum = bytes.sublist(0, bytes.length - 4);
    final checksum = bytes.sublist(bytes.length - 4);

    final calculatedChecksum = _calculateChecksum(keyWithChecksum);
    if (!_listEquals(checksum, calculatedChecksum)) {
      throw Exception('Invalid WIF checksum');
    }

    if (keyWithChecksum[0] != networkPrefix) {
      throw Exception(
          'Incompatible WIF prefix: 0x${keyWithChecksum[0].toRadixString(16).toUpperCase()}. S256 uses 0x${networkPrefix.toRadixString(16).toUpperCase()}');
    }

    return Uint8List.fromList(keyWithChecksum.sublist(
        1, keyWithChecksum.length - (keyWithChecksum.length > 32 ? 1 : 0)));
  }

  Uint8List _calculateChecksum(Uint8List data) {
    final sha256_1 = sha256.convert(data).bytes;
    final sha256_2 = sha256.convert(Uint8List.fromList(sha256_1)).bytes;
    return Uint8List.fromList(sha256_2.sublist(0, 4));
  }

  Uint8List _pubKeyToP2WPKH(List<int> pubKey) {
    final sha256Hash = sha256.convert(pubKey).bytes;
    final ripemd160Hash =
        RIPEMD160Digest().process(Uint8List.fromList(sha256Hash));
    return Uint8List.fromList(ripemd160Hash);
  }

  String _encodeBech32Address(String hrp, int version, Uint8List program) {
    final converted = _convertBits(program, 8, 5, true);
    final data = [version] + converted;
    return const Bech32Codec().encode(Bech32(hrp, data));
  }

  List<int> _convertBits(List<int> data, int from, int to, bool pad) {
    int acc = 0, bits = 0;
    final ret = <int>[];
    final maxv = (1 << to) - 1;

    for (final value in data) {
      if (value < 0 || (value >> from) != 0) throw Exception('Invalid value');
      acc = (acc << from) | value;
      bits += from;
      while (bits >= to) {
        bits -= to;
        ret.add((acc >> bits) & maxv);
      }
    }

    if (pad && bits > 0) ret.add((acc << (to - bits)) & maxv);
    if (!pad && (bits >= from || ((acc << (to - bits)) & maxv) != 0)) {
      throw Exception('Invalid padding');
    }
    return ret;
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // RPC calls
  Future<Map<String, dynamic>?> rpcRequest(
    String rpcUrl,
    String rpcUser,
    String rpcPassword,
    String method,
    [List<dynamic>? params]
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (rpcUser.isNotEmpty || rpcPassword.isNotEmpty) {
      final auth =
          'Basic ${base64Encode(utf8.encode('$rpcUser:$rpcPassword'))}';
      headers['Authorization'] = auth;
    }

    final body = jsonEncode({
      'jsonrpc': '1.0',
      'id': 'mobile',
      'method': method,
      'params': params ?? [],
    });

    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP status code: ${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw Exception('Invalid RPC response format received');
    } catch (e) {
      rethrow;
    }
  }

  // Legacy rpcRequest for backward compatibility if needed, but better to use the one with credentials
  Future<Map<String, dynamic>?> rpcRequestLegacy(String method,
      [List<dynamic>? params]) async {
    final rpcUrl = await _rpcConfig.getRpcUrl();
    final rpcUser = await _rpcConfig.getRpcUser();
    final rpcPassword = await _rpcConfig.getRpcPassword();

    return rpcRequest(rpcUrl, rpcUser, rpcPassword, method, params);
  }

  // Get UTXOs for address
  Future<List<Map<String, dynamic>>> getUtxos(
    String rpcUrl,
    String rpcUser,
    String rpcPassword,
    String address,
  ) async {
    // 1. Get confirmed UTXOs from the chain
    final result = await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'scantxoutset', [
      'start',
      [
        {'desc': 'addr($address)'}
      ]
    ]);

    int currentHeight = 0;
    final blockCountResult =
        await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'getblockcount');
    if (blockCountResult != null && blockCountResult['result'] != null) {
      currentHeight = (blockCountResult['result'] as num).toInt();
    }

    final List<Map<String, dynamic>> confirmedUtxos = [];
    if (result != null && result['result'] != null) {
      final unspents = result['result']['unspents'] as List<dynamic>? ?? [];
      for (var u in unspents) {
        final int utxoHeight = (u['height'] as num).toInt();
        final int conf = currentHeight > 0 && utxoHeight > 0
            ? currentHeight - utxoHeight + 1
            : 1;
        confirmedUtxos.add({
          'txid': u['txid'],
          'vout': u['vout'],
          'amount': (u['amount'] is num)
              ? (u['amount'] as num).toDouble()
              : double.tryParse(u['amount'].toString()) ?? 0.0,
          'height': utxoHeight,
          'confirmations': conf,
        });
      }
    }

    // 2. Get mempool txids
    final List<Map<String, dynamic>> decodedMempool = [];
    bool rpcMempoolSucceeded = false;
    final mempoolResult =
        await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'getrawmempool', [false]);

    if (mempoolResult != null && mempoolResult['result'] != null) {
      rpcMempoolSucceeded = true;
      final List<dynamic> txids = mempoolResult['result'] as List<dynamic>;
      
      // Batch processing mempool to avoid too many requests
      for (var txid in txids) {
        final rawTx = await rpcRequest(
            rpcUrl, rpcUser, rpcPassword, 'getrawtransaction', [txid, true]);
        if (rawTx != null && rawTx['result'] != null) {
          decodedMempool.add(rawTx['result'] as Map<String, dynamic>);
        }
      }
    }

    // Fallback: ONLY if RPC failed (not if mempool was just empty)
    if (!rpcMempoolSucceeded) {
      try {
        final explorerResponse =
            await http.get(Uri.parse('https://sha256coin.eu/api/mempool'));
        if (explorerResponse.statusCode == 200) {
          final List<dynamic> explorerTxs =
              jsonDecode(explorerResponse.body)['transactions'];
          for (var tx in explorerTxs) {
            decodedMempool.add(tx as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }

    final List<Map<String, dynamic>> finalUtxos = [];
    bool hasMempoolActivity = false;

    // 3. Process Decoded Mempool (Detect spends and incoming)
    final spentInMempool = <String>{};
    final incomingFromMempool = <Map<String, dynamic>>[];

    for (var data in decodedMempool) {
      final String txid = data['txid'] ?? '';

      // Check inputs (detect our coins being spent)
      final vins = data['vin'] as List<dynamic>? ?? [];
      for (var vin in vins) {
        final String? vinTxid = vin['txid'] ?? vin['prev_txid'];
        final dynamic vinVout = vin['vout'] ?? vin['prev_vout'];
        if (vinTxid != null && vinVout != null) {
          spentInMempool.add('$vinTxid:$vinVout');
        }
      }

      // Check outputs (detect new funds or change)
      final vouts = data['vout'] as List<dynamic>? ?? [];
      for (var vout in vouts) {
        final scriptPubKey = vout['scriptPubKey'] as Map<String, dynamic>? ?? {};
        final addresses = scriptPubKey['addresses'] as List<dynamic>? ?? [];
        final String? singleAddr = scriptPubKey['address'] as String?;

        if (addresses.contains(address) ||
            (singleAddr != null && singleAddr == address)) {
          double parsedAmount = 0.0;
          final rawValue = vout['value'];
          if (rawValue is num) {
            parsedAmount = rawValue.toDouble();
          } else if (rawValue is String) {
            parsedAmount = double.tryParse(rawValue) ?? 0.0;
          }

          incomingFromMempool.add({
            'txid': txid,
            'vout': vout['n'] ?? 0,
            'amount': parsedAmount,
            'confirmations': 0,
          });
          hasMempoolActivity = true;
        }
      }
    }

    // 4. Merge Confirmed and Mempool
    for (var utxo in confirmedUtxos) {
      final outpoint = '${utxo['txid']}:${utxo['vout']}';
      if (spentInMempool.contains(outpoint)) {
        hasMempoolActivity = true;
      } else {
        finalUtxos.add(utxo);
      }
    }
    finalUtxos.addAll(incomingFromMempool);

    // 5. Final Force-Yellow logic
    if (hasMempoolActivity && !finalUtxos.any((u) => u['confirmations'] == 0)) {
      finalUtxos.add({
        'txid': 'pending_marker',
        'amount': 0.0,
        'confirmations': 0,
      });
    }

    return finalUtxos;
  }

  // Send transaction
  Future<Map<String, dynamic>> sendTransaction(
    String rpcUrl,
    String rpcUser,
    String rpcPassword,
    String privateKeyWif,
    String fromAddress,
    String toAddress,
    double amount, {
    double? feeRate,
    List<Map<String, dynamic>>? preSelectedUtxos,
  }) async {
    final allUtxos = await getUtxos(rpcUrl, rpcUser, rpcPassword, fromAddress);
    final utxos = (preSelectedUtxos != null && preSelectedUtxos.isNotEmpty)
        ? List<Map<String, dynamic>>.from(preSelectedUtxos)
        : allUtxos
            .where((u) =>
                u['txid'] != 'pending_marker' && (u['confirmations'] as int) > 0)
            .toList();

    if (utxos.isEmpty) {
      final hasPending = allUtxos.any(
          (u) => u['txid'] != 'pending_marker' && (u['confirmations'] as int) == 0);
      return {
        'success': false,
        'message': hasPending
            ? 'Your funds are pending confirmation. Please wait approximately 20 minutes before sending again.'
            : 'No confirmed funds available. Please wait approximately 20 minutes for your deposit to confirm.'
      };
    }

    for (final utxo in utxos) {
      if (utxo['scriptPubKey'] == null || (utxo['scriptPubKey'] as String).isEmpty) {
        try {
          final txOut = await rpcRequest(
            rpcUrl,
            rpcUser,
            rpcPassword,
            'gettxout',
            [utxo['txid'], utxo['vout']],
          );
          if (txOut?['result']?['scriptPubKey']?['hex'] != null) {
            utxo['scriptPubKey'] = txOut!['result']['scriptPubKey']['hex'] as String;
          }
        } catch (_) {}
      }

      if (utxo['scriptPubKey'] == null || (utxo['scriptPubKey'] as String).isEmpty) {
        try {
          final generatedScript = S256Signer.scriptFromAddress(fromAddress);
          utxo['scriptPubKey'] = HEX.encode(generatedScript);
        } catch (_) {
          return {
            'success': false,
            'message': 'Could not resolve scriptPubKey for UTXO ${utxo['txid']}.',
          };
        }
      }
    }

    final totalAvailable = utxos.fold(
      0.0,
      (sum, utxo) => sum + (utxo['amount'] as num).toDouble(),
    );
    final bool isSweep = (amount >= totalAvailable - 0.00001);

    utxos.sort((a, b) => ((b['amount'] as num).toDouble())
        .compareTo((a['amount'] as num).toDouble()));

    double currentFeeRate = feeRate ?? 0.00001;
    if (feeRate == null) {
      try {
        final feeResult = await rpcRequest(
          rpcUrl,
          rpcUser,
          rpcPassword,
          'estimatesmartfee',
          [6],
        );
        if (feeResult != null &&
            feeResult['result'] != null &&
            feeResult['result']['feerate'] != null) {
          currentFeeRate = (feeResult['result']['feerate'] as num).toDouble();
        }
      } catch (_) {}
    }

    List<Map<String, dynamic>> selectedUtxos = [];
    double inputSum = 0.0;

    for (int i = 0; i < utxos.length; i++) {
      selectedUtxos.add(utxos[i]);
      final utxo = utxos[i];
      inputSum += (utxo['amount'] as num).toDouble();

      if (isSweep && i < utxos.length - 1) continue;

      final inputCount = selectedUtxos.length;
      final bool isDestLegacy = !toAddress.toLowerCase().startsWith('s2');
      final int destOutputSize = isDestLegacy ? 34 : 31;
      const int changeOutputSize = 31;

      int txSize = 11 + (inputCount * 68);
      if (isSweep) {
        txSize += destOutputSize;
      } else {
        txSize += destOutputSize + changeOutputSize;
      }

      final fee = currentFeeRate * txSize / 1000;
      final actualFee = double.parse(fee.toStringAsFixed(8));

      if (inputSum >= (isSweep ? actualFee : amount + actualFee)) {
        final inputs = selectedUtxos.map((u) {
          String? scriptHex = u['scriptPubKey'] as String?;
          if (scriptHex == null || scriptHex.isEmpty) {
            scriptHex = HEX.encode(S256Signer.scriptFromAddress(fromAddress));
          }
          return S256TxInput(
            txid: u['txid'] as String,
            vout: u['vout'] as int,
            scriptPubKey: Uint8List.fromList(HEX.decode(scriptHex)),
            satoshis: ((u['amount'] as num).toDouble() * 1e8).round(),
          );
        }).toList();

        final outputs = <S256TxOutput>[];
        try {
          if (isSweep) {
            final sweepSats = ((inputSum - actualFee) * 1e8).round();
            if (sweepSats <= 546) {
              return {
                'success': false,
                'message': 'Balance too low to cover transaction fees.'
              };
            }
            outputs.add(S256TxOutput(
              scriptPubKey: S256Signer.scriptFromAddress(toAddress),
              satoshis: sweepSats,
            ));
          } else {
            outputs.add(S256TxOutput(
              scriptPubKey: S256Signer.scriptFromAddress(toAddress),
              satoshis: (amount * 1e8).round(),
            ));
            final changeSats = ((inputSum - amount - actualFee) * 1e8).round();
            if (changeSats > 546) {
              outputs.add(S256TxOutput(
                scriptPubKey: S256Signer.scriptFromAddress(fromAddress),
                satoshis: changeSats,
              ));
            }
          }
        } catch (_) {
          return {
            'success': false,
            'message': 'Invalid destination address provided.'
          };
        }

        String signedHex;
        try {
          signedHex = S256Signer.signTransaction(
            inputs: inputs,
            outputs: outputs,
            wif: privateKeyWif,
          );
        } catch (e) {
          return {
            'success': false,
            'message': 'Signing failed: $e'
          };
        }

        final sendResult = await rpcRequest(
          rpcUrl,
          rpcUser,
          rpcPassword,
          'sendrawtransaction',
          [signedHex],
        );

        if (sendResult != null && sendResult['result'] != null) {
          final changeAmount = isSweep
              ? 0.0
              : double.parse((inputSum - amount - actualFee).toStringAsFixed(8));
          return {
            'success': true,
            'txid': sendResult['result'],
            'fee': actualFee,
            'change': changeAmount,
          };
        }

        final errorMessage = sendResult?['error']?['message'] ?? 'Unknown error';
        if (errorMessage.contains('insufficient fee') ||
            errorMessage.contains('rejecting replacement')) {
          return {
            'success': false,
            'message':
                'You have a pending transaction. Please wait approximately 20 minutes before sending another transaction.'
          };
        }
        return {'success': false, 'message': errorMessage};
      }
    }

    return {
      'success': false,
      'message':
          'Insufficient funds. Available balance: ${inputSum.toStringAsFixed(8)} S256.'
    };
  }

  // Get transaction history for an address via explorer API with pagination.
  Future<Map<String, dynamic>> getTransactions(
    String address, {
    int offset = 0,
    int limit = 10,
  }) async {
    const String explorerBase = 'https://explorer.sha256coin.eu/api/address';
    final url = '$explorerBase/$address/txs?offset=$offset&limit=$limit';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return {'transactions': <Map<String, dynamic>>[], 'txCount': 0};
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final txList = decoded['transactions'] as List<dynamic>? ?? [];
      final txCount = decoded['txCount'] as int? ?? 0;

      final parsedTransactions = txList.whereType<Map<String, dynamic>>().map((tx) {
        final amt = tx['addressAmount'] as Map<String, dynamic>? ?? {};
        final direction = (amt['direction'] as String?) ?? 'in';
        final net = (amt['net'] as num?)?.toDouble() ?? 0.0;
        final confirmations = (tx['confirmations'] as int?) ?? 0;
        final blocktime = tx['blocktime'] as int? ?? tx['time'] as int?;

        return {
          'txid': tx['txid'] as String,
          'amount': net.abs(),
          'direction': direction == 'out' ? 'sent' : 'received',
          'confirmations': confirmations,
          'timestamp': blocktime,
          'counterparty': null,
        };
      }).toList();

      return {
        'transactions': parsedTransactions,
        'txCount': txCount,
      };
    } catch (_) {
      return {'transactions': <Map<String, dynamic>>[], 'txCount': 0};
    }
  }

  // Get network info
  Future<Map<String, dynamic>?> getNetworkInfo(
    String rpcUrl,
    String rpcUser,
    String rpcPassword,
  ) async {
    final blockchainInfo =
        await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'getblockchaininfo');
    final networkInfo =
        await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'getnetworkinfo');
    final mempoolInfo =
        await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'getmempoolinfo');
    final miningInfo =
        await rpcRequest(rpcUrl, rpcUser, rpcPassword, 'getmininginfo');

    if (blockchainInfo == null) return null;

    return {
      'blocks': blockchainInfo['result']?['blocks'],
      'difficulty': blockchainInfo['result']?['difficulty'],
      'bestblockhash': blockchainInfo['result']?['bestblockhash'],
      'mediantime': blockchainInfo['result']?['mediantime'],
      'version': networkInfo?['result']?['version'],
      'subversion': networkInfo?['result']?['subversion'],
      'connections': networkInfo?['result']?['connections'],
      'mempool_size': mempoolInfo?['result']?['size'],
      'mempool_bytes': mempoolInfo?['result']?['bytes'],
      'networkhashps': miningInfo?['result']?['networkhashps'],
    };
  }

  // Calculate balance from UTXOs
  double calculateBalance(List<Map<String, dynamic>> utxos) {
    return utxos
        .where((u) =>
            u['txid'] != 'pending_marker' && (u['confirmations'] as int) > 0)
        .fold(0.0, (sum, u) => sum + (u['amount'] as double));
  }

  double calculateUnconfirmedBalance(List<Map<String, dynamic>> utxos) {
    return utxos
        .where((u) =>
            u['txid'] != 'pending_marker' && (u['confirmations'] as int) == 0)
        .fold(0.0, (sum, u) => sum + (u['amount'] as double));
  }
}
