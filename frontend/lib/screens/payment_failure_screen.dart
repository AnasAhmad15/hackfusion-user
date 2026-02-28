import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class PaymentFailureScreen extends StatelessWidget {
  final String error;

  const PaymentFailureScreen({
    Key? key,
    required this.error,
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
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: PharmacoTokens.emergencyBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: PharmacoTokens.error, size: 48),
              ),
              const SizedBox(height: PharmacoTokens.space24),
              Text(LocalizationService.t('Payment Failed!'), style: theme.textTheme.headlineLarge),
              const SizedBox(height: PharmacoTokens.space16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: PharmacoTokens.neutral500),
              ),
              const SizedBox(height: PharmacoTokens.space40),

              SizedBox(
                width: double.infinity,
                height: PharmacoTokens.buttonHeightRegular,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PharmacoTokens.error,
                    foregroundColor: PharmacoTokens.white,
                  ),
                  child: Text(LocalizationService.t('Try Again')),
                ),
              ),
              const SizedBox(height: PharmacoTokens.space12),
              PharmacoButton.text(
                label: LocalizationService.t('Back to Home'),
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
