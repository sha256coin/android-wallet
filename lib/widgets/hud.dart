import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:s256_wallet/widgets/app_background.dart';

// Shared pieces of the "Digital Platinum" look, the same as the S256 web
// wallet: cards with corner brackets, mono labels and the platinum display
// type (the grid is AppBackground).
// Every animation stops when the system asks for reduced motion.

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A flat card with a hairline border. With [brackets], amber corner marks
/// frame it like a heads-up display; use them for the cards that matter
/// (balance, confirmation, recovery words), not for every card.
class HudCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool brackets;
  final Color? bracketColor;
  final Color? color;
  final Color? borderColor;

  const HudCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.brackets = false,
    this.bracketColor,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? S256Colors.cardBg,
        borderRadius: S256Theme.borderRadius,
        border: Border.all(color: borderColor ?? S256Colors.line),
      ),
      child: child,
    );
    if (!brackets) return card;
    return CustomPaint(
      foregroundPainter: _BracketPainter(bracketColor ?? S256Colors.primary),
      child: card,
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;

  const _BracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const len = 14.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, len)..lineTo(0, 0)..lineTo(len, 0)
      ..moveTo(w - len, 0)..lineTo(w, 0)..lineTo(w, len)
      ..moveTo(w, h - len)..lineTo(w, h)..lineTo(w - len, h)
      ..moveTo(len, h)..lineTo(0, h)..lineTo(0, h - len);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) => oldDelegate.color != color;
}

/// Small uppercase mono label above a section: "// BALANCE".
class HudLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool slashes;

  const HudLabel(this.text, {super.key, this.color = S256Colors.primary, this.slashes = true});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${slashes ? '// ' : ''}${text.toUpperCase()}',
      style: TextStyle(
        fontFamily: S256Theme.mono,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.8,
        color: color,
      ),
    );
  }
}

/// Section title in Chakra Petch with an optional mono label above it.
class HudTitle extends StatelessWidget {
  final String title;
  final String? label;
  final Widget? trailing;

  const HudTitle(this.title, {super.key, this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[HudLabel(label!), const SizedBox(height: 6)],
              Text(
                title,
                style: const TextStyle(
                  fontFamily: S256Theme.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: S256Colors.text,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Display text in brushed platinum with a slow sheen moving across it
/// (the website's hero title).
class PlatinumText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  const PlatinumText(this.text, {super.key, required this.style, this.textAlign});

  @override
  State<PlatinumText> createState() => _PlatinumTextState();
}

class _PlatinumTextState extends State<PlatinumText> with SingleTickerProviderStateMixin {
  late final AnimationController _sheen =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _sheen.stop();
    } else if (!_sheen.isAnimating) {
      _sheen.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sheen,
      builder: (context, child) {
        // The gradient is twice as wide as the text and slides across it.
        final t = Curves.easeInOut.transform(_sheen.value);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: S256Colors.platinum,
            stops: const [0, 0.34, 0.56, 1],
            transform: _SlideGradient(t),
          ).createShader(Rect.fromLTWH(0, 0, bounds.width * 2, bounds.height)),
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style.copyWith(color: Colors.white), textAlign: widget.textAlign),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double t;

  const _SlideGradient(this.t);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(-bounds.width / 2 * t, 0, 0);
}

/// A status dot that pulses softly.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, this.color = S256Colors.success, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: s * (1 + 1.4 * t),
                height: s * (1 + 1.4 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              Container(
                width: s,
                height: s,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The coin logo inside a dashed amber ring that turns slowly.
class CoinStage extends StatefulWidget {
  final double size;

  const CoinStage({super.key, this.size = 200});

  @override
  State<CoinStage> createState() => _CoinStageState();
}

class _CoinStageState extends State<CoinStage> with SingleTickerProviderStateMixin {
  late final AnimationController _turn =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.14,
      height: s * 1.14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _turn,
            child: CustomPaint(size: Size.square(s * 1.14), painter: const _DashedRingPainter()),
          ),
          Container(
            width: s,
            height: s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x47f5a524), blurRadius: 40, offset: Offset(0, 18))],
            ),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 1;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = S256Colors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashes = 64;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * sweep, sweep * 0.5, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => false;
}
