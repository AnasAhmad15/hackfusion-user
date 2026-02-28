import 'package:flutter/material.dart';
import '../models/medicine_model.dart';
import '../services/cart_service.dart';
import '../services/medicine_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_input.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({Key? key}) : super(key: key);

  @override
  _MedicineSearchScreenState createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final _medicineService = MedicineService();
  final _cartService = CartService();
  List<Medicine> _medicines = [];
  List<Medicine> _filteredMedicines = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    try {
      final List<Medicine> allMedicines = await _medicineService.getMedicines();

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
        _filteredMedicines = _medicines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterMedicines(String query) {
    final filtered = _medicines.where((medicine) {
      return medicine.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    setState(() => _filteredMedicines = filtered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Medicines')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'search_cart_fab',
        onPressed: () => Navigator.of(context).pushNamed('/cart'),
        backgroundColor: PharmacoTokens.primaryBase,
        foregroundColor: PharmacoTokens.white,
        child: const Icon(Icons.shopping_cart_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PharmacoTokens.space16),
            child: PharmacoSearchBar(
              hint: 'Search medicines...',
              onChanged: _filterMedicines,
            ),
          ),
          Expanded(child: _buildMedicineList(theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildMedicineList(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(PharmacoTokens.space16),
        child: SkeletonLayouts.cardList(),
      );
    }

    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: _error,
        actionLabel: 'Retry',
        onAction: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _fetchMedicines();
        },
      );
    }

    if (_filteredMedicines.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No medicines found',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space16),
      itemCount: _filteredMedicines.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: PharmacoTokens.space8),
      itemBuilder: (context, index) {
        final medicine = _filteredMedicines[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
            borderRadius: PharmacoTokens.borderRadiusCard,
            boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
            border:
                isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: PharmacoTokens.space16,
              vertical: PharmacoTokens.space4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: PharmacoTokens.borderRadiusCard,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PharmacoTokens.primarySurface,
                borderRadius: PharmacoTokens.borderRadiusSmall,
              ),
              child: const Icon(
                Icons.medication_rounded,
                color: PharmacoTokens.primaryBase,
              ),
            ),
            title: Text(medicine.name, style: theme.textTheme.titleSmall),
            subtitle: Text(
              '₹${medicine.price.toStringAsFixed(2)} • Stock: ${medicine.stock}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: PharmacoTokens.neutral500,
              ),
            ),
            trailing: SizedBox(
              height: PharmacoTokens.buttonHeightSmall,
              child: ElevatedButton.icon(
                onPressed: () {
                  _cartService.addToCart(medicine);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${medicine.name} added to cart'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ),
          ),
        );
      },
    );
  }
}
