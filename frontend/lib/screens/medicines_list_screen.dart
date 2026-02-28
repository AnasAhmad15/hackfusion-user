import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/localization_service.dart';
import '../services/cart_service.dart';
import '../models/medicine_model.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_input.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';
import 'cart_screen.dart';
import 'medicine_detail_screen.dart';

class MedicinesListScreen extends StatefulWidget {
  const MedicinesListScreen({Key? key}) : super(key: key);

  @override
  _MedicinesListScreenState createState() => _MedicinesListScreenState();
}

class _MedicinesListScreenState extends State<MedicinesListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CartService _cartService = CartService();
  bool _isLoading = true;
  List<Medicine> _medicines = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchMedicines(),
      _cartService.fetchCart(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _fetchMedicines() async {
    try {
      final response = await _supabase.from('medicines').select();
      if (mounted) {
        final List<Medicine> allMedicines =
            (response as List).map((m) => Medicine.fromJson(m)).toList();

        final Map<String, Medicine> uniqueMedicines = {};
        for (var med in allMedicines) {
          final normalizedName = med.name.trim().toLowerCase();
          if (!uniqueMedicines.containsKey(normalizedName) ||
              med.price > uniqueMedicines[normalizedName]!.price) {
            uniqueMedicines[normalizedName] = med;
          }
        }

        setState(() {
          _medicines = uniqueMedicines.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMedicines = _medicines
        .where((m) =>
            m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.brand.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.t('Medicines')),
        actions: [
          ListenableBuilder(
            listenable: _cartService,
            builder: (context, _) {
              final count = _cartService.items.length;
              return IconButton(
                icon: Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  backgroundColor: PharmacoTokens.error,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                ).then((_) => setState(() {})),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(PharmacoTokens.space16),
            child: PharmacoSearchBar(
              hint: LocalizationService.t('Search medicines...'),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(PharmacoTokens.space16),
                    child: SkeletonLayouts.cardList(),
                  )
                : filteredMedicines.isEmpty
                    ? EmptyState(
                        icon: Icons.medication_outlined,
                        title: LocalizationService.t('No medicines found'),
                        subtitle: 'Try a different search term',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PharmacoTokens.space16,
                        ),
                        itemCount: filteredMedicines.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: PharmacoTokens.space12),
                        itemBuilder: (context, index) {
                          final med = filteredMedicines[index];
                          return _MedicineListTile(
                            medicine: med,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MedicineDetailScreen(medicine: med),
                              ),
                            ).then((_) => setState(() {})),
                            onAddToCart: () async {
                              await _cartService.addToCart(med);
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${med.name} ${LocalizationService.t('added to cart')}',
                                    ),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MedicineListTile extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _MedicineListTile({
    required this.medicine,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border:
            isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: PharmacoTokens.borderRadiusCard,
        child: InkWell(
          onTap: onTap,
          borderRadius: PharmacoTokens.borderRadiusCard,
          child: Padding(
            padding: const EdgeInsets.all(PharmacoTokens.space12),
            child: Row(
              children: [
                // Icon
                Hero(
                  tag: 'med_${medicine.id}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PharmacoTokens.primarySurface,
                      borderRadius: PharmacoTokens.borderRadiusSmall,
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: PharmacoTokens.primaryBase,
                    ),
                  ),
                ),
                const SizedBox(width: PharmacoTokens.space12),

                // Name + brand
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${medicine.brand} • ${medicine.category}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: PharmacoTokens.neutral500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PharmacoTokens.space8),

                // Price
                Text(
                  '₹${medicine.price}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: PharmacoTokens.primaryBase,
                  ),
                ),
                const SizedBox(width: PharmacoTokens.space4),

                // Add to cart
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  color: PharmacoTokens.primaryBase,
                  onPressed: onAddToCart,
                  constraints: const BoxConstraints(
                    minWidth: PharmacoTokens.minTapTarget,
                    minHeight: PharmacoTokens.minTapTarget,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
