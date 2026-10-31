import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/models/price_info.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:s256_wallet/widgets/hud.dart';

/// "12.34 PH/s"
String formatHashrate(dynamic hashrate) {
  if (hashrate == null) return 'N/A';
  final rate = (hashrate as num).toDouble();
  if (rate > 1e18) return '${(rate / 1e18).toStringAsFixed(2)} EH/s';
  if (rate > 1e15) return '${(rate / 1e15).toStringAsFixed(2)} PH/s';
  if (rate > 1e12) return '${(rate / 1e12).toStringAsFixed(2)} TH/s';
  if (rate > 1e9) return '${(rate / 1e9).toStringAsFixed(2)} GH/s';
  if (rate > 1e6) return '${(rate / 1e6).toStringAsFixed(2)} MH/s';
  if (rate > 1e3) return '${(rate / 1e3).toStringAsFixed(2)} KH/s';
  return '${rate.toStringAsFixed(2)} H/s';
}

/// Live network line along the top of the wallet: connection, block height,
/// hashrate, peers and price, as in the S256 web wallet. Reads the node every
/// two minutes; a failed read marks the connection amber and keeps the last
/// values.
class StatusStrip extends StatefulWidget {
  const StatusStrip({super.key});

  @override
  State<StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<StatusStrip> {
  Map<String, dynamic>? _info;
  bool _online = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    Map<String, dynamic>? info;
    try {
      info = await context.read<WalletProvider>().getNetworkInfo();
    } catch (_) {
      info = null;
    }
    if (!mounted) return;
    setState(() {
      _online = info != null;
      _info = info ?? _info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final price = context.watch<BlockchainProvider>().priceInfo;
    final blocks = _info?['blocks'];
    final peers = _info?['connections'];

    final items = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(color: _online ? S256Colors.success : S256Colors.primary, size: 7),
          const SizedBox(width: 4),
          _value(_online ? 'MAINNET' : 'NODE UNREACHABLE',
              color: _online ? S256Colors.text : S256Colors.primary),
        ],
      ),
      _item('BLOCK', blocks is num ? NumberFormat.decimalPattern('en_US').format(blocks) : '—'),
      _item('HASHRATE', _info == null ? '—' : formatHashrate(_info!['networkhashps'])),
      _item('PEERS', peers is num ? '$peers' : '—'),
      _item(
        'S256',
        !price.hasPrice
            ? '—'
            : '${PriceInfo.formatUsd(price.price!)}${price.isLastTrade ? ' · LAST TRADED' : ''}',
      ),
    ];

    return Container(
      width: double.infinity,
      height: 34,
      decoration: const BoxDecoration(
        color: S256Colors.darkBg,
        border: Border(bottom: BorderSide(color: S256Colors.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: S256Colors.lineStrong,
                ),
              items[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(String label, String value, {Color color = S256Colors.text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: S256Theme.mono,
            fontSize: 10.5,
            letterSpacing: 1.4,
            color: S256Colors.textLight,
          ),
        ),
        const SizedBox(width: 8),
        _value(value, color: color),
      ],
    );
  }

  Widget _value(String text, {Color color = S256Colors.text}) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: S256Theme.mono,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }
}
