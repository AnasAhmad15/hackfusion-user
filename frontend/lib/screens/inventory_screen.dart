import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _inventory = [];

  int _totalMedicines = 0;
  int _criticalMedicines = 0;
  int _expiringSoon = 0;
  double _avgDaysLeft = 0;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('user_inventory')
          .select()
          .eq('user_id', userId)
          .order('expiry_date', ascending: true);

      if (mounted) {
        setState(() {
          _inventory = List<Map<String, dynamic>>.from(data);
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching inventory: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    _totalMedicines = _inventory.length;
    _criticalMedicines = 0;
    _expiringSoon = 0;
    double totalDays = 0;
    int itemsWithDays = 0;

    final now = DateTime.now();
    for (var item in _inventory) {
      if (item['expiry_date'] == null) {
        _criticalMedicines++; // Or handle as per business logic
        continue;
      }
      final expiryDate = DateTime.parse(item['expiry_date']);
      final daysLeft = expiryDate.difference(now).inDays;
      if (daysLeft <= 3) _criticalMedicines++;
      else if (daysLeft <= 7) _expiringSoon++;
      if (daysLeft > 0) {
        totalDays += daysLeft;
        itemsWithDays++;
      }
    }
    _avgDaysLeft = itemsWithDays > 0 ? totalDays / itemsWithDays : 0;
  }

  String _getStatusText(int daysLeft) {
    if (daysLeft < 0) return LocalizationService.t('Expired');
    if (daysLeft <= 3) return LocalizationService.t('Critical');
    if (daysLeft <= 7) return LocalizationService.t('Low');
    return LocalizationService.t('Safe');
  }

  Color _getStatusColor(int daysLeft) {
    if (daysLeft < 0) return PharmacoTokens.neutral600;
    if (daysLeft <= 3) return PharmacoTokens.error;
    if (daysLeft <= 7) return PharmacoTokens.warning;
    return PharmacoTokens.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.t('Home Inventory')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchInventory),
        ],
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              child: SkeletonLayouts.cardList(),
            )
          : RefreshIndicator(
              onRefresh: _fetchInventory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(PharmacoTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(theme),
                    const SizedBox(height: PharmacoTokens.space24),
                    Text(LocalizationService.t('Medicine List View'), style: theme.textTheme.headlineMedium),
                    const SizedBox(height: PharmacoTokens.space16),
                    _inventory.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Your inventory is empty',
                            subtitle: 'Add medicines to track expiry dates',
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _inventory.length,
                            separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space12),
                            itemBuilder: (context, index) => _buildMedicineCard(_inventory[index], theme, isDark),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add_rounded),
        label: Text(LocalizationService.t('Add Medicine')),
        backgroundColor: PharmacoTokens.primaryBase,
        foregroundColor: PharmacoTokens.white,
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(PharmacoTokens.space20),
      decoration: BoxDecoration(
        color: PharmacoTokens.primaryBase,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: PharmacoTokens.shadowZ2(),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(LocalizationService.t('Total'), _totalMedicines.toString(), Icons.medication_rounded),
              _buildStatItem(LocalizationService.t('Critical'), _criticalMedicines.toString(), Icons.warning_amber_rounded,
                  color: Colors.redAccent),
            ],
          ),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: PharmacoTokens.space32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(LocalizationService.t('Expiring'), _expiringSoon.toString(), Icons.timer_outlined,
                  color: Colors.orangeAccent),
              _buildStatItem(LocalizationService.t('Avg Days'), _avgDaysLeft.toStringAsFixed(0), Icons.calendar_today_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color color = Colors.white}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: PharmacoTokens.space8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: PharmacoTokens.weightBold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> item, ThemeData theme, bool isDark) {
    final String? expiryDateStr = item['expiry_date'];
    final expiryDate = expiryDateStr != null ? DateTime.parse(expiryDateStr) : null;
    final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : -1;
    final statusColor = _getStatusColor(daysLeft);
    final statusText = _getStatusText(daysLeft);

    return Container(
      padding: const EdgeInsets.all(PharmacoTokens.space16),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(PharmacoTokens.space12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medication_rounded, color: statusColor, size: 26),
              ),
              const SizedBox(width: PharmacoTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['medicine_name'], style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text('${LocalizationService.t('Quantity')}: ${item['quantity']}',
                        style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
                    Text('${LocalizationService.t('Daily Usage')}: ${item['daily_usage']}',
                        style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
                    Text('${LocalizationService.t('Expiry')}: ${expiryDate != null ? DateFormat('yyyy-MM-dd').format(expiryDate) : LocalizationService.t('Not Set')}',
                        style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.neutral500)),
                  ],
                ),
              ),
              _buildStatusIndicator(statusText, statusColor, theme),
            ],
          ),
          const Divider(height: PharmacoTokens.space24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(expiryDate != null ? '$daysLeft ${LocalizationService.t('Days Left')}' : LocalizationService.t('No Expiry'),
                  style: theme.textTheme.titleSmall?.copyWith(color: statusColor)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: PharmacoTokens.primaryBase,
                    iconSize: 20,
                    onPressed: () => _editMedicine(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: PharmacoTokens.error,
                    iconSize: 20,
                    onPressed: () => _deleteMedicine(item['id']),
                  ),
                  SizedBox(
                    height: 32,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: ElevatedButton(
                        onPressed: () => _reorderMedicine(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PharmacoTokens.success,
                          foregroundColor: PharmacoTokens.white,
                          padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space8),
                          shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusSmall),
                          minimumSize: Size.zero,
                        ),
                        child: Text(LocalizationService.t('Reorder'), style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space8, vertical: PharmacoTokens.space4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PharmacoTokens.radiusFull),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: PharmacoTokens.weightSemiBold)),
        ],
      ),
    );
  }

  void _showAddOptions() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + PharmacoTokens.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: PharmacoTokens.space12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: PharmacoTokens.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: PharmacoTokens.space16),
              Text(LocalizationService.t('Add Medicine'), style: theme.textTheme.headlineMedium),
              const SizedBox(height: PharmacoTokens.space24),
              _buildAddOption(Icons.edit_note_rounded, LocalizationService.t('Manual'), () {
                Navigator.pop(context);
                _showAddMedicineForm('manual');
              }),
              _buildAddOption(Icons.description_outlined, LocalizationService.t('From Prescription'), () {
                Navigator.pop(context);
                _processPrescription();
              }),
              _buildAddOption(Icons.camera_alt_outlined, LocalizationService.t('Scan Tablet'), () {
                Navigator.pop(context);
                _scanTablet();
              }),
              const SizedBox(height: PharmacoTokens.space24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPrescription() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$fileName';

      await _supabase.storage.from('prescriptions').upload(
            filePath,
            File(image.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage.from('prescriptions').getPublicUrl(filePath);

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/process_prescription_inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'image_url': imageUrl}),
      ).timeout(const Duration(minutes: 3));

      final result = json.decode(response.body);

      if (result['success'] == true) {
        final List<dynamic> medications = result['raw_data']?['data']?['prescription']?['medications'] ?? [];
        if (medications.isNotEmpty) {
          _showMultiMedicineVerification(medications);
        } else {
          _showAddMedicineForm('prescription', initialData: {
            'name': result['medicines'].isNotEmpty ? result['medicines'][0] : '',
            'quantity': 10,
            'usage': 1.0,
          });
        }
      } else {
        final errorMessage = result['error'] ?? 'Unknown error occurred';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Processing failed: $errorMessage')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanTablet() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String rawOcrText = recognizedText.text;
      await textRecognizer.close();

      if (rawOcrText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.t('No text detected. Please try a clearer photo.'))),
        );
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/extract_medicine_name'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'ocr_text': rawOcrText}),
      );

      String detectedName = "";
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        detectedName = result['medicine_name'] ?? "Unknown";
      }

      _showAddMedicineForm('tablet_scan', initialData: {
        'name': detectedName == "Unknown" ? "" : detectedName,
        'quantity': 10,
        'usage': 1.0,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanning failed: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddMedicineForm(String source, {Map<String, dynamic>? initialData}) {
    final theme = Theme.of(context);
    final nameController = TextEditingController(text: initialData?['name'] ?? '');
    final quantityController = TextEditingController(text: initialData?['quantity']?.toString() ?? '');
    final usageController = TextEditingController(text: initialData?['usage']?.toString() ?? '1.0');
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: PharmacoTokens.space16,
            right: PharmacoTokens.space16,
            top: PharmacoTokens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${LocalizationService.t('Add Medicine')} ($source)', style: theme.textTheme.headlineMedium),
              const SizedBox(height: PharmacoTokens.space16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: LocalizationService.t('Medicine Name'),
                  prefixIcon: const Icon(Icons.medication_outlined, color: PharmacoTokens.primaryBase),
                ),
              ),
              const SizedBox(height: PharmacoTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: LocalizationService.t('Quantity'),
                        prefixIcon: const Icon(Icons.numbers_rounded, color: PharmacoTokens.primaryBase),
                      ),
                    ),
                  ),
                  const SizedBox(width: PharmacoTokens.space12),
                  Expanded(
                    child: TextField(
                      controller: usageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: LocalizationService.t('Daily Usage'),
                        prefixIcon: const Icon(Icons.schedule_rounded, color: PharmacoTokens.primaryBase),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PharmacoTokens.space12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: PharmacoTokens.primarySurface,
                    borderRadius: PharmacoTokens.borderRadiusSmall,
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: PharmacoTokens.primaryBase),
                ),
                title: Text(LocalizationService.t('Expiry Date')),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setModalState(() => selectedDate = date);
                },
              ),
              const SizedBox(height: PharmacoTokens.space24),
              PharmacoButton(
                label: LocalizationService.t('Save'),
                onPressed: () async {
                  if (nameController.text.isEmpty || quantityController.text.isEmpty) return;
                  try {
                    final userId = _supabase.auth.currentUser?.id;
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    await _supabase.from('user_inventory').insert({
                      'user_id': userId,
                      'medicine_name': nameController.text,
                      'quantity': int.parse(quantityController.text),
                      'daily_usage': double.parse(usageController.text),
                      'expiry_date': selectedDate.toIso8601String().split('T')[0],
                      'added_from': source,
                    });
                    
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _fetchInventory();
                    
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(LocalizationService.t('Medicine added successfully')))
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
              const SizedBox(height: PharmacoTokens.space16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: PharmacoTokens.primaryBase),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded, color: PharmacoTokens.neutral400),
      onTap: onTap,
    );
  }

  void _showMultiMedicineVerification(List<dynamic> medications) {
    final theme = Theme.of(context);
    List<Map<String, dynamic>> itemsToVerify = medications.map((m) {
      String freq = (m['frequency'] ?? '1').toString().toLowerCase();
      double usage = 1.0;
      if (freq.contains('bd') || freq.contains('twice') || freq.contains('1-0-1')) usage = 2.0;
      else if (freq.contains('tid') || freq.contains('thrice') || freq.contains('1-1-1')) usage = 3.0;
      else if (freq.contains('qid')) usage = 4.0;

      return {
        'name': m['name'] ?? m['medicine_name'] ?? 'Unknown',
        'quantity': 10,
        'usage': usage,
        'expiry': DateTime.now().add(const Duration(days: 180)),
        'selected': true,
      };
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(PharmacoTokens.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(LocalizationService.t('Verify Medications'), style: theme.textTheme.headlineMedium),
              const SizedBox(height: PharmacoTokens.space16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itemsToVerify.length,
                  separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space8),
                  itemBuilder: (context, index) {
                    final item = itemsToVerify[index];
                    return Container(
                      padding: const EdgeInsets.all(PharmacoTokens.space12),
                      decoration: BoxDecoration(
                        color: PharmacoTokens.neutral100,
                        borderRadius: PharmacoTokens.borderRadiusCard,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: item['selected'],
                                onChanged: (val) => setModalState(() => item['selected'] = val),
                                activeColor: PharmacoTokens.primaryBase,
                              ),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Medicine Name'),
                                  controller: TextEditingController(text: item['name']),
                                  onChanged: (val) => item['name'] = val,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 48),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: LocalizationService.t('Usage'),
                                    isDense: true,
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  controller: TextEditingController(text: item['usage'].toString()),
                                  onChanged: (val) => item['usage'] = double.tryParse(val) ?? 1.0,
                                ),
                              ),
                              const SizedBox(width: PharmacoTokens.space8),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: LocalizationService.t('Quantity'),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: item['quantity'].toString()),
                                  onChanged: (val) => item['quantity'] = int.tryParse(val) ?? 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: PharmacoTokens.space8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 48),
                              Text(LocalizationService.t('Expiry Date'), style: theme.textTheme.labelSmall),
                              TextButton(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: item['expiry'],
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                  );
                                  if (date != null) setModalState(() => item['expiry'] = date);
                                },
                                child: Text(DateFormat('yyyy-MM-dd').format(item['expiry'])),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: PharmacoTokens.space16),
              PharmacoButton(
                label: LocalizationService.t('Add Selected'),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  Navigator.pop(context);
                  try {
                    final userId = _supabase.auth.currentUser?.id;
                    for (var item in itemsToVerify) {
                      if (item['selected']) {
                        await _supabase.from('user_inventory').insert({
                          'user_id': userId,
                          'medicine_name': item['name'],
                          'quantity': item['quantity'],
                          'daily_usage': item['usage'],
                          'expiry_date': item['expiry'].toIso8601String().split('T')[0],
                          'added_from': 'prescription',
                        });
                      }
                    }
                    _fetchInventory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LocalizationService.t('Inventory Updated')), behavior: SnackBarBehavior.floating),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editMedicine(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final nameController = TextEditingController(text: item['medicine_name']);
    final quantityController = TextEditingController(text: item['quantity'].toString());
    final usageController = TextEditingController(text: item['daily_usage'].toString());
    DateTime selectedDate = item['expiry_date'] != null 
        ? DateTime.parse(item['expiry_date']) 
        : DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: PharmacoTokens.space16,
            right: PharmacoTokens.space16,
            top: PharmacoTokens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LocalizationService.t('Edit Medicine'), style: theme.textTheme.headlineMedium),
              const SizedBox(height: PharmacoTokens.space16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: LocalizationService.t('Medicine Name'),
                  prefixIcon: const Icon(Icons.medication_outlined, color: PharmacoTokens.primaryBase),
                ),
              ),
              const SizedBox(height: PharmacoTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: LocalizationService.t('Quantity'),
                        prefixIcon: const Icon(Icons.numbers_rounded, color: PharmacoTokens.primaryBase),
                      ),
                    ),
                  ),
                  const SizedBox(width: PharmacoTokens.space12),
                  Expanded(
                    child: TextField(
                      controller: usageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: LocalizationService.t('Daily Usage'),
                        prefixIcon: const Icon(Icons.schedule_rounded, color: PharmacoTokens.primaryBase),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PharmacoTokens.space12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: PharmacoTokens.primarySurface,
                    borderRadius: PharmacoTokens.borderRadiusSmall,
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: PharmacoTokens.primaryBase),
                ),
                title: Text(LocalizationService.t('Expiry Date')),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setModalState(() => selectedDate = date);
                },
              ),
              const SizedBox(height: PharmacoTokens.space24),
              PharmacoButton(
                label: LocalizationService.t('Save'),
                onPressed: () async {
                  if (nameController.text.isEmpty || quantityController.text.isEmpty) return;
                  try {
                    await _supabase.from('user_inventory').update({
                      'medicine_name': nameController.text,
                      'quantity': int.parse(quantityController.text),
                      'daily_usage': double.parse(usageController.text),
                      'expiry_date': selectedDate.toIso8601String().split('T')[0],
                    }).eq('id', item['id']);
                    Navigator.pop(context);
                    _fetchInventory();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
              const SizedBox(height: PharmacoTokens.space16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
        title: Text(LocalizationService.t('Confirm')),
        content: Text(LocalizationService.t('Are you sure you want to delete this item?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(LocalizationService.t('Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocalizationService.t('Delete'), style: const TextStyle(color: PharmacoTokens.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.from('user_inventory').delete().eq('id', id);
      _fetchInventory();
    }
  }

  void _reorderMedicine(Map<String, dynamic> item) {
    Navigator.pushNamed(context, '/medicine-search', arguments: item['medicine_name']);
  }
}
