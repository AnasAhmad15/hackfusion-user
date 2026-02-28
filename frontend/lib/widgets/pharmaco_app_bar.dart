import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/cart_service.dart';

/// PharmaCo App Bar
/// ────────────────
/// Clean medical AppBar with optional search, cart badge, notification bell.
///
/// Usage:
///   PharmacoAppBar(title: 'PharmaCo')
///   PharmacoAppBar.search(onSearchTap: () {}, onCartTap: () {})

class PharmacoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showSearch;
  final bool showCart;
  final bool showNotifications;
  final bool showBack;
  final VoidCallback? onSearchTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onNotificationTap;
  final Widget? leading;
  final List<Widget>? extraActions;

  const PharmacoAppBar({
    super.key,
    this.title,
    this.showSearch = true,
    this.showCart = true,
    this.showNotifications = true,
    this.showBack = false,
    this.onSearchTap,
    this.onCartTap,
    this.onNotificationTap,
    this.leading,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(PharmacoTokens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      leading: leading ??
          (showBack
              ? IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null),
      title: title != null
          ? Text(
              title!,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: PharmacoTokens.weightBold,
              ),
            )
          : null,
      actions: [
        if (showSearch)
          IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search_rounded),
            constraints: const BoxConstraints(
              minWidth: PharmacoTokens.minTapTarget,
              minHeight: PharmacoTokens.minTapTarget,
            ),
          ),
        if (showNotifications)
          IconButton(
            onPressed: onNotificationTap,
            icon: const Icon(Icons.notifications_outlined),
            constraints: const BoxConstraints(
              minWidth: PharmacoTokens.minTapTarget,
              minHeight: PharmacoTokens.minTapTarget,
            ),
          ),
        if (showCart) _CartBadgeIcon(onTap: onCartTap),
        if (extraActions != null) ...extraActions!,
        const SizedBox(width: PharmacoTokens.space4),
      ],
    );
  }
}

/// Cart icon with item count badge — listens to CartService.
class _CartBadgeIcon extends StatelessWidget {
  final VoidCallback? onTap;
  const _CartBadgeIcon({this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService(),
      builder: (context, _) {
        final count = CartService().items.length;
        return IconButton(
          onPressed: onTap,
          constraints: const BoxConstraints(
            minWidth: PharmacoTokens.minTapTarget,
            minHeight: PharmacoTokens.minTapTarget,
          ),
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            backgroundColor: PharmacoTokens.error,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
        );
      },
    );
  }
}
