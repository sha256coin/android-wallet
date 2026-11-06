import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:s256_wallet/config.dart';
import 'package:s256_wallet/widgets/app_background.dart';

/// Coinbase (mining reward) outputs can only be spent after this many blocks.
const int _coinbaseMaturity = 100;

class TransactionModal extends StatefulWidget {
  final String txid;

  /// Unix time in seconds from the transaction list. Used when the explorer
  /// has no time for the transaction (for example while it is still pending).
  final int? timestamp;

  const TransactionModal({super.key, required this.txid, this.timestamp});

  @override
  State<TransactionModal> createState() => _TransactionModalState();
}

class _TransactionModalState extends State<TransactionModal> {
  Map<String, dynamic>? _tx;
  int? _tipHeight;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txUrl = '${Config.explorerUrl}${Config.getTxEndpoint}/${widget.txid}';
    final tipUrl = '${Config.explorerUrl}/api/blockchain-info';

    // The tip height is optional: without it we fall back to the stored
    // confirmation count, so a failure there must not fail the whole sheet.
    final tipFuture = http
        .get(Uri.parse(tipUrl))
        .timeout(const Duration(seconds: 10))
        .then<int?>((r) => r.statusCode == 200
            ? (jsonDecode(r.body)['blocks'] as num?)?.toInt()
            : null)
        .catchError((_) => null);

    try {
      final response = await http
          .get(Uri.parse(txUrl))
          .timeout(const Duration(seconds: 15));
      final tip = await tipFuture;
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _tx = jsonDecode(response.body)['tx'] as Map<String, dynamic>?;
          _tipHeight = tip;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// Confirmations from the live chain tip, else the stored count, else 0.
  int get _confirmations {
    final tx = _tx;
    if (tx == null) return 0;
    final height = (tx['blockheight'] as num?)?.toInt();
    if (height != null && _tipHeight != null) {
      final c = _tipHeight! - height + 1;
      return c < 0 ? 0 : c;
    }
    return (tx['confirmations'] as num?)?.toInt() ?? (height != null ? 1 : 0);
  }

  bool get _isCoinbase {
    final vin = _tx?['vin'];
    return vin is List && vin.isNotEmpty && vin.first['coinbase'] != null;
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what copied'),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(2),
        topRight: Radius.circular(2),
      ),
      child: Container(
        color: S256Colors.darkBg,
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: S256Colors.textLight,
                ),
              ),
              const SizedBox(height: 16),
              // The txid is known before anything loads, so it can always be
              // copied, even when the explorer has no record yet (pending).
              _txidRow(),
              const SizedBox(height: 8),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: S256Colors.accent)),
                )
              else if (_hasError || _tx == null)
                _pendingOrError()
              else
                ..._details(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _txidRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TXID', style: TextStyle(color: S256Colors.text)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.txid,
            style: const TextStyle(
                color: S256Colors.text, fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        InkWell(
          onTap: () => _copy(widget.txid, 'Transaction ID'),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy, size: 20, color: S256Colors.accent),
          ),
        ),
      ],
    );
  }

  Widget _pendingOrError() {
    final ts = widget.timestamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip('Waiting for the explorer', S256Colors.accent),
        const SizedBox(height: 12),
        if (ts != null) _buildDetailRow('Date', _formatDate(ts)),
        const Text(
          'The explorer has no details for this transaction yet. A new '
          'transaction can take a moment to appear. Close this and tap it '
          'again in a minute.',
          style: TextStyle(color: S256Colors.textLight),
        ),
      ],
    );
  }

  List<Widget> _details() {
    final tx = _tx!;
    final conf = _confirmations;
    final height = (tx['blockheight'] as num?)?.toInt();
    final time = (tx['time'] as num?)?.toInt() ?? widget.timestamp;
    final vin = (tx['vin'] as List?) ?? const [];
    final vout = (tx['vout'] as List?) ?? const [];
    final fee = _fee(vin, vout);

    final String statusText;
    final Color statusColor;
    if (conf <= 0) {
      statusText = 'Pending · 0 confirmations';
      statusColor = S256Colors.accent;
    } else {
      statusText = 'Confirmed · $conf ${conf == 1 ? 'confirmation' : 'confirmations'}';
      statusColor = S256Colors.success;
    }

    return [
      _statusChip(statusText, statusColor),
      if (_isCoinbase && conf < _coinbaseMaturity) ...[
        const SizedBox(height: 8),
        Text(
          'Mining reward: spendable after $_coinbaseMaturity confirmations '
          '(${_coinbaseMaturity - conf} to go).',
          style: const TextStyle(color: S256Colors.textLight, fontSize: 13),
        ),
      ],
      const SizedBox(height: 12),
      if (time != null) _buildDetailRow('Date', _formatDate(time)),
      if (height != null) _buildDetailRow('Block', '#$height'),
      _buildDetailRow('Total', '${_formatAmount(tx['total'])} S256'),
      if (fee != null) _buildDetailRow('Fee', '${_formatAmount(fee)} S256'),
      const SizedBox(height: 16),
      const Text('Input:',
          style: TextStyle(fontWeight: FontWeight.bold, color: S256Colors.text)),
      const SizedBox(height: 4),
      ...vin.map((v) => _ioRow(v['amount'], v['addresses'])),
      const SizedBox(height: 16),
      const Text('Output:',
          style: TextStyle(fontWeight: FontWeight.bold, color: S256Colors.text)),
      const SizedBox(height: 4),
      ...vout.map((v) => _ioRow(v['amount'], v['addresses'])),
    ];
  }

  /// Fee = inputs - outputs. Only shown when every input amount is known, and
  /// never for a coinbase (it creates coins, it does not pay a fee).
  int? _fee(List vin, List vout) {
    if (_isCoinbase || vin.isEmpty) return null;
    var inSum = 0;
    for (final v in vin) {
      final a = (v['amount'] as num?)?.toInt() ?? 0;
      if (a <= 0) return null;
      inSum += a;
    }
    final outSum =
        vout.fold<int>(0, (s, v) => s + ((v['amount'] as num?)?.toInt() ?? 0));
    final fee = inSum - outSum;
    return fee >= 0 ? fee : null;
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  /// An input or output line: amount, then the address (tap to copy).
  Widget _ioRow(dynamic amount, dynamic address) {
    final addr = (address ?? 'Unknown').toString();
    final copyable = RegExp(r'^[A-Za-z0-9]{20,}$').hasMatch(addr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: copyable ? () => _copy(addr, 'Address') : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatAmount(amount),
                style: const TextStyle(color: S256Colors.text)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(addr, style: const TextStyle(color: S256Colors.text)),
            ),
            if (copyable)
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 2),
                child: Icon(Icons.copy, size: 14, color: S256Colors.textLight),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: S256Colors.text)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: S256Colors.text)),
          ),
        ],
      ),
    );
  }

  String _formatDate(int seconds) => DateFormat('dd MMM yyyy HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));

  String _formatAmount(dynamic amount) {
    final sats = (amount as num?)?.toInt() ?? 0;
    return (sats / 100000000).toStringAsFixed(8);
  }
}
