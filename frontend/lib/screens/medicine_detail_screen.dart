import 'package:flutter/material.dart';
import '../models/medicine_model.dart';
import '../services/cart_service.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetailScreen({Key? key, required this.medicine}) : super(key: key);

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final CartService _cartService = CartService();
  bool _isAdding = false;

  Future<void> _handleAddToCart() async {
    setState(() => _isAdding = true);
    await _cartService.addToCart(widget.medicine);
    if (mounted) {
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.medicine.name} ${LocalizationService.t('added to cart')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final med = widget.medicine;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar with Hero Icon ───
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: PharmacoTokens.primarySurface,
                child: Center(
                  child: Hero(
                    tag: 'med_${med.id}',
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: PharmacoTokens.white,
                        borderRadius: PharmacoTokens.borderRadiusCard,
                        boxShadow: PharmacoTokens.shadowZ1(),
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        size: 48,
                        color: PharmacoTokens.primaryBase,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Details ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med.name, style: theme.textTheme.headlineLarge),
                            const SizedBox(height: PharmacoTokens.space4),
                            Text(
                              med.brand,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: PharmacoTokens.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${med.price}',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: PharmacoTokens.primaryBase,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PharmacoTokens.space20),

                  // Prescription badge
                  if (med.prescriptionRequired)
                    Container(
                      padding: const EdgeInsets.all(PharmacoTokens.space12),
                      decoration: BoxDecoration(
                        color: PharmacoTokens.warningLight,
                        borderRadius: PharmacoTokens.borderRadiusMedium,
                        border: Border.all(
                          color: PharmacoTokens.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: PharmacoTokens.warning),
                          const SizedBox(width: PharmacoTokens.space12),
                          Expanded(
                            child: Text(
                              'Prescription required for this medicine',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: PharmacoTokens.warning,
                                fontWeight: PharmacoTokens.weightMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: PharmacoTokens.space20),

                  // About section
                  Text('About Medicine', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: PharmacoTokens.space8),
                  Text(
                    med.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: PharmacoTokens.neutral500,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: PharmacoTokens.space20),

                  // Details
                  _DetailRow(
                    label: 'Category',
                    value: med.category,
                    theme: theme,
                  ),
                  _DetailRow(
                    label: 'Stock Status',
                    value: med.stock > 0
                        ? 'In Stock (${med.stock})'
                        : 'Out of Stock',
                    valueColor: med.stock > 0
                        ? PharmacoTokens.success
                        : PharmacoTokens.error,
                    theme: theme,
                  ),
                  _DetailRow(
                    label: 'Min Order',
                    value: '${med.minOrderQuantity} units',
                    theme: theme,
                  ),

                  // Bottom spacer for the button
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(PharmacoTokens.space16),
        decoration: BoxDecoration(
          color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
          boxShadow: PharmacoTokens.shadowZ2(),
        ),
        child: SafeArea(
          child: PharmacoButton(
            label: 'Add to Cart',
            icon: Icons.add_shopping_cart_rounded,
            onPressed: _isAdding ? null : _handleAddToCart,
            isLoading: _isAdding,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final ThemeData theme;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PharmacoTokens.space8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: PharmacoTokens.neutral500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: PharmacoTokens.weightSemiBold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
