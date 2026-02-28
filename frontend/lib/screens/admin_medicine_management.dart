import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

class AdminMedicineManagement extends StatefulWidget {
  const AdminMedicineManagement({Key? key}) : super(key: key);

  @override
  _AdminMedicineManagementState createState() => _AdminMedicineManagementState();
}

class _AdminMedicineManagementState extends State<AdminMedicineManagement> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _medicines = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('medicines')
          .select()
          .order('name', ascending: true);
      
      if (mounted) {
        setState(() {
          _medicines = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditMedicineDialog([Map<String, dynamic>? medicine]) {
    final isEditing = medicine != null;
    final nameController = TextEditingController(text: medicine?['name'] ?? '');
    final brandController = TextEditingController(text: medicine?['brand'] ?? '');
    final priceController = TextEditingController(text: medicine?['price']?.toString() ?? '');
    final stockController = TextEditingController(text: medicine?['stock']?.toString() ?? '');
    final categoryController = TextEditingController(text: medicine?['category'] ?? 'General');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Medicine' : 'Add New Medicine'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Medicine Name'),
              ),
              TextField(
                controller: brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
              ),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Initial Stock'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameController.text,
                'brand': brandController.text,
                'price': double.tryParse(priceController.text) ?? 0.0,
                'stock': int.tryParse(stockController.text) ?? 0,
                'category': categoryController.text,
                'is_active': true,
              };

              try {
                if (isEditing) {
                  await _supabase.from('medicines').update(data).eq('id', medicine['id']);
                } else {
                  await _supabase.from('medicines').insert(data);
                }
                Navigator.pop(context);
                _fetchMedicines();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditMedicineDialog(),
        backgroundColor: PharmacoTokens.primaryBase,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? SkeletonLayouts.cardList()
          : _medicines.isEmpty
              ? const EmptyState(
                  icon: Icons.medication_rounded,
                  title: 'No medicines found',
                  subtitle: 'Add medicines to the platform catalog',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(PharmacoTokens.space16),
                  itemCount: _medicines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space12),
                  itemBuilder: (context, index) {
                    final med = _medicines[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: PharmacoTokens.primarySurface,
                          child: Icon(Icons.medication_rounded, color: PharmacoTokens.primaryBase),
                        ),
                        title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${med['brand']} • ₹${med['price']} • Stock: ${med['stock']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showAddEditMedicineDialog(med),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Medicine'),
                                    content: const Text('Are you sure you want to delete this medicine?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _supabase.from('medicines').delete().eq('id', med['id']);
                                  _fetchMedicines();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
