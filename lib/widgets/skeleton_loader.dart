import 'package:flutter/material.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? S256Theme.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                S256Colors.cardBg,
                S256Colors.surface2,
                S256Colors.cardBg,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

class WalletBalanceSkeleton extends StatelessWidget {
  const WalletBalanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // USD Value skeleton
        SkeletonLoader(
          width: 120,
          height: 20,
          borderRadius: S256Theme.borderRadius,
        ),
        const SizedBox(height: 8),
        // S256 Balance skeleton
        SkeletonLoader(
          width: 200,
          height: 36,
          borderRadius: S256Theme.borderRadius,
        ),
        const SizedBox(height: 30),
        // Chart skeleton
        Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: S256Colors.darkBg.withValues(alpha: 0.2),
            borderRadius: S256Theme.borderRadius,
            border: Border.all(
              color: S256Colors.text.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    8,
                    (index) => SkeletonLoader(
                      width: 20,
                      height: 50.0 + (index * 10.0),
                      borderRadius: S256Theme.borderRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Last sync skeleton
        SkeletonLoader(
          width: 100,
          height: 12,
          borderRadius: S256Theme.borderRadius,
        ),
      ],
    );
  }
}

class TransactionSkeleton extends StatelessWidget {
  const TransactionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: S256Colors.text.withValues(alpha: 0.05),
        borderRadius: S256Theme.borderRadius,
      ),
      child: Row(
        children: [
          // Icon skeleton
          SkeletonLoader(
            width: 40,
            height: 40,
            borderRadius: S256Theme.borderRadius,
          ),
          const SizedBox(width: 12),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 150,
                  height: 16,
                  borderRadius: S256Theme.borderRadius,
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 100,
                  height: 12,
                  borderRadius: S256Theme.borderRadius,
                ),
              ],
            ),
          ),
          // Trailing skeleton
          SkeletonLoader(
            width: 20,
            height: 20,
            borderRadius: S256Theme.borderRadius,
          ),
        ],
      ),
    );
  }
}
