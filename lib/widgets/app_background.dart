import 'package:flutter/material.dart';

// S256 "Digital Platinum" colours, taken from sha256coin.eu (theme.css).
// Contrast on the card colour: text 15:1, textLight 6.7:1, amber 8.6:1;
// onPrimary on amber 9:1 (all above the 4.5:1 AA minimum).
class S256Colors {
  static const primary = Color(0xFFf5a524);      // Amber (coin logo)
  static const accent = Color(0xFFffbf55);       // Light amber, highlights
  static const secondary = Color(0xFFffbf55);
  static const onPrimary = Color(0xFF1a1206);    // Text on amber
  static const darkBg = Color(0xFF0c0e11);       // Graphite ground
  static const cardBg = Color(0xFF13161b);       // Card
  static const surface2 = Color(0xFF1a1e25);     // Raised surface, inputs
  static const text = Color(0xFFe7ebf1);
  static const textLight = Color(0xFF98a1b0);    // Secondary text
  static const line = Color(0x17d6deeb);         // Hairline, 9%
  static const lineStrong = Color(0x2ed6deeb);   // Stronger hairline, 18%
  static const danger = Color(0xFFff6b6b);

  static const gradient = LinearGradient(
    colors: [Color(0xFFf7b53b), Color(0xFFe58b0f)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientGold = gradient;
}

/// Graphite ground with a faint grid, like the website's hero.
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showGradient;
  final bool enableAccent;

  const AppBackground({
    super.key,
    required this.child,
    this.showGradient = true,
    this.enableAccent = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: S256Colors.darkBg,
      child: enableAccent
          ? Stack(
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(child: CustomPaint(painter: S256ShimmerPainter())),
                ),
                child,
              ],
            )
          : child,
    );
  }
}

// Name kept from the old glow painter; it now draws the faint grid.
class S256ShimmerPainter extends CustomPainter {
  const S256ShimmerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0ad6deeb)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class S256AccentGradient extends StatelessWidget {
  final Widget child;
  final double intensity;

  const S256AccentGradient({
    super.key,
    required this.child,
    this.intensity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            S256Colors.primary.withValues(alpha: intensity),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

/// Flat square card with a hairline border. [title] adds the small uppercase
/// label the cards on the website carry.
class SilverCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enableShimmer;
  final String? title;

  const SilverCard({
    super.key,
    required this.child,
    this.padding,
    this.enableShimmer = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: S256Colors.cardBg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: S256Colors.line, width: 1),
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'ChakraPetch',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: S256Colors.textLight,
                  ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
    );
  }
}

/// Square card with an amber edge (was an animated gradient border).
class SilverBorder extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final BorderRadius? borderRadius;

  const SilverBorder({
    super.key,
    required this.child,
    this.borderWidth = 2,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: S256Colors.darkBg,
        borderRadius: borderRadius ?? BorderRadius.circular(2),
        border: Border.all(color: S256Colors.primary, width: borderWidth / 2),
      ),
      child: child,
    );
  }
}
