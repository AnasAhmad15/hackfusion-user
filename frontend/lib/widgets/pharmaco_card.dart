import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// PharmaCo Card
/// ─────────────
/// Variants: compact, media (image top), action (with CTA).
/// Uses token-based padding, radii, and subtle z1 shadows.
///
/// Usage:
///   PharmacoCard(child: ...)
///   PharmacoCard.media(imageUrl: '...', child: ...)

enum PharmacoCardVariant { compact, media, action }

class PharmacoCard extends StatelessWidget {
  final Widget child;
  final PharmacoCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final String? imageUrl;
  final Widget? trailing;
  final Color? backgroundColor;

  const PharmacoCard({
    super.key,
    required this.child,
    this.variant = PharmacoCardVariant.compact,
    this.onTap,
    this.padding,
    this.imageUrl,
    this.trailing,
    this.backgroundColor,
  });

  /// Media card with an image at the top.
  const PharmacoCard.media({
    super.key,
    required this.child,
    required this.imageUrl,
    this.onTap,
    this.padding,
    this.trailing,
    this.backgroundColor,
  }) : variant = PharmacoCardVariant.media;

  /// Action card with a trailing widget (chevron, button, etc).
  const PharmacoCard.action({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.trailing,
    this.backgroundColor,
  })  : variant = PharmacoCardVariant.action,
        imageUrl = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBg = backgroundColor ??
        (isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white);

    final effectivePadding = padding ??
        const EdgeInsets.all(PharmacoTokens.space16);

    Widget cardContent;

    switch (variant) {
      case PharmacoCardVariant.media:
        cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(PharmacoTokens.radiusCard),
                  topRight: Radius.circular(PharmacoTokens.radiusCard),
                ),
                child: Image.network(
                  imageUrl!,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: PharmacoTokens.neutral100,
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: PharmacoTokens.neutral400,
                        size: PharmacoTokens.iconLarge,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: effectivePadding, child: child),
          ],
        );

      case PharmacoCardVariant.action:
        cardContent = Padding(
          padding: effectivePadding,
          child: Row(
            children: [
              Expanded(child: child),
              if (trailing != null) ...[
                const SizedBox(width: PharmacoTokens.space12),
                trailing!,
              ] else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? PharmacoTokens.neutral500
                      : PharmacoTokens.neutral400,
                ),
            ],
          ),
        );

      case PharmacoCardVariant.compact:
        cardContent = Padding(
          padding: effectivePadding,
          child: child,
        );
    }

    return Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark
            ? Border.all(color: PharmacoTokens.darkBorder)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: PharmacoTokens.borderRadiusCard,
        child: InkWell(
          onTap: onTap,
          borderRadius: PharmacoTokens.borderRadiusCard,
          child: cardContent,
        ),
      ),
    );
  }
}
