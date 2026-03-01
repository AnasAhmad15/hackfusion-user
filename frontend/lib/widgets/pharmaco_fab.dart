import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// PharmaCo FAB
/// ────────────
/// Minimal, clean floating action button for emergency or AI quick-access.
/// No heavy animations — simple scale on press.
///
/// Usage:
///   PharmacoFab(icon: Icons.emergency, onPressed: () {}, isEmergency: true)
///   PharmacoFab.ai(onPressed: () {})

class PharmacoFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool mini;

  const PharmacoFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.mini = false,
  });

  /// Convenience: AI assistant FAB.
  const PharmacoFab.ai({
    super.key,
    required this.onPressed,
    this.tooltip = 'Ask AI',
  })  : icon = Icons.auto_awesome_rounded,
        mini = false;

  @override
  Widget build(BuildContext context) {
    final size = mini ? PharmacoTokens.fabMiniSize : PharmacoTokens.fabSize;

    return SizedBox(
      width: size,
      height: size,
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        heroTag: 'pharmaco_fab',
        backgroundColor: PharmacoTokens.primaryBase,
        foregroundColor: PharmacoTokens.white,
        elevation: PharmacoTokens.elevationZ1,
        highlightElevation: PharmacoTokens.elevationZ2,
        shape: const CircleBorder(),
        child: Icon(
          icon,
          size: mini ? PharmacoTokens.iconMedium : PharmacoTokens.iconLarge,
        ),
      ),
    );
  }
}
