import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/fcm_service.dart';
import '../theme/design_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: PharmacoTokens.durationSplash,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _redirect();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final user = _authService.currentUser;
    if (user != null) {
      await FCMService.initialize();
      try {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select('is_profile_complete')
            .eq('id', user.id)
            .maybeSingle();

        final bool isComplete = profile?['is_profile_complete'] ?? false;
        if (mounted) {
          if (isComplete) {
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
      } catch (e) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: PharmacoTokens.primarySurface,
                  borderRadius: PharmacoTokens.borderRadiusCard,
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  size: PharmacoTokens.space40,
                  color: PharmacoTokens.primaryBase,
                ),
              ),
              const SizedBox(height: PharmacoTokens.space24),
              Text(
                'PharmaCo',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: PharmacoTokens.primaryBase,
                ),
              ),
              const SizedBox(height: PharmacoTokens.space8),
              Text(
                'Your Health, Our Priority',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: PharmacoTokens.neutral400,
                ),
              ),
              const SizedBox(height: PharmacoTokens.space40),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: PharmacoTokens.primaryBase,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
