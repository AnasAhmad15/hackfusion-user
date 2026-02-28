import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/fcm_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: PharmacoTokens.space24,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),

                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: PharmacoTokens.primarySurface,
                      borderRadius: PharmacoTokens.borderRadiusCard,
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_pharmacy_rounded,
                        size: PharmacoTokens.space40,
                        color: PharmacoTokens.primaryBase,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space32),

                // Title
                Text(
                  t('Welcome Back'),
                  style: theme.textTheme.displayLarge,
                ),
                const SizedBox(height: PharmacoTokens.space8),
                Text(
                  t('Sign in to continue caring for your health'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: PharmacoTokens.neutral500,
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space32),

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
                const SizedBox(height: PharmacoTokens.space8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(t('Forgot Password?')),
                  ),
                ),
                const SizedBox(height: PharmacoTokens.space24),

                // Login button
                PharmacoButton(
                  label: t('Login'),
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: PharmacoTokens.space24),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t("Don't have an account? "),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: PharmacoTokens.neutral500,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/register'),
                      child: Text(
                        t('Register'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: PharmacoTokens.primaryBase,
                          fontWeight: PharmacoTokens.weightSemiBold,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final response = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('is_profile_complete, role')
            .eq('id', response.user!.id)
            .maybeSingle();

        final bool isComplete = profile?['is_profile_complete'] ?? false;
        final String role = profile?['role'] ?? 'user';

        if (mounted) {
          await FCMService.initialize();
          await FCMService.sendWelcomeNotification('login');

          if (role == 'admin') {
            Navigator.of(context).pushReplacementNamed('/admin-dashboard');
          } else if (isComplete) {
            final bool tourSeen = await LocalizationService.isTourSeen();
            if (tourSeen) {
              Navigator.of(context).pushReplacementNamed('/home');
            } else {
              Navigator.of(context).pushReplacementNamed('/app-tour');
            }
          } else {
            Navigator.of(context).pushReplacementNamed('/profile-completion');
          }
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
