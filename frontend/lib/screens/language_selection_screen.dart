import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> languages = const [
    {'name': 'English', 'code': 'English', 'flag': '🇺🇸'},
    {'name': 'Hindi', 'code': 'Hindi', 'flag': '🇮🇳'},
    {'name': 'Marathi', 'code': 'Marathi', 'flag': '🇮🇳'},
    {'name': 'Spanish', 'code': 'Spanish', 'flag': '🇪🇸'},
    {'name': 'French', 'code': 'French', 'flag': '🇫🇷'},
    {'name': 'German', 'code': 'German', 'flag': '🇩🇪'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PharmacoTokens.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: PharmacoTokens.space40),

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: PharmacoTokens.primarySurface,
                  borderRadius: PharmacoTokens.borderRadiusMedium,
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  size: PharmacoTokens.iconLarge,
                  color: PharmacoTokens.primaryBase,
                ),
              ),
              const SizedBox(height: PharmacoTokens.space24),

              // Title
              Text(
                'Choose Your Language',
                style: theme.textTheme.displayLarge,
              ),
              const SizedBox(height: PharmacoTokens.space8),
              Text(
                'अपनी भाषा चुनें',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: PharmacoTokens.neutral400,
                ),
              ),
              const SizedBox(height: PharmacoTokens.space32),

              // Language grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: PharmacoTokens.space12,
                    mainAxisSpacing: PharmacoTokens.space12,
                  ),
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    return _LanguageCard(
                      name: lang['name']!,
                      flag: lang['flag']!,
                      onTap: () async {
                        await LocalizationService.setLanguage(lang['code']!);
                        await LocalizationService.markFirstTimeDone();
                        if (context.mounted) {
                          Navigator.pushNamed(context, '/login');
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String name;
  final String flag;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.name,
    required this.flag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
      borderRadius: PharmacoTokens.borderRadiusCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: PharmacoTokens.borderRadiusCard,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: PharmacoTokens.borderRadiusCard,
            boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
            border: isDark
                ? Border.all(color: PharmacoTokens.darkBorder)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: PharmacoTokens.space8),
              Text(
                name,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
