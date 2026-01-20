import 'package:flutter/material.dart';

// S256 Brand Colors
class S256Colors {
  static const primary = Color(0xFFa300ff);      // Purple
  static const secondary = Color(0xFFffd700);    // Gold
  static const accent = Color(0xFF00d4ff);       // Cyan
  static const darkBg = Color(0xFF0b0f14);       // Dark background
  static const cardBg = Color(0xFF1a1f2e);       // Card background
  static const textLight = Color(0xFF9ca3af);    // Light text

  static const gradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientGold = LinearGradient(
    colors: [secondary, Color(0xFFffa500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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
      decoration: BoxDecoration(
        color: S256Colors.darkBg,
        gradient: showGradient
            ? const LinearGradient(
          colors: [
            Color(0xFF151a24),
            Color(0xFF0f1318),
            Color(0xFF0b0f14),
            Color(0xFF080a0d),
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
            : null,
        image: !showGradient
            ? DecorationImage(
          image: const AssetImage("assets/background.jpg"),
          fit: BoxFit.cover,
          colorFilter: enableAccent
              ? ColorFilter.mode(
            S256Colors.primary.withValues(alpha: 0.05),
            BlendMode.lighten,
          )
              : null,
        )
            : null,
      ),
      child: enableAccent
          ? Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: S256ShimmerPainter(),
            ),
          ),
          child,
        ],
      )
          : child,
    );
  }
}

// Custom painter for S256 purple-cyan shimmer effect
class S256ShimmerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top center purple glow
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          S256Colors.primary.withValues(alpha: 0.15),
          S256Colors.primary.withValues(alpha: 0.08),
          S256Colors.primary.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.5, 0),
        radius: size.width * 0.7,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.5, 0),
      size.width * 0.7,
      paint,
    );

    // Top left purple accent
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          S256Colors.primary.withValues(alpha: 0.12),
          S256Colors.primary.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(0, size.height * 0.2),
        radius: size.width * 0.4,
      ));

    canvas.drawCircle(
      Offset(0, size.height * 0.2),
      size.width * 0.4,
      paint2,
    );

    // Top right cyan accent
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          S256Colors.accent.withValues(alpha: 0.1),
          S256Colors.accent.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width, size.height * 0.15),
        radius: size.width * 0.5,
      ));

    canvas.drawCircle(
      Offset(size.width, size.height * 0.15),
      size.width * 0.5,
      paint3,
    );

    // Bottom gold accent (subtle)
    final paint4 = Paint()
      ..shader = RadialGradient(
        colors: [
          S256Colors.secondary.withValues(alpha: 0.06),
          S256Colors.secondary.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.3, size.height),
        radius: size.width * 0.4,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height),
      size.width * 0.4,
      paint4,
    );
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
            S256Colors.accent.withValues(alpha: intensity * 0.5),
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

// S256-themed card decoration
class SilverCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enableShimmer;

  const SilverCard({
    super.key,
    required this.child,
    this.padding,
    this.enableShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            S256Colors.cardBg,
            Color.fromRGBO(S256Colors.cardBg.r.toInt(), S256Colors.cardBg.g.toInt(), (S256Colors.cardBg.b * 255 + 10).toInt().clamp(0, 255), 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: S256Colors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: S256Colors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: enableShimmer
          ? ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.8),
            S256Colors.accent,
            Colors.white.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
        child: child,
      )
          : child,
    );
  }
}

// S256-themed animated border
class SilverBorder extends StatefulWidget {
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
  State<SilverBorder> createState() => _SilverBorderState();
}

class _SilverBorderState extends State<SilverBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: SweepGradient(
              colors: [
                S256Colors.primary.withValues(alpha: 0.8),
                S256Colors.accent.withValues(alpha: 0.6),
                S256Colors.secondary.withValues(alpha: 0.5),
                S256Colors.accent.withValues(alpha: 0.6),
                S256Colors.primary.withValues(alpha: 0.8),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              transform: GradientRotation(_controller.value * 2 * 3.14159),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.borderWidth),
            child: Container(
              decoration: BoxDecoration(
                color: S256Colors.darkBg,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
