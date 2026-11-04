import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
///
/// When the items do not fit the width (most phones) the line scrolls by
/// itself like a ticker: slow, steady, looping without a jump. It pauses while
/// the user touches it (they can still drag it by hand) and stays still when
/// the system asks for reduced motion.
class StatusStrip extends StatefulWidget {
  const StatusStrip({super.key});

  @override
  State<StatusStrip> createState() => _StatusStripState();
}

class _StatusStripState extends State<StatusStrip> with SingleTickerProviderStateMixin {
  /// Ticker speed in logical pixels per second.
  static const double _speed = 26;
  Map<String, dynamic>? _info;
  bool _online = true;
  Timer? _timer;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _copyKey = GlobalKey();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _touching = false;
  bool _reduceMotion = false;
  bool _loop = false;
  Timer? _resume;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resume?.cancel();
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_scroll.hasClients) return;
    final copy = _copyKey.currentContext?.size?.width;
    if (copy == null) return;
    // 16 is the left padding: the line only loops when one copy is wider than the view.
    final needsLoop = copy + 16 > _scroll.position.viewportDimension;
    if (needsLoop != _loop) {
      setState(() => _loop = needsLoop);
      return;
    }
    if (!_loop || _touching || _reduceMotion || dt <= 0 || dt > 0.25) return;
    var next = _scroll.offset + _speed * dt;
    // The second copy is identical, so jumping back one copy width is invisible.
    if (next >= copy) next -= copy;
    if (next > _scroll.position.maxScrollExtent) return;
    _scroll.jumpTo(next);
  }

  void _touchStart() {
    _resume?.cancel();
    _touching = true;
  }

  void _touchEnd() {
    _resume?.cancel();
    _resume = Timer(const Duration(seconds: 2), () => _touching = false);
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

    // One copy of the line: the items with a divider after each, so two copies
    // side by side look like an endless line.
    List<Widget> copy() => [
          for (final item in items) ...[
            item,
            Container(
              width: 1,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: S256Colors.lineStrong,
            ),
          ],
        ];

    return Container(
      width: double.infinity,
      height: 34,
      decoration: const BoxDecoration(
        color: S256Colors.darkBg,
        border: Border(bottom: BorderSide(color: S256Colors.line)),
      ),
      child: Listener(
        onPointerDown: (_) => _touchStart(),
        onPointerUp: (_) => _touchEnd(),
        onPointerCancel: (_) => _touchEnd(),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Row(key: _copyKey, children: copy()),
              if (_loop) Row(children: copy()),
            ],
          ),
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
