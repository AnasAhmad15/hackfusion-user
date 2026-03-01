import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../theme/pharmaco_theme.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/cart_service.dart';
import '../widgets/pharmaco_app_bar.dart';
import '../widgets/pharmaco_bottom_nav.dart';
import '../widgets/pharmaco_fab.dart';
import '../widgets/pharmaco_card.dart';
import '../widgets/pharmaco_input.dart';
import '../widgets/skeleton_loader.dart';
import 'chat_screen.dart';
import 'medicines_list_screen.dart';
import 'my_orders_screen.dart';
import 'profile_screen.dart';

/// Redesigned Home Screen — Direction A: Clean Medical
/// ────────────────────────────────────────────────────
/// Spacious, white + medical blue, token-driven, accessible.
/// No backend changes — uses same Supabase streams and API calls.

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2> {
  final _authService = AuthService();
  int _selectedIndex = 0;

  // Localization
  Map<String, String> _t = {};

  @override
  void initState() {
    super.initState();
    LocalizationService.addListener(_translateUI);
    _translateUI();
    CartService().fetchCart();
  }

  @override
  void dispose() {
    LocalizationService.removeListener(_translateUI);
    super.dispose();
  }

  void _translateUI() {
    if (!mounted) return;
    setState(() {
      _t = {
        'Home': LocalizationService.t('Home'),
        'Medicines': LocalizationService.t('Medicines'),
        'AI Chat': LocalizationService.t('AI Chat'),
        'Profile': LocalizationService.t('Profile'),
      };
    });
  }

  String t(String key) => _t[key] ?? key;

  final List<Widget> _pages = const [
    _HomeContentV2(),
    MedicinesListScreen(),
    ChatScreen(),
    MyOrdersScreen(),
    ProfileScreen(),
  ];

  void _onTabTap(int index) {
    if (index == 2) {
      // AI tab: launch voice agent first, chat is the fallback
      Navigator.pushNamed(context, '/s2s-voice');
      setState(() => _selectedIndex = 2);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: PharmacoBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  HOME CONTENT (the actual scrollable home page)
// ─────────────────────────────────────────────────

class _HomeContentV2 extends StatelessWidget {
  const _HomeContentV2();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('user_profiles')
          .stream(primaryKey: ['id'])
          .eq('id', user?.id ?? ''),
      builder: (context, snapshot) {
        final profile =
            snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;
        final displayName = profile?['full_name'] ??
            user?.userMetadata?['name'] ??
            'User';
        final walletBalance = (profile?['wallet_balance'] ?? 0).toDouble();

        return Scaffold(
          appBar: PharmacoAppBar(
            title: 'PharmaCo',
            onSearchTap: () =>
                Navigator.pushNamed(context, '/medicine-search'),
            onCartTap: () => Navigator.pushNamed(context, '/cart'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              // Pull-to-refresh — Supabase stream already handles realtime
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ─── Greeting Section ───
                _GreetingSection(
                  name: displayName,
                  walletBalance: walletBalance,
                ),

                // ─── Search Bar ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PharmacoTokens.space16,
                  ),
                  child: PharmacoSearchBar(
                    hint: 'Search medicines...',
                    onTap: () =>
                        Navigator.pushNamed(context, '/medicine-search'),
                    readOnly: true,
                  ),
                ),

                const SizedBox(height: PharmacoTokens.space24),

                // ─── AI Chat Quick Card ───
                _AIChatCard(
                  onTap: () => Navigator.pushNamed(context, '/chat'),
                ),

                const SizedBox(height: PharmacoTokens.space24),

                // ─── Quick Actions Grid ───
                _QuickActionsGrid(context: context),

                const SizedBox(height: PharmacoTokens.space24),

                // ─── Featured Medicines ───
                _FeaturedMedicines(),

                const SizedBox(height: PharmacoTokens.space24),

                // ─── Health Profile CTA ───
                _HealthProfileCard(
                  onTap: () =>
                      Navigator.pushNamed(context, '/profile-completion'),
                ),

                const SizedBox(height: PharmacoTokens.space32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────
//  GREETING SECTION
// ─────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  final String name;
  final double walletBalance;

  const _GreetingSection({
    required this.name,
    required this.walletBalance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PharmacoTokens.space16,
        PharmacoTokens.space16,
        PharmacoTokens.space16,
        PharmacoTokens.space16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name 👋',
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: PharmacoTokens.space4),
                Text(
                  'Your Health, Our Priority',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PharmacoTokens.neutral500,
                  ),
                ),
              ],
            ),
          ),
          // Wallet chip
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/wallet'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PharmacoTokens.space12,
                vertical: PharmacoTokens.space8,
              ),
              decoration: BoxDecoration(
                color: PharmacoTokens.primarySurface,
                borderRadius: PharmacoTokens.borderRadiusFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: PharmacoTokens.iconSmall,
                    color: PharmacoTokens.primaryBase,
                  ),
                  const SizedBox(width: PharmacoTokens.space4),
                  Text(
                    '₹${walletBalance.toStringAsFixed(0)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: PharmacoTokens.primaryBase,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  AI CHAT QUICK CARD
// ─────────────────────────────────────────────────

class _AIChatCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AIChatCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PharmacoTokens.space16,
      ),
      child: PharmacoCard(
        onTap: onTap,
        backgroundColor: PharmacoTokens.primarySurface,
        child: Row(
          children: [
            // AI Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PharmacoTokens.primaryBase,
                borderRadius: PharmacoTokens.borderRadiusMedium,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: PharmacoTokens.white,
                size: PharmacoTokens.iconMedium,
              ),
            ),
            const SizedBox(width: PharmacoTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pharma AI Assistant',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: PharmacoTokens.space4),
                  Text(
                    'Ask about medicines, health, or order help',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PharmacoTokens.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PharmacoTokens.space12,
                vertical: PharmacoTokens.space8,
              ),
              decoration: BoxDecoration(
                color: PharmacoTokens.primaryBase,
                borderRadius: PharmacoTokens.borderRadiusFull,
              ),
              child: Text(
                'Ask AI',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: PharmacoTokens.white,
                  fontWeight: PharmacoTokens.weightSemiBold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  QUICK ACTIONS GRID (5 items)
// ─────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final BuildContext context;
  const _QuickActionsGrid({required this.context});

  @override
  Widget build(BuildContext _) {
    final actions = [
      _QuickAction(
        icon: Icons.medication_rounded,
        label: 'Browse',
        color: PharmacoTokens.primaryBase,
        onTap: () => Navigator.pushNamed(context, '/medicines'),
      ),
      _QuickAction(
        icon: Icons.receipt_long_rounded,
        label: 'Orders',
        color: PharmacoTokens.secondaryBase,
        onTap: () => Navigator.pushNamed(context, '/my-orders'),
      ),
      _QuickAction(
        icon: Icons.inventory_2_outlined,
        label: 'Inventory',
        color: PharmacoTokens.warning,
        onTap: () => Navigator.pushNamed(context, '/inventory'),
      ),
      _QuickAction(
        icon: Icons.alarm_rounded,
        label: 'Reminders',
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.pushNamed(context, '/reminders'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PharmacoTokens.space16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions,
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: PharmacoTokens.borderRadiusMedium,
              ),
              child: Icon(
                icon,
                color: color,
                size: PharmacoTokens.iconMedium,
              ),
            ),
            const SizedBox(height: PharmacoTokens.space8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: PharmacoTokens.weightMedium,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  FEATURED MEDICINES CAROUSEL
// ─────────────────────────────────────────────────

class _FeaturedMedicines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PharmacoTokens.space16,
          ),
          child: Row(
            children: [
              Text(
                'Featured Medicines',
                style: theme.textTheme.headlineMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/medicines'),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: PharmacoTokens.space8),
        SizedBox(
          height: 180,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('medicines')
                .stream(primaryKey: ['id'])
                .limit(10),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SkeletonLayouts.carousel();
              }

              final medicines = snapshot.data!;
              if (medicines.isEmpty) {
                return Center(
                  child: Text(
                    'No featured medicines',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: PharmacoTokens.neutral400,
                    ),
                  ),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: PharmacoTokens.space16,
                ),
                itemCount: medicines.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: PharmacoTokens.space12),
                itemBuilder: (context, index) {
                  final med = medicines[index];
                  return _MedicineCard(medicine: med);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> medicine;
  const _MedicineCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = medicine['name'] ?? 'Medicine';
    final price = (medicine['price'] ?? 0).toDouble();
    final requiresPrescription =
        medicine['requires_prescription'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/medicine-detail',
            arguments: medicine);
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(PharmacoTokens.space12),
        decoration: BoxDecoration(
          color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
          borderRadius: PharmacoTokens.borderRadiusCard,
          boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
          border: isDark
              ? Border.all(color: PharmacoTokens.darkBorder)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine icon placeholder
            Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: PharmacoTokens.primarySurface,
                borderRadius: PharmacoTokens.borderRadiusSmall,
              ),
              child: Icon(
                Icons.medication_rounded,
                color: PharmacoTokens.primaryBase,
                size: PharmacoTokens.iconLarge,
              ),
            ),
            const SizedBox(height: PharmacoTokens.space8),
            // Name
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: PharmacoTokens.weightMedium,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Price + badge row
            Row(
              children: [
                Text(
                  '₹${price.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: PharmacoTokens.primaryBase,
                  ),
                ),
                const Spacer(),
                if (requiresPrescription)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PharmacoTokens.space4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: PharmacoTokens.warningLight,
                      borderRadius: PharmacoTokens.borderRadiusSmall,
                    ),
                    child: Text(
                      'Rx',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: PharmacoTokens.warning,
                        fontWeight: PharmacoTokens.weightSemiBold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
//  HEALTH PROFILE CTA CARD
// ─────────────────────────────────────────────────

class _HealthProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HealthProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PharmacoTokens.space16,
      ),
      child: PharmacoCard.action(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PharmacoTokens.secondarySurface,
                borderRadius: PharmacoTokens.borderRadiusSmall,
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: PharmacoTokens.secondaryBase,
                size: PharmacoTokens.iconMedium,
              ),
            ),
            const SizedBox(width: PharmacoTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Health Profile',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: PharmacoTokens.space4),
                  Text(
                    'Help us provide better care for you',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PharmacoTokens.neutral500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
