import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';

import '../widgets/admin_drawer.dart';

class AdminOrderManagementScreen extends StatefulWidget {
  const AdminOrderManagementScreen({Key? key}) : super(key: key);

  @override
  _AdminOrderManagementScreenState createState() => _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState extends State<AdminOrderManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final response = await _supabase.from('orders').update({'status': newStatus}).eq('id', orderId).select();
      if (response.isEmpty) throw 'No order updated';
      
      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus')),
        );
      }
    } catch (e) {
      debugPrint('Update Order Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin-orders'),
      body: _isLoading
          ? SkeletonLayouts.cardList()
          : _orders.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No orders found',
                  subtitle: 'All customer orders will appear here',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(PharmacoTokens.space16),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space12),
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final date = DateTime.parse(order['created_at']);
                    final status = order['status'] ?? 'pending';

                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status).withOpacity(0.1),
                          child: Icon(Icons.receipt_long_rounded, color: _getStatusColor(status)),
                        ),
                        title: Text('Order #${order['id'].toString().substring(0, 8)}'),
                        subtitle: Text('${DateFormat('MMM dd, yyyy • HH:mm').format(date)} • ₹${order['total_amount']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getStatusColor(status)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ... (order['order_items'] as List).map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text('${item['name']} x ${item['quantity']}')),
                                      Text('₹${item['price']}'),
                                    ],
                                  ),
                                )).toList(),
                                const Divider(),
                                Text('Address: ${order['delivery_address'] ?? 'No address'}'),
                                const SizedBox(height: 16),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      if (status == 'pending')
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: ElevatedButton(
                                            onPressed: () => _updateOrderStatus(order['id'], 'preparing'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue, 
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(80, 36),
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ),
                                      if (status == 'preparing')
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: ElevatedButton(
                                            onPressed: () => _updateOrderStatus(order['id'], 'ready'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange, 
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(80, 36),
                                            ),
                                            child: const Text('Ready'),
                                          ),
                                        ),
                                      if (status != 'delivered' && status != 'cancelled' && status != 'completed')
                                        TextButton(
                                          onPressed: () => _updateOrderStatus(order['id'], 'cancelled'),
                                          child: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted':
      case 'preparing': return Colors.blue;
      case 'ready':
      case 'picked_up': return Colors.purple;
      case 'delivered':
      case 'completed': return Colors.green;
      case 'cancelled':
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}
