import 'package:flutter_test/flutter_test.dart';
import 'package:s256_wallet/services/s256_signer.dart';

void main() {
  group('S256Signer', () {
    test('scriptFromAddress returns native segwit script for s2/s21 address', () {
      const address = 's21qmxrw6qdh5g3ztfcwm0et5l8mvws4eva20fdh95';

      final script = S256Signer.scriptFromAddress(address);

      expect(script.length, 22); // OP_0 + PUSH20 + 20-byte-hash
      expect(script[0], 0x00);
      expect(script[1], 0x14);
    });

    test('signTransaction returns segwit tx and serializes output value', () {
      const wif = 'VPLkcKBqgpTjy5R65nATTSxFS42KmCRU5xTRt2Yw6yLEuAx8pfek';
      const address = 's21qmxrw6qdh5g3ztfcwm0et5l8mvws4eva20fdh95';

      final inputScript = S256Signer.scriptFromAddress(address);
      final outputScript = S256Signer.scriptFromAddress(address);

      final txHex = S256Signer.signTransaction(
        wif: wif,
        inputs: [
          S256TxInput(
            txid: List.filled(64, '0').join(),
            vout: 1,
            scriptPubKey: inputScript,
            satoshis: 100000,
          ),
        ],
        outputs: [
          S256TxOutput(
            scriptPubKey: outputScript,
            satoshis: 50000,
          ),
        ],
      );

      expect(txHex, startsWith('010000000001'));
      expect(txHex, endsWith('00000000'));

      // 50000 sats in LE uint64 -> 50 c3 00 00 00 00 00 00
      expect(txHex.contains('50c3000000000000'), isTrue);
    });

    test('scriptFromAddress throws on unsupported address', () {
      expect(
        () => S256Signer.scriptFromAddress('not-a-valid-address'),
        throwsException,
      );
    });
  });
}
