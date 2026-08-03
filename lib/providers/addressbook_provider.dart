import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s256_wallet/models/addressbook_entry.dart';

class AddressbookProvider with ChangeNotifier {
  static const String _storageKey = 'addressbook_entries_v1';
  static const int maxImportEntries = 5000;
  static const int maxLabelLength = 64;
  static const int maxAddressLength = 128;

  static final RegExp _legacyAddressRegex =
      RegExp(r'^[S8][1-9A-HJ-NP-Za-km-z]{24,49}$');
  static final RegExp _bech32AddressRegex = RegExp(r'^s21[ac-hj-np-z02-9]{39,59}$');

  final List<AddressbookEntry> _entries = [];
  bool _isLoading = false;
  Future<void>? _inFlightLoad;

  List<AddressbookEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;

  AddressbookProvider() {
    loadEntries();
  }

  Future<void> reloadEntries() => loadEntries();

  Future<void> loadEntries() async {
    if (_inFlightLoad != null) {
      return _inFlightLoad!;
    }

    final loadFuture = _loadEntriesInternal();
    _inFlightLoad = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_inFlightLoad, loadFuture)) {
        _inFlightLoad = null;
      }
    }
  }

  Future<void> _loadEntriesInternal() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data == null || data.isEmpty) {
        _entries.clear();
        return;
      }

      final decoded = jsonDecode(data);
      if (decoded is! List) {
        _entries.clear();
        return;
      }

      _entries
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .map(AddressbookEntry.fromJson)
              .where((e) => e.label.isNotEmpty && e.address.isNotEmpty),
        );
    } catch (_) {
      _entries.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  String _normalizeAddressForMatch(String address) {
    final trimmed = address.trim();
    final lower = trimmed.toLowerCase();
    return lower.startsWith('s21') ? lower : trimmed;
  }

  bool _isValidAddressFormat(String address) {
    final trimmed = address.trim();
    final lower = trimmed.toLowerCase();
    return _legacyAddressRegex.hasMatch(trimmed) ||
        _bech32AddressRegex.hasMatch(lower);
  }

  bool _isValidLabelFormat(String label) {
    final trimmed = label.trim();
    return trimmed.isNotEmpty && trimmed.length <= maxLabelLength;
  }

  bool _isValidAddressLength(String address) {
    final trimmed = address.trim();
    return trimmed.isNotEmpty && trimmed.length <= maxAddressLength;
  }

  Future<String?> addOrUpdateEntry({
    required String label,
    required String address,
    String? originalAddress,
  }) async {
    final cleanLabel = label.trim();
    final cleanAddress = address.trim();

    if (cleanLabel.isEmpty || cleanAddress.isEmpty) {
      return 'Label and address are required.';
    }

    if (!_isValidLabelFormat(cleanLabel)) {
      return 'Label is too long (max $maxLabelLength characters).';
    }

    if (!_isValidAddressLength(cleanAddress)) {
      return 'Address is too long (max $maxAddressLength characters).';
    }

    if (!_isValidAddressFormat(cleanAddress)) {
      return 'Address format is invalid.';
    }

    final normalizedCleanAddress = _normalizeAddressForMatch(cleanAddress);

    final existingByAddress = _entries.indexWhere(
      (e) => _normalizeAddressForMatch(e.address) == normalizedCleanAddress,
    );

    if (existingByAddress != -1 &&
        (originalAddress == null ||
            _normalizeAddressForMatch(_entries[existingByAddress].address) !=
                _normalizeAddressForMatch(originalAddress))) {
      return 'This address is already saved.';
    }

    if (originalAddress != null && originalAddress.trim().isNotEmpty) {
      final existingIndex = _entries.indexWhere(
        (e) =>
            _normalizeAddressForMatch(e.address) ==
            _normalizeAddressForMatch(originalAddress),
      );
      if (existingIndex != -1) {
        _entries[existingIndex] = _entries[existingIndex].copyWith(
          label: cleanLabel,
          address: cleanAddress,
        );
      } else {
        _entries.insert(
          0,
          AddressbookEntry(
            label: cleanLabel,
            address: cleanAddress,
            createdAt: DateTime.now(),
          ),
        );
      }
    } else {
      _entries.insert(
        0,
        AddressbookEntry(
          label: cleanLabel,
          address: cleanAddress,
          createdAt: DateTime.now(),
        ),
      );
    }

    await _persistEntries();
    notifyListeners();
    return null;
  }

  Future<void> removeEntry(String address) async {
    final normalizedAddress = _normalizeAddressForMatch(address);
    _entries.removeWhere(
      (e) => _normalizeAddressForMatch(e.address) == normalizedAddress,
    );
    await _persistEntries();
    notifyListeners();
  }

  Future<void> clearEntries() async {
    _entries.clear();
    await _persistEntries();
    notifyListeners();
  }

  String exportToS256Json() {
    final contacts = _entries
        .map(
          (e) => <String, dynamic>{
            'label': e.label,
            'address': e.address,
            'addedAt': e.createdAt.toIso8601String(),
          },
        )
        .toList();

    return jsonEncode(<String, dynamic>{
      'version': '1.0',
      'network': 's256',
      'exportDate': DateTime.now().toIso8601String(),
      'contactCount': contacts.length,
      'contacts': contacts,
    });
  }

  // Debug-compatible alias.
  String exportToBtcsJson() => exportToS256Json();

  Future<Map<String, dynamic>> importFromS256Json(String jsonString) async {
    try {
      final sanitized = jsonString
          .replaceAll('\u0000', '')
          .replaceFirst(RegExp(r'^\uFEFF'), '')
          .trim();

      final decoded = jsonDecode(sanitized);

      if (decoded is! Map) {
        return {
          'success': false,
          'message': 'Invalid file format.',
        };
      }

      final decodedMap = Map<String, dynamic>.from(decoded);
      final rawEntries = decodedMap['contacts'];

      if (rawEntries is! List) {
        return {
          'success': false,
          'message': 'Invalid format. Contacts must be a list.',
        };
      }

      if (rawEntries.length > maxImportEntries) {
        return {
          'success': false,
          'message': 'File contains too many entries (max $maxImportEntries).',
        };
      }

      int imported = 0;
      int skipped = 0;

      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map) {
          skipped++;
          continue;
        }

        final map = Map<String, dynamic>.from(rawEntry);
        final label =
            (map['label'] ?? map['username'] ?? '').toString().trim();
        final address = (map['address'] ?? '').toString().trim();

        if (label.isEmpty || address.isEmpty) {
          skipped++;
          continue;
        }

        final error = await addOrUpdateEntry(label: label, address: address);
        if (error == null) {
          imported++;
        } else {
          skipped++;
        }
      }

      return {
        'success': true,
        'imported': imported,
        'skipped': skipped,
        'message': 'Imported $imported contacts${skipped > 0 ? ' ($skipped skipped)' : ''}.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not parse file. Ensure it is valid JSON.',
      };
    }
  }

  // Debug-compatible alias.
  Future<Map<String, dynamic>> importFromBtcsJson(String jsonString) =>
      importFromS256Json(jsonString);
}
