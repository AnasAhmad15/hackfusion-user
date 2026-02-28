import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// PharmaCo Bottom Navigation — Icons-Only with Elevated Center AI Tab
/// ────────────────────────────────────────────────────────────────────
/// 5 tabs: Home, Medicines, AI (elevated), Orders, Profile.
/// Center tab is a large colored circle that protrudes from the bar.
/// Active tabs use a subtle pill indicator, inactive tabs are grey.

class PharmacoBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int orderBadgeCount;

  const PharmacoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.orderBadgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Home
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              // Medicines
              _NavItem(
                icon: Icons.medication_outlined,
                activeIcon: Icons.medication_rounded,
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              // Center AI Tab (elevated)
              _CenterAITab(
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              // Orders (with badge)
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                isActive: currentIndex == 3,
                showBadge: orderBadgeCount > 0,
                badgeCount: orderBadgeCount,
                onTap: () => onTap(3),
              ),
              // Profile
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                isActive: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// REGULAR NAV ITEM (icon only, subtle pill when active)
// ─────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final bool showBadge;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.showBadge = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final displayIcon = isActive ? activeIcon : icon;
    final color = isActive ? PharmacoTokens.primaryBase : PharmacoTokens.neutral400;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            showBadge
                ? Badge(
                    label: Text('$badgeCount', style: const TextStyle(fontSize: 10)),
                    backgroundColor: PharmacoTokens.error,
                    child: Icon(displayIcon, size: 24, color: color),
                  )
                : Icon(displayIcon, size: 24, color: color),
            const SizedBox(height: 4),
            // Active dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 5 : 0,
              height: isActive ? 5 : 0,
              decoration: BoxDecoration(
                color: PharmacoTokens.primaryBase,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CENTER AI TAB (elevated colored circle)
// ─────────────────────────────────────────────────

class _CenterAITab extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _CenterAITab({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: const Offset(0, -14), // Protrude above the bar
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6366F1), // Indigo-500
                Color(0xFF8B5CF6), // Violet-500
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
