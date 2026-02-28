import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({Key? key}) : super(key: key);

  @override
  _AdminUserManagementScreenState createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('user_profiles')
          .select()
          .order('full_name', ascending: true);
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
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
      ),
      body: _isLoading
          ? SkeletonLayouts.cardList()
          : _users.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No users found',
                  subtitle: 'System users will appear here',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(PharmacoTokens.space16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space12),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isAdmin = user['role'] == 'admin';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin ? Colors.red.withOpacity(0.1) : PharmacoTokens.primarySurface,
                          child: Icon(
                            isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                            color: isAdmin ? Colors.red : PharmacoTokens.primaryBase,
                          ),
                        ),
                        title: Text(user['full_name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${user['email'] ?? 'No Email'} • Age: ${user['age']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isAdmin ? Colors.red : Colors.green).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isAdmin ? Colors.red : Colors.green),
                          ),
                          child: Text(
                            (user['role'] ?? 'user').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isAdmin ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
