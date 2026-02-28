import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../services/localization_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  int _totalUsers = 0;
  int _totalMedicines = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final ordersRes = await _supabase.from('orders').select('id, status');
      final usersRes = await _supabase.from('user_profiles').select('id');
      final medsRes = await _supabase.from('medicines').select('id');

      if (mounted) {
        setState(() {
          _totalOrders = ordersRes.length;
          _pendingOrders = ordersRes.where((o) => o['status'] == 'pending').length;
          _totalUsers = usersRes.length;
          _totalMedicines = medsRes.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              child: SkeletonLayouts.cardList(),
            )
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(PharmacoTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Overview',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: PharmacoTokens.weightBold,
                      ),
                    ),
                    const SizedBox(height: PharmacoTokens.space16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: PharmacoTokens.space16,
                      crossAxisSpacing: PharmacoTokens.space16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('Total Orders', _totalOrders.toString(), Icons.shopping_bag_rounded, Colors.blue),
                        _buildStatCard('Pending', _pendingOrders.toString(), Icons.pending_actions_rounded, Colors.orange),
                        _buildStatCard('Users', _totalUsers.toString(), Icons.people_rounded, Colors.green),
                        _buildStatCard('Medicines', _totalMedicines.toString(), Icons.medication_rounded, Colors.purple),
                      ],
                    ),
                    const SizedBox(height: PharmacoTokens.space32),
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: PharmacoTokens.weightBold,
                      ),
                    ),
                    const SizedBox(height: PharmacoTokens.space16),
                    _buildActionTile(
                      Icons.inventory_2_rounded,
                      'Manage Inventory',
                      'Add or update global medicines',
                      () {
                        Navigator.of(context).pushNamed('/admin-medicines');
                      },
                    ),
                    _buildActionTile(
                      Icons.list_alt_rounded,
                      'View All Orders',
                      'Monitor and update order status',
                      () {
                        Navigator.of(context).pushNamed('/admin-orders');
                      },
                    ),
                    _buildActionTile(
                      Icons.person_search_rounded,
                      'User Management',
                      'View and manage system users',
                      () {
                        Navigator.of(context).pushNamed('/admin-users');
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(PharmacoTokens.space16),
      decoration: BoxDecoration(
        color: PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: PharmacoTokens.shadowZ1(),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: PharmacoTokens.weightBold,
                  color: PharmacoTokens.neutral800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: PharmacoTokens.neutral500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: PharmacoTokens.space12),
      decoration: BoxDecoration(
        color: PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: PharmacoTokens.shadowZ1(),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(PharmacoTokens.space8),
          decoration: BoxDecoration(
            color: PharmacoTokens.primarySurface,
            borderRadius: PharmacoTokens.borderRadiusSmall,
          ),
          child: Icon(icon, color: PharmacoTokens.primaryBase),
        ),
        title: Text(title, style: const TextStyle(fontWeight: PharmacoTokens.weightSemiBold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
