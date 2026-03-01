import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/location_service.dart';
import '../theme/design_tokens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  Map<String, String> _translatedStrings = {
    'Profile': 'Profile',
    'Personal Details': 'Personal Details',
    'Full Name': 'Full Name',
    'Phone Number': 'Phone Number',
    'Age': 'Age',
    'Blood Group': 'Blood Group',
    'Address / Area': 'Address / Area',
    'Health & Medical': 'Health & Medical',
    'Allergies': 'Allergies',
    'Chronic Conditions': 'Chronic Conditions',
    'Regular Medications': 'Regular Medications',
    'Account': 'Account',
    'Security': 'Security',
    'Notifications': 'Notifications',
    'Language': 'Language',
    'Logout': 'Logout',
    'None': 'None',
    'Not set': 'Not set',
  };

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    LocalizationService.addListener(_translateUI);
    _translateUI();
  }

  @override
  void dispose() {
    LocalizationService.removeListener(_translateUI);
    super.dispose();
  }

  Future<void> _translateUI() async {
    if (!mounted) return;
    setState(() {
      _translatedStrings = {
        'Profile': LocalizationService.t('Profile'),
        'Personal Details': LocalizationService.t('Personal Details'),
        'Full Name': LocalizationService.t('Full Name'),
        'Phone Number': LocalizationService.t('Phone Number'),
        'Age': LocalizationService.t('Age'),
        'Blood Group': LocalizationService.t('Blood Group'),
        'Address / Area': LocalizationService.t('Address / Area'),
        'Health & Medical': LocalizationService.t('Health & Medical'),
        'Allergies': LocalizationService.t('Allergies'),
        'Chronic Conditions': LocalizationService.t('Chronic Conditions'),
        'Regular Medications': LocalizationService.t('Regular Medications'),
        'Account': LocalizationService.t('Account'),
        'Security': LocalizationService.t('Security'),
        'Notifications': LocalizationService.t('Notifications'),
        'Language': LocalizationService.t('Language'),
        'Logout': LocalizationService.t('Logout'),
        'None': LocalizationService.t('None'),
        'Not set': LocalizationService.t('Not set'),
      };
    });
  }

  String t(String key) => _translatedStrings[key] ?? key;

  Future<void> _fetchProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final data = await _client
            .from('user_profiles')
            .select()
            .eq('id', user.id)
            .single();

        final walletRes = await _client
            .from('wallets')
            .select('balance')
            .eq('user_id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _profileData = data;
            if (walletRes != null) {
              _profileData!['wallet_balance'] = (walletRes['balance'] as num).toDouble();
            } else {
              _profileData!['wallet_balance'] = 0.0;
            }
          });

          final lat = _profileData?['latitude'];
          final lng = _profileData?['longitude'];
          final currentAddr = _profileData?['address'] ?? _profileData?['city_area'];

          if ((currentAddr == null || currentAddr.toString().isEmpty || currentAddr == 'Not set') && lat != null && lng != null) {
            final syncedAddress = await LocationService.syncUserAddress(user.id, lat: lat, lng: lng);
            if (mounted && syncedAddress != null) {
              setState(() {
                _profileData?['address'] = syncedAddress;
                _profileData?['city_area'] = syncedAddress;
              });
            }
          }

          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(t('Profile')), automaticallyImplyLeading: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _authService.currentUser;
    final displayName = _profileData?['full_name'] ?? user?.userMetadata?['name'] ?? 'User';
    final email = user?.email ?? '';
    final phone = _profileData?['phone_number'] ?? t('Not set');
    final avatarUrl = _profileData?['avatar_url'];
    final isComplete = _profileData?['is_profile_complete'] ?? false;
    final walletBalance = (_profileData?['wallet_balance'] ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Profile')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/profile-completion').then((_) => _fetchProfile()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ────── Profile Header ──────
            _buildProfileHeader(theme, isDark, displayName, email, phone, avatarUrl, isComplete),
            const SizedBox(height: PharmacoTokens.space16),

            // ────── Quick Stats Row ──────
            _buildQuickStats(theme, isDark, walletBalance),
            const SizedBox(height: PharmacoTokens.space24),

            // ────── Menu Sections ──────
            _buildMenuSection(theme, isDark, t('Health & Medical'), [
              _MenuItem(Icons.health_and_safety_rounded, 'Health Profile', PharmacoTokens.success,
                  () => Navigator.pushNamed(context, '/health-profile')),
              _MenuItem(Icons.inventory_2_outlined, 'Home Inventory', PharmacoTokens.warning,
                  () => Navigator.pushNamed(context, '/inventory')),
              _MenuItem(Icons.alarm_rounded, 'Reminders', const Color(0xFF7C3AED),
                  () => Navigator.pushNamed(context, '/reminders')),
              _MenuItem(Icons.upload_file_rounded, 'Upload Prescription', PharmacoTokens.primaryBase,
                  () => Navigator.pushNamed(context, '/upload-prescription')),
            ]),
            const SizedBox(height: PharmacoTokens.space12),

            _buildMenuSection(theme, isDark, t('Account'), [
              _MenuItem(Icons.account_balance_wallet_rounded, 'My Wallet', PharmacoTokens.primaryBase,
                  () => Navigator.pushNamed(context, '/wallet').then((_) => _fetchProfile())),
              _MenuItem(Icons.receipt_long_rounded, 'My Orders', PharmacoTokens.secondaryBase,
                  () => Navigator.pushNamed(context, '/my-orders')),
              _MenuItem(Icons.shopping_cart_rounded, 'Cart', PharmacoTokens.primaryBase,
                  () => Navigator.pushNamed(context, '/cart')),
            ]),
            const SizedBox(height: PharmacoTokens.space12),

            // ────── Language Selector ──────
            _buildLanguageCard(theme, isDark),
            const SizedBox(height: PharmacoTokens.space24),

            // ────── Logout ──────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(t('Logout'), style: const TextStyle(color: PharmacoTokens.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/language-selection', (route) => false);
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: PharmacoTokens.error),
                label: Text(t('Logout'), style: const TextStyle(color: PharmacoTokens.error)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: BorderSide(color: PharmacoTokens.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusMedium),
                ),
              ),
            ),
            const SizedBox(height: PharmacoTokens.space40),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // PROFILE HEADER
  // ────────────────────────────────────────────────

  Widget _buildProfileHeader(ThemeData theme, bool isDark, String name, String email, String phone, String? avatarUrl, bool isComplete) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
      padding: const EdgeInsets.all(PharmacoTokens.space20),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PharmacoTokens.primaryBase, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: PharmacoTokens.primarySurface,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person_rounded, size: 40, color: PharmacoTokens.primaryBase)
                      : null,
                ),
              ),
              const SizedBox(width: PharmacoTokens.space16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    if (email.isNotEmpty)
                      Text(email, style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
                    const SizedBox(height: 2),
                    Text(phone, style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral400)),
                  ],
                ),
              ),
              // Edit button
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: PharmacoTokens.primarySurface,
                  borderRadius: PharmacoTokens.borderRadiusSmall,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: PharmacoTokens.primaryBase),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pushNamed(context, '/profile-completion').then((_) => _fetchProfile()),
                ),
              ),
            ],
          ),
          const SizedBox(height: PharmacoTokens.space16),
          // Progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: PharmacoTokens.borderRadiusFull,
                  child: LinearProgressIndicator(
                    value: isComplete ? 1.0 : 0.5,
                    backgroundColor: PharmacoTokens.neutral200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isComplete ? PharmacoTokens.success : PharmacoTokens.primaryBase,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: PharmacoTokens.space12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space8, vertical: 2),
                decoration: BoxDecoration(
                  color: isComplete ? PharmacoTokens.successLight : PharmacoTokens.primarySurface,
                  borderRadius: PharmacoTokens.borderRadiusFull,
                ),
                child: Text(
                  isComplete ? '100%' : '50%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isComplete ? PharmacoTokens.success : PharmacoTokens.primaryBase,
                    fontWeight: PharmacoTokens.weightSemiBold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // QUICK STATS (Wallet, Orders, Emergency)
  // ────────────────────────────────────────────────

  Widget _buildQuickStats(ThemeData theme, bool isDark, double walletBalance) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
      child: Row(
        children: [
          _buildStatChip(
            theme, isDark,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Wallet',
            value: '₹${walletBalance.toStringAsFixed(0)}',
            color: PharmacoTokens.primaryBase,
            onTap: () => Navigator.pushNamed(context, '/wallet').then((_) => _fetchProfile()),
          ),
          const SizedBox(width: PharmacoTokens.space12),
          _buildStatChip(
            theme, isDark,
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            value: 'View',
            color: PharmacoTokens.secondaryBase,
            onTap: () => Navigator.pushNamed(context, '/my-orders'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, bool isDark, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(PharmacoTokens.space12),
          decoration: BoxDecoration(
            color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
            borderRadius: PharmacoTokens.borderRadiusCard,
            boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
            border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: PharmacoTokens.space4),
              Text(value,
                  style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: PharmacoTokens.weightSemiBold)),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.neutral500)),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // MENU SECTIONS
  // ────────────────────────────────────────────────

  Widget _buildMenuSection(ThemeData theme, bool isDark, String title, List<_MenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PharmacoTokens.space16, PharmacoTokens.space16, PharmacoTokens.space16, PharmacoTokens.space8),
            child: Text(title, style: theme.textTheme.labelLarge?.copyWith(
              color: PharmacoTokens.neutral500,
              fontWeight: PharmacoTokens.weightSemiBold,
              letterSpacing: 0.5,
            )),
          ),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16, vertical: PharmacoTokens.space12),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.1),
                            borderRadius: PharmacoTokens.borderRadiusSmall,
                          ),
                          child: Icon(item.icon, color: item.color, size: 20),
                        ),
                        const SizedBox(width: PharmacoTokens.space12),
                        Expanded(child: Text(item.label, style: theme.textTheme.bodyMedium)),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: PharmacoTokens.neutral400),
                      ],
                    ),
                  ),
                ),
                if (idx < items.length - 1)
                  Divider(height: 1, indent: PharmacoTokens.space16 + 36 + PharmacoTokens.space12, color: PharmacoTokens.neutral200),
              ],
            );
          }),
          const SizedBox(height: PharmacoTokens.space4),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // LANGUAGE CARD
  // ────────────────────────────────────────────────

  Widget _buildLanguageCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
      padding: const EdgeInsets.all(PharmacoTokens.space16),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: PharmacoTokens.primaryBase.withValues(alpha: 0.1),
              borderRadius: PharmacoTokens.borderRadiusSmall,
            ),
            child: const Icon(Icons.language_rounded, color: PharmacoTokens.primaryBase, size: 20),
          ),
          const SizedBox(width: PharmacoTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Language'), style: theme.textTheme.bodyMedium),
                DropdownButton<String>(
                  value: LocalizationService.currentLanguage,
                  isExpanded: true,
                  underline: const SizedBox(),
                  isDense: true,
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      await LocalizationService.setLanguage(newValue);
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Language changed to $newValue'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  items: LocalizationService.supportedLanguages
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: theme.textTheme.bodySmall));
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}
