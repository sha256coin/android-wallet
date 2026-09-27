import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s256_wallet/providers/addressbook_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const alice = 's21qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
  const bob = 's21qmxrw6qdh5g3ztfcwm0et5l8mvws4eva20fdh95';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<AddressbookProvider> emptyProvider() async {
    final provider = AddressbookProvider();
    await provider.reloadEntries();
    return provider;
  }

  test('exports and reimports roundtrip payload', () async {
    final provider = await emptyProvider();
    expect(await provider.addOrUpdateEntry(label: 'Cold Storage', address: alice), isNull);

    final exported = provider.exportToS256Json();
    await provider.clearEntries();
    expect(provider.entries, isEmpty);

    final result = await provider.importFromS256Json(exported);
    expect(result['success'], true);
    expect(provider.entries.map((e) => e.label), ['Cold Storage']);
  });

  test('rejects truncated json payloads', () async {
    final provider = await emptyProvider();
    final result = await provider.importFromS256Json(
      '{"version":"1.0","contactCount":1,"contacts":[{"label":"A"',
    );
    expect(result['success'], false);
    expect(provider.entries, isEmpty);
  });

  // Older exports: FilePicker.saveFile did not truncate when saving over a
  // longer file, so the old file's tail follows the new JSON. See MainActivity.kt.
  group('import of exports with leftover bytes', () {
    const export = '{"version":"1.0","network":"s256","exportDate":"2026-09-24T17:17:06.099880",'
        '"contactCount":2,"contacts":['
        '{"label":"miner 4","address":"$alice","addedAt":"2026-09-06T11:06:59.984662"},'
        '{"label":"Bob","address":"$bob","addedAt":"2026-06-17T23:07:18.750032"}]}';
    const leftover = '"label":"Bob","address":"$bob","addedAt":"2026-06-17T23:07:18.750032"}]}';

    test('imports the complete export and ignores the leftovers', () async {
      final provider = await emptyProvider();
      final result = await provider.importFromS256Json(export + leftover);

      expect(result['success'], true);
      expect(result['imported'], 2);
      expect(result['message'], contains('Leftover data'));
      expect(provider.entries.map((e) => e.label).toSet(), {'miner 4', 'Bob'});
    });

    test('refuses leftovers when the contact count does not match', () async {
      final provider = await emptyProvider();
      final wrongCount = export.replaceFirst('"contactCount":2', '"contactCount":7');
      final result = await provider.importFromS256Json(wrongCount + leftover);

      expect(result['success'], false);
      expect(provider.entries, isEmpty);
    });

    test('refuses leftovers when there is no contact count', () async {
      final provider = await emptyProvider();
      final noCount = export.replaceFirst('"contactCount":2,', '');
      final result = await provider.importFromS256Json(noCount + leftover);

      expect(result['success'], false);
      expect(provider.entries, isEmpty);
    });
  });
}
