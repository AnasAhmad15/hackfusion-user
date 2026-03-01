import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cart_service.dart';
import '../services/localization_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  final _supabase = Supabase.instance.client;
  final _storageService = StorageService();
  final _picker = ImagePicker();

  late Razorpay _razorpay;
  bool _isLoading = true;
  bool _isProcessing = false;
  double _walletBalance = 0.0;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadData();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    // Listen to changes in CartService (which now handles prescription state)
    _cartService.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _processCheckout('razorpay', referenceId: response.paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External Wallet: ${response.walletName}')));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _cartService.fetchCart(),
      _fetchProfileAndWallet(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProfileAndWallet() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profileRes = await _supabase.from('user_profiles').select().eq('id', userId).single();
      final walletRes = await _supabase.from('wallets').select('balance').eq('user_id', userId).maybeSingle();

      if (mounted) {
        _profileData = profileRes;
        final address = _profileData?['address'];
        final lat = _profileData?['latitude'];
        final lng = _profileData?['longitude'];

        if ((address == null || address.toString().trim().isEmpty || address.toString() == 'No address set in profile') && lat != null && lng != null) {
          final syncedAddress = await LocationService.syncUserAddress(userId, lat: lat, lng: lng);
          if (mounted && syncedAddress != null) {
            setState(() => _profileData?['address'] = syncedAddress);
          }
        }
        _walletBalance = walletRes != null ? (walletRes['balance'] as num).toDouble() : 0.0;
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  Future<void> _uploadPrescription() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final url = await _storageService.uploadPrescription(image);
      await _cartService.setPrescriptionUrl(url);
      
      if (mounted) {
        if (_cartService.validationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cartService.validationError!),
              backgroundColor: PharmacoTokens.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prescription uploaded and validated!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: PharmacoTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(LocalizationService.t('My Cart'))),
        body: Padding(
          padding: const EdgeInsets.all(PharmacoTokens.space16),
          child: SkeletonLayouts.cardList(),
        ),
      );
    }

    final cartItems = _cartService.items;

    return Scaffold(
      appBar: AppBar(title: Text(LocalizationService.t('My Cart'))),
      body: cartItems.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: LocalizationService.t('Your cart is empty'),
              subtitle: 'Browse medicines and add them to your cart',
              actionLabel: 'Browse Medicines',
              onAction: () => Navigator.of(context).pushNamed('/medicines'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(PharmacoTokens.space16),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: PharmacoTokens.space12),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _CartItemCard(
                        item: item,
                        isDark: isDark,
                        theme: theme,
                        onQuantityChanged: (newQty) async {
                          await _cartService.updateQuantity(item.medicine.id, newQty);
                          setState(() {});
                        },
                        onRemove: () async {
                          await _cartService.removeFromCart(item.medicine.id);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
                _buildCheckoutSection(theme, isDark),
              ],
            ),
    );
  }

  Widget _buildCheckoutSection(ThemeData theme, bool isDark) {
    final bool requiresPrescription = _cartService.requiresPrescription;
    final bool allValidated = requiresPrescription 
        ? (_cartService.prescriptionUrl != null && 
           _cartService.missingMedicines.isEmpty && 
           !_cartService.isValidating && 
           _cartService.validationError == null)
        : true;
    final bool canCheckout = allValidated;
    final double serviceFee = _cartService.totalCost * 0.02;
    final double deliveryFee = 40.0;
    final double totalAmount = _cartService.totalCost + serviceFee + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(PharmacoTokens.space20),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
        boxShadow: PharmacoTokens.shadowZ2(),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prescription banner
            if (requiresPrescription) ...[
              Container(
                padding: const EdgeInsets.all(PharmacoTokens.space12),
                decoration: BoxDecoration(
                  color: allValidated
                      ? PharmacoTokens.successLight
                      : (_cartService.validationError != null || _cartService.missingMedicines.isNotEmpty 
                          ? PharmacoTokens.errorLight 
                          : PharmacoTokens.warningLight),
                  borderRadius: PharmacoTokens.borderRadiusMedium,
                  border: Border.all(
                    color: allValidated
                        ? PharmacoTokens.success.withValues(alpha: 0.3)
                        : (_cartService.validationError != null || _cartService.missingMedicines.isNotEmpty 
                            ? PharmacoTokens.error.withValues(alpha: 0.3) 
                            : PharmacoTokens.warning.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_cartService.isValidating)
                          const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(PharmacoTokens.primaryBase)),
                          )
                        else
                          Icon(
                            allValidated
                                ? Icons.check_circle_rounded
                                : (_cartService.validationError != null || _cartService.missingMedicines.isNotEmpty 
                                    ? Icons.error_outline_rounded 
                                    : Icons.warning_amber_rounded),
                            color: allValidated
                                ? PharmacoTokens.success
                                : (_cartService.validationError != null || _cartService.missingMedicines.isNotEmpty 
                                    ? PharmacoTokens.error 
                                    : PharmacoTokens.warning),
                          ),
                        const SizedBox(width: PharmacoTokens.space12),
                        Expanded(
                          child: Text(
                            _cartService.isValidating
                                ? 'Analyzing prescription...'
                                : (_cartService.validationError != null
                                    ? _cartService.validationError!
                                    : (allValidated
                                        ? 'Prescription validated for all items!'
                                        : (_cartService.missingMedicines.isNotEmpty 
                                            ? 'Prescription missing: ${_cartService.missingMedicines.join(", ")}'
                                            : 'Items require a prescription'))),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: PharmacoTokens.weightMedium,
                              color: allValidated
                                  ? PharmacoTokens.success
                                  : (_cartService.validationError != null || _cartService.missingMedicines.isNotEmpty 
                                      ? PharmacoTokens.error 
                                      : PharmacoTokens.warning),
                            ),
                          ),
                        ),
                        if (_cartService.prescriptionUrl == null || _cartService.missingMedicines.isNotEmpty || _cartService.validationError != null)
                          TextButton(
                            onPressed: _cartService.isValidating ? null : _uploadPrescription,
                            child: _cartService.isValidating
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(_cartService.prescriptionUrl == null ? 'Upload' : 'Retry Scan'),
                          ),
                      ],
                    ),
                    if (_cartService.prescriptionDetails != null && allValidated) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: PharmacoTokens.success.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Dr. ${_cartService.prescriptionDetails!['doctor'] ?? 'Unknown'}',
                            style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.success),
                          ),
                          const Spacer(),
                          Icon(Icons.calendar_today_outlined, size: 14, color: PharmacoTokens.success.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            '${_cartService.prescriptionDetails!['date'] ?? 'N/A'}',
                            style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.success),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: PharmacoTokens.space16),
            ],

            // Wallet balance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(LocalizationService.t('Wallet Balance'),
                    style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
                Text('₹${_walletBalance.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: PharmacoTokens.weightSemiBold)),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space8),
            const Divider(),

            // Charges
            _ChargeRow(label: LocalizationService.t('Price Total'), value: '₹${_cartService.totalCost.toStringAsFixed(2)}', theme: theme),
            _ChargeRow(label: LocalizationService.t('Service Fee (2%)'), value: '₹${serviceFee.toStringAsFixed(2)}', theme: theme),
            _ChargeRow(label: LocalizationService.t('Delivery Fee'), value: '₹${deliveryFee.toStringAsFixed(2)}', theme: theme),
            const SizedBox(height: PharmacoTokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(LocalizationService.t('Total Amount'), style: theme.textTheme.titleMedium),
                Text('₹${totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(color: PharmacoTokens.primaryBase)),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space16),

            PharmacoButton(
              label: LocalizationService.t('Checkout'),
              onPressed: (_isProcessing || !canCheckout) ? null : () => _showPaymentOptions(),
              isLoading: _isProcessing,
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(PharmacoTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LocalizationService.t('Select Payment Method'), style: theme.textTheme.headlineMedium),
            const SizedBox(height: PharmacoTokens.space24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: PharmacoTokens.primarySurface,
                  borderRadius: PharmacoTokens.borderRadiusSmall,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: PharmacoTokens.primaryBase),
              ),
              title: Text(LocalizationService.t('Pay with Wallet')),
              subtitle: Text('${LocalizationService.t('Balance')}: ₹${_walletBalance.toStringAsFixed(2)}'),
              enabled: _walletBalance >= (_cartService.totalCost + (_cartService.totalCost * 0.02) + 40.0),
              onTap: () {
                Navigator.pop(context);
                _showOrderConfirmation('wallet');
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: PharmacoTokens.secondarySurface,
                  borderRadius: PharmacoTokens.borderRadiusSmall,
                ),
                child: const Icon(Icons.payment_outlined, color: PharmacoTokens.secondaryBase),
              ),
              title: const Text('Razorpay'),
              onTap: () {
                Navigator.pop(context);
                _showOrderConfirmation('razorpay');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderConfirmation(String method) {
    final theme = Theme.of(context);
    final double serviceFee = _cartService.totalCost * 0.02;
    final double deliveryFee = 40.0;
    final double totalAmount = _cartService.totalCost + serviceFee + deliveryFee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PharmacoTokens.radiusCard)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(PharmacoTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LocalizationService.t('Confirm Order'), style: theme.textTheme.headlineMedium),
            const SizedBox(height: PharmacoTokens.space20),
            _buildInfoRow(LocalizationService.t('Patient Name'), _profileData?['full_name'] ?? 'N/A', theme),
            _buildInfoRow(LocalizationService.t('Delivery Address'), _profileData?['address'] ?? 'N/A', theme),
            _buildInfoRow(LocalizationService.t('Payment Method'), method.toUpperCase(), theme),
            if (_cartService.prescriptionUrl != null)
              _buildInfoRow('Prescription', 'Uploaded ✅', theme),
            const Divider(height: PharmacoTokens.space24),
            ..._cartService.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: PharmacoTokens.space8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${item.medicine.name} x${item.quantity}',
                      style: theme.textTheme.bodyMedium)),
                  Text('₹${(item.medicine.price * item.quantity).toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: PharmacoTokens.weightSemiBold)),
                ],
              ),
            )),
            const Divider(height: PharmacoTokens.space24),
            _ChargeRow(label: LocalizationService.t('Items Total'), value: '₹${_cartService.totalCost.toStringAsFixed(2)}', theme: theme),
            _ChargeRow(label: LocalizationService.t('Service Fee (2%)'), value: '₹${serviceFee.toStringAsFixed(2)}', theme: theme),
            _ChargeRow(label: LocalizationService.t('Delivery Fee'), value: '₹${deliveryFee.toStringAsFixed(2)}', theme: theme),
            const Divider(height: PharmacoTokens.space16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(LocalizationService.t('Total Amount'), style: theme.textTheme.titleMedium),
                Text('₹${totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(color: PharmacoTokens.primaryBase)),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space24),
            PharmacoButton(
              label: LocalizationService.t('Confirm & Pay'),
              onPressed: () {
                Navigator.pop(context);
                if (method == 'wallet') {
                  _processCheckout('wallet');
                } else {
                  _startRazorpayPayment();
                }
              },
            ),
            const SizedBox(height: PharmacoTokens.space8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PharmacoTokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: PharmacoTokens.neutral500,
                  fontWeight: PharmacoTokens.weightSemiBold,
                )),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: PharmacoTokens.weightMedium))),
        ],
      ),
    );
  }

  void _startRazorpayPayment() {
    final keyId = dotenv.env['RAZORPAY_KEY_ID'];
    if (keyId == null || keyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Razorpay Key not configured')));
      return;
    }

    final double serviceFee = _cartService.totalCost * 0.02;
    final double deliveryFee = 40.0;
    final double totalToPay = _cartService.totalCost + serviceFee + deliveryFee;

    var options = {
      'key': keyId,
      'amount': (totalToPay * 100).toInt(),
      'name': 'PharmaCo',
      'description': 'Medicine Order',
      'currency': 'INR',
      'prefill': {
        'contact': _profileData?['phone_number'] ?? '',
        'email': _supabase.auth.currentUser?.email ?? '',
      },
      'timeout': 300,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
    }
  }

  Future<void> _processCheckout(String method, {String? referenceId}) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final double serviceFee = _cartService.totalCost * 0.02;
      final double deliveryFee = 40.0;
      final double totalToPay = _cartService.totalCost + serviceFee + deliveryFee;

      final res = await _supabase.functions.invoke(
        'verify-payment',
        body: {
          'payment_id': referenceId,
          'payment_method': method,
          'user_id': userId,
          'amount': totalToPay,
          'service_fee': serviceFee,
          'delivery_fee': deliveryFee,
          'total_tax': 0.0,
          'type': 'order',
          'prescription_url': _cartService.prescriptionUrl,
          'items': _cartService.items.map((item) {
            return {
              'medicine_id': int.parse(item.medicine.id.toString()),
              'name': item.medicine.name,
              'quantity': item.quantity,
              'price': item.medicine.price,
              'dosage_frequency': 'Once daily',
              'prescription_required': item.medicine.prescriptionRequired,
            };
          }).toList(),
          'delivery_address': _profileData?['address'] ?? 'Default Address',
          'patient_info': {
            'patient_id': 'PAT-${userId.substring(0, 4)}',
            'patient_age': _profileData?['age'],
            'patient_gender': _profileData?['gender'],
            'full_name': _profileData?['full_name'],
          },
        },
      ).timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (res.data != null && res.data['success'] == true) {
        final totalPaid = totalToPay;
        await _cartService.clearCart();
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/payment-success',
          (route) => false,
          arguments: {'order_id': res.data['order_id'], 'amount': totalPaid},
        );
      } else {
        Navigator.of(context).pushNamed('/payment-failure', arguments: {'error': res.data?['error'] ?? 'Order processing failed'});
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
      if (mounted) {
        Navigator.of(context).pushNamed('/payment-failure', arguments: {'error': e.toString()});
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

// ─── Cart Item Card ───

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final bool isDark;
  final ThemeData theme;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.isDark,
    required this.theme,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PharmacoTokens.space12),
      decoration: BoxDecoration(
        color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
        border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: PharmacoTokens.primarySurface,
              borderRadius: PharmacoTokens.borderRadiusSmall,
            ),
            child: const Icon(Icons.medication_rounded, color: PharmacoTokens.primaryBase),
          ),
          const SizedBox(width: PharmacoTokens.space12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicine.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.medicine.prescriptionRequired)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: PharmacoTokens.space4, vertical: 1),
                    decoration: BoxDecoration(
                      color: PharmacoTokens.warningLight,
                      borderRadius: PharmacoTokens.borderRadiusSmall,
                    ),
                    child: Text('Rx Required', style: theme.textTheme.labelSmall?.copyWith(
                      color: PharmacoTokens.warning, fontWeight: PharmacoTokens.weightSemiBold,
                    )),
                  ),
                const SizedBox(height: 2),
                Text(
                  '₹${item.medicine.price} × ${item.quantity}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PharmacoTokens.primaryBase,
                    fontWeight: PharmacoTokens.weightSemiBold,
                  ),
                ),
              ],
            ),
          ),

          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: item.quantity <= item.medicine.minOrderQuantity
                    ? PharmacoTokens.neutral300
                    : PharmacoTokens.error,
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: item.quantity <= item.medicine.minOrderQuantity
                    ? null
                    : () => onQuantityChanged(item.quantity - 1),
              ),
              Text('${item.quantity}', style: theme.textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: PharmacoTokens.primaryBase,
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () => onQuantityChanged(item.quantity + 1),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: PharmacoTokens.neutral400,
                iconSize: 18,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Charge Row ───

class _ChargeRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _ChargeRow({required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: PharmacoTokens.weightMedium)),
        ],
      ),
    );
  }
}
