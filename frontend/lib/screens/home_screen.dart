import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/voice_service.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'my_orders_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'emergency_contact_screen.dart';
import 'medicines_list_screen.dart';
import '../services/localization_service.dart';
import '../services/cart_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  int _selectedIndex = 0;
  
  Map<String, String> _translatedStrings = {
    'Welcome': 'Welcome',
    'Your Health, Our Priority': 'Your Health, Our Priority',
    'Complete Your Health Profile': 'Complete Your Health Profile',
    'Help us provide better care': 'Help us provide better care',
    'Home Inventory': 'Home Inventory',
    'Total Medicines': 'Total Medicines',
    'Critical Medicines': 'Critical Medicines',
    'Expiring Soon': 'Expiring Soon',
    'Days Left Average': 'Days Left Average',
    'Inventory': 'Inventory',
    'Add Medicine': 'Add Medicine',
    'Manual': 'Manual',
    'From Order': 'From Order',
    'From Prescription': 'From Prescription',
    'Safe': 'Safe',
    'Low': 'Low',
    'Critical': 'Critical',
    'Expired': 'Expired',
    'Days Left': 'Days Left',
    'Quantity': 'Quantity',
    'Reorder': 'Reorder',
    'Upload Prescription': 'Upload Prescription',
    'Quick order processing': 'Quick order processing',
    'Tap to Talk to Pharma AI': 'Tap to Talk to Pharma AI',
    'Listening...': 'Listening...',
    'Home': 'Home',
    'Orders': 'Orders',
    'AI Chat': 'AI Chat',
    'Emergency': 'Emergency',
    'Profile': 'Profile',
  };

  @override
  void initState() {
    super.initState();
    LocalizationService.addListener(_translateUI);
    _translateUI();
    CartService().fetchCart(); // Ensure cart is loaded on start
  }

  @override
  void dispose() {
    LocalizationService.removeListener(_translateUI);
    super.dispose();
  }

  Future<void> _translateUI() async {
    if (!mounted) return;
    
    setState(() {
      // Always update strings based on current language (hardcoded)
      _translatedStrings = {
        'Welcome': LocalizationService.t('Welcome'),
        'Your Health, Our Priority': LocalizationService.t('Your Health, Our Priority'),
        'Complete Your Health Profile': LocalizationService.t('Complete Your Health Profile'),
        'Help us provide better care': LocalizationService.t('Help us provide better care'),
        'Home Inventory': LocalizationService.t('Home Inventory'),
        'Total Medicines': LocalizationService.t('Total Medicines'),
        'Critical Medicines': LocalizationService.t('Critical Medicines'),
        'Expiring Soon': LocalizationService.t('Expiring Soon'),
        'Days Left Average': LocalizationService.t('Days Left Average'),
        'Inventory': LocalizationService.t('Inventory'),
        'Add Medicine': LocalizationService.t('Add Medicine'),
        'Manual': LocalizationService.t('Manual'),
        'From Order': LocalizationService.t('From Order'),
        'From Prescription': LocalizationService.t('From Prescription'),
        'Safe': LocalizationService.t('Safe'),
        'Low': LocalizationService.t('Low'),
        'Critical': LocalizationService.t('Critical'),
        'Expired': LocalizationService.t('Expired'),
        'Days Left': LocalizationService.t('Days Left'),
        'Quantity': LocalizationService.t('Quantity'),
        'Reorder': LocalizationService.t('Reorder'),
        'Upload Prescription': LocalizationService.t('Upload Prescription'),
        'Quick order processing': LocalizationService.t('Quick order processing'),
        'Tap to Talk to Pharma AI': LocalizationService.t('Tap to Talk to Pharma AI'),
        'Listening...': LocalizationService.t('Listening...'),
        'Home': LocalizationService.t('Home'),
        'Orders': LocalizationService.t('Orders'),
        'AI Chat': LocalizationService.t('AI Chat'),
        'Emergency': LocalizationService.t('Emergency'),
        'Profile': LocalizationService.t('Profile'),
      };
    });

    // Optional: Fallback to LLM if key is not found in hardcoded map or for dynamic content
    if (LocalizationService.currentLanguage != 'English') {
      // We can still keep the LLM as a fallback or for dynamic data if needed,
      // but the core UI is now instant via hardcoded map.
    }
  }

  String t(String key) => _translatedStrings[key] ?? key;
  
  // Voice interaction state
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = "";

  void _listen() async {
    // Instead of internal logic, navigate to dedicated S2S page
    Navigator.pushNamed(context, '/s2s-voice');
  }

    final List<Widget> _pages = [
    const HomeContent(),
    const MedicinesListScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Added this line
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: t('Home')),
          BottomNavigationBarItem(icon: const Icon(Icons.medication_outlined), activeIcon: const Icon(Icons.medication), label: t('Medicines')),
          BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline), activeIcon: const Icon(Icons.chat_bubble), label: t('AI Chat')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: t('Profile')),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  String t(BuildContext context, String key) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    return state?.t(key) ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final displayName = user?.userMetadata?['name'] ?? 'User';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('user_profiles')
          .stream(primaryKey: ['id'])
          .eq('id', user?.id ?? ''),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.isNotEmpty == true ? snapshot.data!.first : null;
        final avatarUrl = profileData?['avatar_url'];
        final currentName = profileData?['full_name'] ?? displayName;

        return Scaffold(
          drawer: Drawer(
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(currentName),
                  accountEmail: Text(user?.email ?? ''),
                  currentAccountPicture: CircleAvatar(
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
                  ),
                  decoration: const BoxDecoration(color: Color(0xFF2196F3)),
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: Text(t(context, 'Orders')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my-orders');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(t(context, 'Terms & Conditions')),
                  onTap: () {
                    Navigator.pop(context);
                    // Add terms navigation if screen exists
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(t(context, 'About Us')),
                  onTap: () {
                    Navigator.pop(context);
                    // Add about navigation if screen exists
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(t(context, 'Profile')),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                const Spacer(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(t(context, 'Logout'), style: const TextStyle(color: Colors.red)),
                  onTap: () async {
                    await authService.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/language-selection', (route) => false);
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 80,
                floating: true,
                pinned: true,
                backgroundColor: const Color(0xFF2196F3),
                title: const Text('PharmaCo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => Navigator.pushNamed(context, '/medicine-search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {},
                  ),
                  ListenableBuilder(
                    listenable: CartService(),
                    builder: (context, child) {
                      final cartCount = CartService().items.length;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                            onPressed: () => Navigator.pushNamed(context, '/cart'),
                          ),
                          if (cartCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$cartCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t(context, 'Welcome')}, $currentName',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(context, 'Your Health, Our Priority'),
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      // Health Summary / Quick Actions
                      _buildQuickActionCard(
                        context,
                        title: t(context, 'Complete Your Health Profile'),
                        subtitle: t(context, 'Help us provide better care'),
                        icon: Icons.person_search,
                        color: Colors.teal,
                        onTap: () => Navigator.pushNamed(context, '/profile-completion'),
                      ),
                      const SizedBox(height: 16),
                      _buildQuickActionCard(
                        context,
                        title: t(context, 'Home Inventory'),
                        subtitle: t(context, 'Manage your medicine stock'),
                        icon: Icons.inventory_2_outlined,
                        color: Colors.orange,
                        onTap: () => Navigator.pushNamed(context, '/inventory'),
                      ),
                      const SizedBox(height: 32),
                      // Voice Assistant Section
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: (context.findAncestorStateOfType<_HomeScreenState>()! as _HomeScreenState)._listen,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AvatarGlow(
                                    animate: true,
                                    glowColor: const Color(0xFF673AB7),
                                    endRadius: 90.0,
                                    duration: const Duration(milliseconds: 2000),
                                    repeat: true,
                                    showTwoGlows: true,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF673AB7), Color(0xFF9575CD)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.mic,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t(context, 'Tap to Talk to Pharma AI'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF673AB7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              t(context, 'Ask about medicines or your health'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FadeInRight(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
