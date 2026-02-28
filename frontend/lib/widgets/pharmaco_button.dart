import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// PharmaCo Button
/// ───────────────
/// Primary (filled), Secondary (outlined), and Text variants.
/// Supports: loading, disabled, error, icon-leading states.
/// All sizes meet 44dp minimum tap target.
///
/// Usage:
///   PharmacoButton(label: 'Add to Cart', onPressed: () {})
///   PharmacoButton.secondary(label: 'Cancel', onPressed: () {})
///   PharmacoButton(label: 'Placing...', onPressed: null, isLoading: true)

enum PharmacoButtonSize { large, regular, small }

enum PharmacoButtonVariant { primary, secondary, text }

class PharmacoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PharmacoButtonSize size;
  final PharmacoButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const PharmacoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PharmacoButtonSize.large,
    this.variant = PharmacoButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  /// Convenience: secondary outlined button.
  const PharmacoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PharmacoButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = PharmacoButtonVariant.secondary;

  /// Convenience: text button.
  const PharmacoButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = PharmacoButtonSize.regular,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = PharmacoButtonVariant.text;

  double get _height {
    switch (size) {
      case PharmacoButtonSize.large:
        return PharmacoTokens.buttonHeightLarge;
      case PharmacoButtonSize.regular:
        return PharmacoTokens.buttonHeightRegular;
      case PharmacoButtonSize.small:
        return PharmacoTokens.buttonHeightSmall;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: PharmacoTokens.iconSmall,
            height: PharmacoTokens.iconSmall,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == PharmacoButtonVariant.primary
                  ? PharmacoTokens.white
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: PharmacoTokens.space8),
        ] else if (icon != null) ...[
          Icon(icon, size: PharmacoTokens.iconMedium),
          const SizedBox(width: PharmacoTokens.space8),
        ],
        Text(label),
      ],
    );

    switch (variant) {
      case PharmacoButtonVariant.primary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: _height,
          child: ElevatedButton(
            onPressed: effectiveOnPressed,
            child: child,
          ),
        );
      case PharmacoButtonVariant.secondary:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: _height,
          child: OutlinedButton(
            onPressed: effectiveOnPressed,
            child: child,
          ),
        );
      case PharmacoButtonVariant.text:
        return SizedBox(
          height: _height,
          child: TextButton(
            onPressed: effectiveOnPressed,
            child: child,
          ),
        );
    }
  }
}
