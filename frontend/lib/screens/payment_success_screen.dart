import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String orderId;
  final double amount;

  const PaymentSuccessScreen({
    Key? key,
    required this.orderId,
    required this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PharmacoTokens.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success circle
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: PharmacoTokens.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: PharmacoTokens.success, size: 48),
              ),
              const SizedBox(height: PharmacoTokens.space24),
              Text(LocalizationService.t('Payment Successful!'), style: theme.textTheme.headlineLarge),
              const SizedBox(height: PharmacoTokens.space16),
              Text(
                '${LocalizationService.t('Order ID')}: #$orderId',
                style: theme.textTheme.bodyMedium?.copyWith(color: PharmacoTokens.neutral500),
              ),
              const SizedBox(height: PharmacoTokens.space8),
              Text(
                '${LocalizationService.t('Amount Paid')}: ₹${amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(color: PharmacoTokens.primaryBase),
              ),
              const SizedBox(height: PharmacoTokens.space40),

              PharmacoButton(
                label: LocalizationService.t('Back to Home'),
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
              ),
              const SizedBox(height: PharmacoTokens.space12),
              PharmacoButton.secondary(
                label: LocalizationService.t('View My Orders'),
                onPressed: () => Navigator.of(context).pushReplacementNamed('/my-orders'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
