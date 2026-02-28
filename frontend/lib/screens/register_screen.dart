import '../services/fcm_service.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String t(String key) => LocalizationService.t(key);

  @override
  void initState() {
    super.initState();
    LocalizationService.addListener(_updateUI);
    _updateUI();
  }

  @override
  void dispose() {
    LocalizationService.removeListener(_updateUI);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: PharmacoTokens.space8),

            // Title
            Text(t('Create Account'), style: theme.textTheme.displayLarge),
            const SizedBox(height: PharmacoTokens.space8),
            Text(
              t('Join PharmaCo to manage your health smarter'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: PharmacoTokens.neutral500,
              ),
            ),
            const SizedBox(height: PharmacoTokens.space32),

            // Full Name
            Text(t('Full Name'), style: theme.textTheme.labelLarge),
            const SizedBox(height: PharmacoTokens.space8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'John Doe',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: PharmacoTokens.space16),

            // Age + Gender row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('Age'), style: theme.textTheme.labelLarge),
                      const SizedBox(height: PharmacoTokens.space8),
                      TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '25',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PharmacoTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('Gender'), style: theme.textTheme.labelLarge),
                      const SizedBox(height: PharmacoTokens.space8),
                      TextField(
                        controller: _genderController,
                        decoration: InputDecoration(
                          hintText: 'Male',
                          prefixIcon: const Icon(Icons.wc_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space16),

            // Email
            Text(t('Email Address'), style: theme.textTheme.labelLarge),
            const SizedBox(height: PharmacoTokens.space8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: PharmacoTokens.space16),

            // Password
            Text(t('Password'), style: theme.textTheme.labelLarge),
            const SizedBox(height: PharmacoTokens.space8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: PharmacoTokens.space32),

            // Register button
            PharmacoButton(
              label: t('Register'),
              onPressed: _isLoading ? null : _handleRegister,
              isLoading: _isLoading,
            ),
            const SizedBox(height: PharmacoTokens.space24),

            // Login link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t("Already have an account? "),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PharmacoTokens.neutral500,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    t('Login'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: PharmacoTokens.primaryBase,
                      fontWeight: PharmacoTokens.weightSemiBold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PharmacoTokens.space32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _genderController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Redirecting to profile completion...')),
        );
        if (mounted) {
          await FCMService.initialize();
          await FCMService.sendWelcomeNotification('registration');
          Navigator.of(context).pushReplacementNamed('/profile-completion');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
