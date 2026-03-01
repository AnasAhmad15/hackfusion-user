import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

import '../widgets/admin_drawer.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({Key? key}) : super(key: key);

  @override
  _AdminUserManagementScreenState createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _medicalPartners = [];
  List<Map<String, dynamic>> _deliveryPartners = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final usersData = await _supabase
          .from('user_profiles')
          .select()
          .order('full_name', ascending: true);
      
      final partnersData = await _supabase
          .from('medical_partners')
          .select();

      final deliveryData = await _supabase
          .from('profiles')
          .select();
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersData);
          _medicalPartners = List<Map<String, dynamic>>.from(partnersData);
          _deliveryPartners = List<Map<String, dynamic>>.from(deliveryData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Admins'),
            Tab(text: 'Customers'),
            Tab(text: 'Medical Partners'),
            Tab(text: 'Delivery Partners'),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin-users'),
      body: _isLoading
          ? SkeletonLayouts.cardList()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_users),
                _buildUserList(_users.where((u) => u['role'] == 'admin').toList()),
                _buildUserList(_users.where((u) => u['role'] == 'user' || u['role'] == null).toList()),
                _buildUserList(_medicalPartners),
                _buildUserList(_deliveryPartners),
              ],
            ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> usersList) {
    if (usersList.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No users found',
        subtitle: 'No records match this category',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(PharmacoTokens.space16),
      itemCount: usersList.length,
      separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space12),
      itemBuilder: (context, index) {
        final user = usersList[index];
        final role = user['role']?.toString().toLowerCase() ?? 'user';
        final isAdmin = role == 'admin';
        final isPartner = user.containsKey('medical_name'); // Medical partner
        final isDriver = user.containsKey('vehicle_type'); // Delivery partner

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isAdmin 
                  ? Colors.red.withOpacity(0.1) 
                  : isPartner 
                      ? Colors.blue.withOpacity(0.1)
                      : isDriver 
                          ? Colors.purple.withOpacity(0.1)
                          : PharmacoTokens.primarySurface,
              child: Icon(
                isAdmin 
                    ? Icons.admin_panel_settings_rounded 
                    : isPartner 
                        ? Icons.local_pharmacy_rounded
                        : isDriver 
                            ? Icons.delivery_dining_rounded
                            : Icons.person_rounded,
                color: isAdmin 
                    ? Colors.red 
                    : isPartner 
                        ? Colors.blue
                        : isDriver 
                            ? Colors.purple
                            : PharmacoTokens.primaryBase,
              ),
            ),
            title: Text(
              user['full_name'] ?? user['medical_name'] ?? 'No Name', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email'] ?? 'No Email'),
                if (isPartner) Text('License: ${user['license_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
                if (isDriver) Text('Vehicle: ${user['vehicle_model'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(role, isPartner, isDriver).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getRoleColor(role, isPartner, isDriver)),
              ),
              child: Text(
                _getRoleLabel(role, isPartner, isDriver).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: _getRoleColor(role, isPartner, isDriver),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getRoleColor(String role, bool isPartner, bool isDriver) {
    if (role == 'admin') return Colors.red;
    if (isPartner) return Colors.blue;
    if (isDriver) return Colors.purple;
    return Colors.green;
  }

  String _getRoleLabel(String role, bool isPartner, bool isDriver) {
    if (role == 'admin') return 'Admin';
    if (isPartner) return 'Pharmacy';
    if (isDriver) return 'Driver';
    return 'Customer';
  }
}
