import 'package:flutter_test/flutter_test.dart';
import 'package:s256_wallet/services/wallet_service.dart';
import 'dart:typed_data';
import 'package:hex/hex.dart';

void main() {
  final WalletService walletService = WalletService();

  group('WalletService BIP39 Tests', () {
    test('generateMnemonic produces a valid 12-word phrase', () {
      final mnemonic = walletService.generateMnemonic(strength: 128);
      expect(mnemonic.split(' ').length, 12);
      expect(walletService.validateMnemonic(mnemonic), isTrue);
    });

    test('generateMnemonic produces a valid 24-word phrase', () {
      final mnemonic = walletService.generateMnemonic(strength: 256);
      expect(mnemonic.split(' ').length, 24);
      expect(walletService.validateMnemonic(mnemonic), isTrue);
    });

    test('derivePrivateKeyFromMnemonic produces consistent results', () {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final privateKey = walletService.derivePrivateKeyFromMnemonic(mnemonic);
      
      final hexPrivKey = HEX.encode(privateKey);
      
      // Values derived from m/44'/0'/0'/0/0 and 'abandon...' (12 words) in S256 Mobile
      expect(hexPrivKey, 'e284129cc0922579a535bbf4d1a3b25773090d28c909bc0fed73b5e0222cc372');
    });

    test('getWifFromPrivateKey produces correct WIF for S256 network', () {
      final privateKey = Uint8List.fromList(HEX.decode('e284129cc0922579a535bbf4d1a3b25773090d28c909bc0fed73b5e0222cc372'));
      final wif = walletService.getWifFromPrivateKey(privateKey);
      
      // Prefix 0xBF (191) -> Base58 starts with 'V' for this specific key
      expect(wif, startsWith('V'));
      expect(wif, 'VPLkcKBqgpTjy5R65nATTSxFS42KmCRU5xTRt2Yw6yLEuAx8pfek');
    });

    test('loadAddressFromKey produces correct s21... address', () {
      final privateKey = Uint8List.fromList(HEX.decode('e284129cc0922579a535bbf4d1a3b25773090d28c909bc0fed73b5e0222cc372'));
      final wif = walletService.getWifFromPrivateKey(privateKey);
      final address = walletService.loadAddressFromKey(wif);
      
      expect(address, startsWith('s21'));
      // For this specific key, address is:
      expect(address, 's21qmxrw6qdh5g3ztfcwm0et5l8mvws4eva20fdh95');
    });
  });
}
