import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';

class AdminDrawer extends StatelessWidget {
  final String currentRoute;

  const AdminDrawer({Key? key, required this.currentRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: PharmacoTokens.primaryBase),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings_rounded, color: PharmacoTokens.primaryBase, size: 40),
            ),
            accountName: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.email ?? 'admin@pharmaco.com'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            route: '/admin-dashboard',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.inventory_2_rounded,
            title: 'Inventory Management',
            route: '/admin-medicines',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.list_alt_rounded,
            title: 'Order Management',
            route: '/admin-orders',
          ),
          _buildDrawerItem(
            context,
            icon: Icons.people_alt_rounded,
            title: 'User Management',
            route: '/admin-users',
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await supabase.auth.signOut();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          const SizedBox(height: PharmacoTokens.space16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, {required IconData icon, required String title, required String route}) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? PharmacoTokens.primaryBase : PharmacoTokens.neutral600),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? PharmacoTokens.primaryBase : PharmacoTokens.neutral800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: PharmacoTokens.primarySurface,
      onTap: () {
        if (isSelected) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
