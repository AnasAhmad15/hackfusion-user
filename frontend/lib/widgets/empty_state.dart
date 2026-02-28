import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'pharmaco_button.dart';

/// Empty State
/// ───────────
/// Placeholder for screens with no data.
/// Shows an icon illustration, title, subtitle, and optional CTA button.
///
/// Usage:
///   EmptyState(
///     icon: Icons.inventory_2_outlined,
///     title: 'No Medicines',
///     subtitle: 'Your inventory is empty',
///     actionLabel: 'Add Medicine',
///     onAction: () {},
///   )

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PharmacoTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon illustration
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: isDark
                    ? PharmacoTokens.primarySurfaceDark
                    : PharmacoTokens.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: PharmacoTokens.space40,
                color: PharmacoTokens.primaryBase,
              ),
            ),
            const SizedBox(height: PharmacoTokens.space24),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PharmacoTokens.space8),

            // Subtitle
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? PharmacoTokens.neutral400
                      : PharmacoTokens.neutral500,
                ),
                textAlign: TextAlign.center,
              ),

            // CTA
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: PharmacoTokens.space24),
              PharmacoButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
