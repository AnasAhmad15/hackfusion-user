import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Skeleton Loader
/// ───────────────
/// Shimmer loading placeholder with 1200ms loop.
/// Adapts to light and dark themes.
///
/// Usage:
///   SkeletonLoader(width: 200, height: 16)  // text line
///   SkeletonLoader.card()                    // full card placeholder
///   SkeletonLoader.circle(size: 40)          // avatar placeholder

class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = PharmacoTokens.radiusSmall,
  });

  /// Circle skeleton for avatars.
  const SkeletonLoader.circle({
    super.key,
    double size = PharmacoTokens.avatarMedium,
  })  : width = size,
        height = size,
        borderRadius = 999;

  /// Card-sized skeleton placeholder.
  const SkeletonLoader.card({
    super.key,
  })  : width = double.infinity,
        height = PharmacoTokens.cardMinHeight,
        borderRadius = PharmacoTokens.radiusCard;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PharmacoTokens.durationShimmer,
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? PharmacoTokens.darkSurfaceElevated
        : PharmacoTokens.neutral200;
    final shimmerColor = isDark
        ? PharmacoTokens.darkBorder
        : PharmacoTokens.neutral100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built skeleton layouts for common screen sections.
class SkeletonLayouts {
  SkeletonLayouts._();

  /// Skeleton for a list of cards (e.g., medicine list loading).
  static Widget cardList({int count = 3}) {
    return Column(
      children: List.generate(count, (i) {
        return const Padding(
          padding: EdgeInsets.only(bottom: PharmacoTokens.space16),
          child: SkeletonLoader.card(),
        );
      }),
    );
  }

  /// Skeleton for a horizontal carousel (e.g., featured medicines).
  static Widget carousel({int count = 3}) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space16,
        ),
        itemCount: count,
        separatorBuilder: (_, __) =>
            const SizedBox(width: PharmacoTokens.space12),
        itemBuilder: (_, __) => const SizedBox(
          width: 140,
          child: SkeletonLoader.card(),
        ),
      ),
    );
  }

  /// Skeleton for a quick-action grid row.
  static Widget actionGrid({int items = 5}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(items, (_) {
        return Column(
          children: [
            const SkeletonLoader.circle(size: 48),
            const SizedBox(height: PharmacoTokens.space8),
            SkeletonLoader(width: 48, height: 10),
          ],
        );
      }),
    );
  }
}
