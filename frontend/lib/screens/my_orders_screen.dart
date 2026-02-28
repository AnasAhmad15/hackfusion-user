import 'package:pharmaco_frontend/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  _MyOrdersScreenState createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('orders')
          .select('*, order_items(*), medical_partners!fk_orders_pharmacy(*), profiles(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = (response as List).map((o) => Order.fromJson(o)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return PharmacoTokens.warning;
      case 'accepted':
      case 'picked_up': return PharmacoTokens.primaryBase;
      case 'delivered':
      case 'completed': return PharmacoTokens.success;
      case 'cancelled': return PharmacoTokens.error;
      default: return PharmacoTokens.neutral400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(LocalizationService.t('My Orders'))),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              child: SkeletonLayouts.cardList(),
            )
          : _orders.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: LocalizationService.t('You have no past orders.'),
                  subtitle: 'Your order history will appear here',
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(PharmacoTokens.space16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space12),
                    itemBuilder: (context, index) => _OrderCard(
                      order: _orders[index],
                      theme: theme,
                      statusColor: _getStatusColor(_orders[index].status),
                    ),
                  ),
                ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final ThemeData theme;
  final Color statusColor;

  const _OrderCard({required this.order, required this.theme, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: PharmacoTokens.space16,
            vertical: PharmacoTokens.space4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            PharmacoTokens.space16, 0, PharmacoTokens.space16, PharmacoTokens.space16,
          ),
          shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_basket_rounded, color: statusColor, size: 22),
          ),
          title: Text(
            '${LocalizationService.t('Order')} #${order.id.substring(0, 8)}',
            style: theme.textTheme.titleSmall,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500),
              ),
              const SizedBox(height: PharmacoTokens.space4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: PharmacoTokens.borderRadiusSmall,
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: PharmacoTokens.weightSemiBold,
                      ),
                    ),
                  ),
                  const SizedBox(width: PharmacoTokens.space8),
                  Text('₹${order.totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(color: PharmacoTokens.primaryBase)),
                ],
              ),
            ],
          ),
          children: [
            const Divider(),
            const SizedBox(height: PharmacoTokens.space8),
            // Items
            Text(LocalizationService.t('Order Items'), style: theme.textTheme.titleSmall),
            const SizedBox(height: PharmacoTokens.space8),
            ...?order.items?.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: PharmacoTokens.space4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${item.name} × ${item.quantity}', style: theme.textTheme.bodySmall),
                  Text('₹${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: PharmacoTokens.weightMedium)),
                ],
              ),
            )),
            const Divider(height: PharmacoTokens.space16),

            // Payment + Patient
            _row(LocalizationService.t('Payment Status'), (order.paymentStatus ?? 'pending').toUpperCase(),
                color: (order.paymentStatus == 'successful') ? PharmacoTokens.success : PharmacoTokens.warning),
            _row(LocalizationService.t('Payment Method'), order.paymentMethod.toUpperCase()),
            _row(LocalizationService.t('Patient ID'), order.patientId ?? 'N/A'),
            _row(LocalizationService.t('Patient Age'), order.patientAge?.toString() ?? 'N/A'),
            _row(LocalizationService.t('Patient Gender'), order.patientGender ?? 'N/A'),

            const Divider(height: PharmacoTokens.space16),
            Text(LocalizationService.t('Partner Details'),
                style: theme.textTheme.labelLarge?.copyWith(color: PharmacoTokens.primaryBase)),
            const SizedBox(height: PharmacoTokens.space8),

            if (order.pharmacy != null) ...[
              _partnerRow(Icons.local_pharmacy_rounded, order.pharmacy?['medical_name'] ?? 'Pharmacy Assigned'),
              _partnerRow(Icons.location_on_outlined, order.pharmacy?['address'] ?? 'N/A'),
            ] else
              _partnerRow(Icons.local_pharmacy_rounded, LocalizationService.t('Waiting for Pharmacy...')),

            const SizedBox(height: PharmacoTokens.space4),
            if (order.deliveryPartner != null) ...[
              _partnerRow(Icons.person_pin_rounded, order.deliveryPartner?['full_name'] ?? 'Delivery Partner Assigned'),
              _partnerRow(Icons.phone_android_rounded, order.deliveryPartner?['phone'] ?? 'N/A'),
            ] else
              _partnerRow(Icons.person_pin_rounded, LocalizationService.t('Finding Delivery Partner...')),

            const Divider(height: PharmacoTokens.space16),
            _row(LocalizationService.t('Subtotal'), '₹${(order.totalAmount - order.serviceFee - order.deliveryFee).toStringAsFixed(2)}'),
            _row(LocalizationService.t('Service Fee'), '₹${order.serviceFee.toStringAsFixed(2)}'),
            _row(LocalizationService.t('Delivery Fee'), '₹${order.deliveryFee.toStringAsFixed(2)}'),
            _row(LocalizationService.t('Total Amount'), '₹${order.totalAmount.toStringAsFixed(2)}',
                color: PharmacoTokens.primaryBase, isBold: true),

            const SizedBox(height: PharmacoTokens.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${LocalizationService.t('Address')}: ',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: PharmacoTokens.weightSemiBold)),
                const SizedBox(width: PharmacoTokens.space8),
                Expanded(child: Text(order.deliveryAddress, style: theme.textTheme.labelSmall)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.neutral500)),
          Text(value, style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isBold ? PharmacoTokens.weightBold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Widget _partnerRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: PharmacoTokens.neutral400),
          const SizedBox(width: PharmacoTokens.space8),
          Expanded(child: Text(text, style: theme.textTheme.labelSmall)),
        ],
      ),
    );
  }
}
