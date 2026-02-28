import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _supabase = Supabase.instance.client;
  late Razorpay _razorpay;
  double _balance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final walletRes = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      final transRes = await _supabase
          .from('wallet_transactions')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          if (walletRes != null) {
            _balance = (walletRes['balance'] as num).toDouble();
          }
          _transactions = List<Map<String, dynamic>>.from(transRes);
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    if (response.paymentId != null) {
      await _verifyTopup(response.paymentId!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment ID missing. Please contact support.')),
      );
    }
  }

  Future<void> _verifyTopup(String paymentId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final res = await _supabase.functions.invoke(
        'verify-payment',
        body: {
          'payment_id': paymentId,
          'user_id': user.id,
          'amount': double.parse(_amountController.text),
          'type': 'topup',
          'payment_method': 'razorpay',
        },
      ).timeout(const Duration(seconds: 45));

      if (!mounted) return;

      if (res.data != null && res.data['success'] == true) {
        _amountController.clear();
        await _fetchWalletData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet topped up successfully!'), behavior: SnackBarBehavior.floating),
        );
      } else {
        throw Exception(res.data?['error'] ?? 'Top-up verification failed');
      }
    } catch (e) {
      debugPrint('Topup verification error: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (e is TimeoutException) {
          errorMessage = "Verification timed out. Please check your transaction history in a few minutes.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Error: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _startTopup() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    final keyId = dotenv.env['RAZORPAY_KEY_ID'];
    if (keyId == null || keyId.isEmpty || keyId == 'rzp_test_YourRealTestKeyHere') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure a valid Razorpay Key ID in .env')),
      );
      return;
    }

    var options = {
      'key': keyId,
      'amount': (amount * 100).toInt(),
      'name': 'PharmaCo Wallet',
      'currency': 'INR',
      'description': 'Add Money to Wallet',
      'prefill': {
        'contact': '',
        'email': _supabase.auth.currentUser?.email ?? '',
      },
      'timeout': 300,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(LocalizationService.t('My Wallet'))),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              child: SkeletonLayouts.cardList(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(PharmacoTokens.space20),
              child: Column(
                children: [
                  _buildBalanceCard(theme),
                  const SizedBox(height: PharmacoTokens.space24),
                  _buildTopupSection(theme, isDark),
                  const SizedBox(height: PharmacoTokens.space24),
                  _buildTransactionHistory(theme, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PharmacoTokens.space24),
      decoration: BoxDecoration(
        color: PharmacoTokens.primaryBase,
        borderRadius: PharmacoTokens.borderRadiusCard,
        boxShadow: PharmacoTokens.shadowZ2(),
      ),
      child: Column(
        children: [
          Text(
            LocalizationService.t('Current Balance'),
            style: theme.textTheme.bodyLarge?.copyWith(color: PharmacoTokens.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: PharmacoTokens.space8),
          Text(
            '₹${_balance.toStringAsFixed(2)}',
            style: theme.textTheme.displayLarge?.copyWith(
              color: PharmacoTokens.white,
              fontSize: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopupSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LocalizationService.t('Add Money'), style: theme.textTheme.headlineMedium),
        const SizedBox(height: PharmacoTokens.space12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: LocalizationService.t('Enter Amount'),
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: PharmacoTokens.space12),
        PharmacoButton(
          label: LocalizationService.t('Add Funds'),
          icon: Icons.account_balance_wallet_rounded,
          onPressed: _startTopup,
        ),
      ],
    );
  }

  Widget _buildTransactionHistory(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LocalizationService.t('Transaction History'), style: theme.textTheme.headlineMedium),
        const SizedBox(height: PharmacoTokens.space12),
        _transactions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(PharmacoTokens.space20),
                child: Center(child: Text('No transactions yet')),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space8),
                itemBuilder: (context, index) {
                  final t = _transactions[index];
                  final isDeposit = t['transaction_type'] == 'topup' || t['transaction_type'] == 'deposit';
                  final amount = (t['amount'] as num).toDouble();

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
                      borderRadius: PharmacoTokens.borderRadiusCard,
                      boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
                      border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isDeposit
                              ? PharmacoTokens.successLight
                              : PharmacoTokens.emergencyBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDeposit ? Icons.add_rounded : Icons.remove_rounded,
                          color: isDeposit ? PharmacoTokens.success : PharmacoTokens.error,
                        ),
                      ),
                      title: Text(t['description'] ?? t['transaction_type'],
                          style: theme.textTheme.bodyMedium),
                      subtitle: Text(
                        t['created_at'].toString().split('T')[0],
                        style: theme.textTheme.labelSmall?.copyWith(color: PharmacoTokens.neutral500),
                      ),
                      trailing: Text(
                        '${isDeposit ? "+" : ""}₹${amount.abs().toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isDeposit ? PharmacoTokens.success : PharmacoTokens.error,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}
