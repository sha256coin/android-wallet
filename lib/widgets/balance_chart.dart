import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:s256_wallet/widgets/hud.dart';

/// One point of the balance history: the balance right after a transaction.
class BalancePoint {
  final DateTime? time;
  final double balance;

  /// What the transaction changed: positive for coins in, negative for out.
  final double change;

  const BalancePoint({required this.time, required this.balance, required this.change});
}

/// The wallet's balance over its loaded transactions, rebuilt backwards from
/// the confirmed balance: the explorer lists mined transactions only, newest
/// first, and each amount is the net change for this address. (The explorer's
/// own per-transaction "balance" restarts at 0 for every page, so it is not
/// used.)
class BalanceHistory {
  /// Balance before the oldest loaded transaction (0 when the whole history
  /// is loaded and complete).
  final double start;

  /// Oldest first.
  final List<BalancePoint> points;

  /// Confirmed balance plus pending transactions, or null when nothing is
  /// pending.
  final double? pendingTotal;

  const BalanceHistory({required this.start, required this.points, this.pendingTotal});

  /// [newestFirst] are BlockchainProvider.transactions: maps with a signed
  /// net 'amount' and a 'timestamp' in seconds.
  factory BalanceHistory.fromExplorer(
    List<dynamic> newestFirst, {
    required double confirmedBalance,
    double? totalBalance,
  }) {
    final newestFirstPoints = <BalancePoint>[];
    var after = confirmedBalance;
    for (final tx in newestFirst) {
      final change = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final ts = tx['timestamp'];
      newestFirstPoints.add(BalancePoint(
        time: ts is num ? DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000) : null,
        balance: math.max(0, after),
        change: change,
      ));
      after = double.parse((after - change).toStringAsFixed(8));
    }
    final pending = totalBalance != null && (totalBalance - confirmedBalance).abs() >= 1e-8
        ? totalBalance
        : null;
    return BalanceHistory(
      start: math.max(0, after),
      points: newestFirstPoints.reversed.toList(),
      pendingTotal: pending,
    );
  }

  bool get isEmpty => points.isEmpty;

  /// True when every point has a time, so the x axis can be time.
  bool get timed => points.isNotEmpty && points.every((p) => p.time != null);
}

/// Round axis steps: 1, 2 or 5 times a power of ten, about [ticks] of them.
({double min, double max, double step}) niceRange(double lo, double hi, {int ticks = 3}) {
  if (hi < lo) (lo, hi) = (hi, lo);
  var span = hi - lo;
  if (span < 1e-8) span = math.max(hi.abs() * 0.1, 1);
  final raw = span / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [1.0, 2.0, 5.0, 10.0].map((m) => m * mag).firstWhere((s) => s >= raw);
  final min = (lo / step).floor() * step;
  var max = (hi / step).ceil() * step;
  if (max - min < 1e-12) max = min + step;
  return (min: min, max: max, step: step);
}

/// "29.1K", "1.25M", "350": decimals follow the axis step.
String compactAmount(double v, double step) {
  String fixed(double x, double unitStep) {
    final decimals = unitStep >= 1 ? 0 : (-(math.log(unitStep) / math.ln10).floor()).clamp(0, 4);
    return x.toStringAsFixed(decimals);
  }

  if (v.abs() >= 1e6) return '${fixed(v / 1e6, step / 1e6)}M';
  if (v.abs() >= 1e4) return '${fixed(v / 1e3, step / 1e3)}K';
  return fixed(v, step);
}

/// Stepped balance chart with round gridlines, in/out markers and a touch
/// readout.
class BalanceChart extends StatefulWidget {
  final BalanceHistory history;
  final double height;

  const BalanceChart({super.key, required this.history, this.height = 160});

  @override
  State<BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<BalanceChart> {
  int? _hover;

  static const _axisWidth = 52.0;
  static const _bottom = 22.0;

  @override
  Widget build(BuildContext context) {
    final h = widget.history;
    if (h.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const HudLabel('Balance history', color: S256Colors.textLight),
            const Spacer(),
            Text(
              'LAST ${h.points.length} TX',
              style: const TextStyle(fontFamily: S256Theme.mono, fontSize: 10.5, letterSpacing: 1.2, color: S256Colors.textLight),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(builder: (context, constraints) {
            final layout = _ChartLayout(h, Size(constraints.maxWidth, widget.height), _axisWidth, _bottom);
            void pick(Offset local) {
              final i = layout.nearest(local.dx);
              if (i != _hover) setState(() => _hover = i);
            }

            // Taps and sideways drags only, so a vertical swipe that starts
            // on the chart still scrolls the page.
            return GestureDetector(
                onTapDown: (d) => pick(d.localPosition),
                onTapUp: (_) => Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _hover = null);
                }),
                onHorizontalDragDown: (d) => pick(d.localPosition),
                onHorizontalDragUpdate: (d) => pick(d.localPosition),
                onHorizontalDragEnd: (_) => setState(() => _hover = null),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _ChartPainter(layout, _hover))),
                    if (_hover != null) _tooltip(layout, _hover!, constraints.maxWidth),
                  ],
                ),
            );
          }),
        ),
      ],
    );
  }

  Widget _tooltip(_ChartLayout layout, int i, double width) {
    final p = widget.history.points[i];
    final at = layout.pointOffset(i);
    const boxWidth = 168.0;
    final left = (at.dx + 12 + boxWidth > width) ? at.dx - 12 - boxWidth : at.dx + 12;
    final change = p.change;
    return Positioned(
      left: left,
      top: 0,
      child: IgnorePointer(
        child: Container(
          width: boxWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: S256Colors.surface2,
            borderRadius: S256Theme.borderRadius,
            border: Border.all(color: S256Colors.lineStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.time == null ? 'TX ${i + 1}' : DateFormat('d MMM yyyy · HH:mm').format(p.time!).toUpperCase(),
                style: const TextStyle(fontFamily: S256Theme.mono, fontSize: 10, letterSpacing: 0.8, color: S256Colors.textLight),
              ),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat('#,##0.00', 'en_US').format(p.balance)} S256',
                style: const TextStyle(fontFamily: S256Theme.mono, fontSize: 13, fontWeight: FontWeight.w500, color: S256Colors.text),
              ),
              if (change != 0)
                Text(
                  '${change > 0 ? '+' : '−'}${NumberFormat('#,##0.########', 'en_US').format(change.abs())}',
                  style: TextStyle(
                    fontFamily: S256Theme.mono,
                    fontSize: 11,
                    color: change > 0 ? S256Colors.success : S256Colors.danger,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where everything goes: x by time when every point has one, else by order.
class _ChartLayout {
  final BalanceHistory h;
  final Size size;
  final double axisWidth;
  final double bottom;
  late final Rect plot;
  late final ({double min, double max, double step}) y;
  late final double _x0, _x1;
  late final List<double> _xs;

  _ChartLayout(this.h, this.size, this.axisWidth, this.bottom) {
    plot = Rect.fromLTRB(axisWidth, 6, size.width - 6, size.height - bottom);
    final values = [h.start, ...h.points.map((p) => p.balance), if (h.pendingTotal != null) h.pendingTotal!];
    y = niceRange(values.reduce(math.min), values.reduce(math.max));

    if (h.timed) {
      final times = h.points.map((p) => p.time!.millisecondsSinceEpoch.toDouble()).toList();
      final end = math.max(times.last, DateTime.now().millisecondsSinceEpoch.toDouble());
      var span = end - times.first;
      if (span <= 0) span = 3600 * 1000;
      _x0 = times.first - span * 0.04; // room for the balance before the first tx
      _x1 = end;
      _xs = times;
    } else {
      _x0 = -0.5;
      _x1 = h.points.length.toDouble();
      _xs = [for (var i = 0; i < h.points.length; i++) i.toDouble()];
    }
  }

  double xAt(double v) => plot.left + (v - _x0) / (_x1 - _x0) * plot.width;
  double yAt(double v) => plot.bottom - (v - y.min) / (y.max - y.min) * plot.height;

  Offset pointOffset(int i) => Offset(xAt(_xs[i]), yAt(h.points[i].balance));

  int nearest(double dx) {
    var best = 0;
    for (var i = 1; i < _xs.length; i++) {
      if ((xAt(_xs[i]) - dx).abs() < (xAt(_xs[best]) - dx).abs()) best = i;
    }
    return best;
  }

  String xLabel(bool first) {
    if (!h.timed) return first ? 'OLDEST' : 'NOW';
    final t = first ? h.points.first.time! : DateTime.now();
    return DateFormat('d MMM yy').format(t).toUpperCase();
  }
}

class _ChartPainter extends CustomPainter {
  final _ChartLayout l;
  final int? hover;

  _ChartPainter(this.l, this.hover);

  static const _labelStyle = TextStyle(fontFamily: S256Theme.mono, fontSize: 10, color: S256Colors.textLight);

  void _text(Canvas canvas, String s, Offset at, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(text: TextSpan(text: s, style: _labelStyle), textDirection: TextDirection.ltr)..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = l.plot;
    final h = l.h;

    // Round gridlines with their values on the left.
    final grid = Paint()..color = S256Colors.line..strokeWidth = 1;
    for (var v = l.y.min; v <= l.y.max + l.y.step / 2; v += l.y.step) {
      final yy = l.yAt(v);
      for (var x = plot.left; x < plot.right; x += 6) {
        canvas.drawLine(Offset(x, yy), Offset(math.min(x + 3, plot.right), yy), grid);
      }
      _text(canvas, compactAmount(v, l.y.step), Offset(plot.left - 8, yy), align: TextAlign.right);
    }
    _text(canvas, l.xLabel(true), Offset(plot.left, size.height - 8));
    _text(canvas, l.xLabel(false), Offset(plot.right, size.height - 8), align: TextAlign.right);

    // Stepped line: the balance holds until the next transaction.
    final path = Path()..moveTo(plot.left, l.yAt(h.start));
    var prev = h.start;
    for (var i = 0; i < h.points.length; i++) {
      final p = l.pointOffset(i);
      path
        ..lineTo(p.dx, l.yAt(prev))
        ..lineTo(p.dx, p.dy);
      prev = h.points[i].balance;
    }
    final endY = l.yAt(h.points.last.balance);
    path.lineTo(plot.right, endY);

    final fill = Path.from(path)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [S256Colors.primary.withValues(alpha: 0.20), S256Colors.primary.withValues(alpha: 0)],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = S256Colors.primary
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter,
    );

    // Pending: a dashed step at the right edge up (or down) to the total.
    if (h.pendingTotal != null) {
      final to = l.yAt(h.pendingTotal!);
      final dash = Paint()..color = S256Colors.accent..strokeWidth = 1.6;
      final dir = to < endY ? -1 : 1;
      for (var yy = endY; dir < 0 ? yy > to : yy < to; yy += dir * 6) {
        final next = dir < 0 ? math.max(yy - 3, to) : math.min(yy + 3, to);
        canvas.drawLine(Offset(plot.right, yy), Offset(plot.right, next), dash);
      }
      canvas.drawRect(Rect.fromCenter(center: Offset(plot.right, to), width: 6, height: 6), Paint()..color = S256Colors.accent);
    }

    // Markers: green for coins in, red for out; the hovered one larger.
    for (var i = 0; i < h.points.length; i++) {
      final p = l.pointOffset(i);
      final c = h.points[i].change;
      final color = c > 0 ? S256Colors.success : c < 0 ? S256Colors.danger : S256Colors.textLight;
      final s = i == hover ? 8.0 : 5.0;
      canvas.drawRect(Rect.fromCenter(center: p, width: s, height: s), Paint()..color = S256Colors.darkBg);
      canvas.drawRect(
        Rect.fromCenter(center: p, width: s, height: s),
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5,
      );
    }

    // Crosshair on the hovered point.
    if (hover != null) {
      final p = l.pointOffset(hover!);
      final cross = Paint()..color = S256Colors.lineStrong..strokeWidth = 1;
      canvas.drawLine(Offset(p.dx, plot.top), Offset(p.dx, plot.bottom), cross);
      canvas.drawLine(Offset(plot.left, p.dy), Offset(plot.right, p.dy), cross);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.hover != hover || old.l.h != l.h || old.l.size != l.size;
}
