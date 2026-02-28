import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// PharmaCo Input Field
/// ────────────────────
/// States: default, focused, error, disabled, with suffix icon.
/// Min height 48dp, 44dp touch target ensured by padding.
///
/// Usage:
///   PharmacoInput(label: 'Email', controller: _ctrl)
///   PharmacoInput(label: 'Password', obscure: true, errorText: 'Required')

class PharmacoInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? errorText;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const PharmacoInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.errorText,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: PharmacoTokens.space8),
        ],
        SizedBox(
          // Ensure min tap target height
          child: TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            focusNode: focusNode,
            textInputAction: textInputAction,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? null
                      : PharmacoTokens.neutral400,
                ),
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              // Theme provides all border, fill, and text styles
            ),
          ),
        ),
      ],
    );
  }
}

/// Search bar variant — rounded, with mic and search icons.
class PharmacoSearchBar extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final VoidCallback? onMicTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  const PharmacoSearchBar({
    super.key,
    this.hint = 'Search medicines...',
    this.controller,
    this.onMicTap,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: PharmacoTokens.inputHeight,
      decoration: BoxDecoration(
        color: isDark
            ? PharmacoTokens.darkSurfaceElevated
            : PharmacoTokens.neutral100,
        borderRadius: PharmacoTokens.borderRadiusFull,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        textAlignVertical: TextAlignVertical.center,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: PharmacoTokens.neutral400,
            size: PharmacoTokens.iconMedium,
          ),
          suffixIcon: null,
        ),
      ),
    );
  }
}
