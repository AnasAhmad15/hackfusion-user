import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../theme/design_tokens.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({Key? key}) : super(key: key);

  @override
  _AppTourScreenState createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _tourData = [
    {
      'title': 'Welcome to PharmaCo',
      'description': 'Your personalized health companion for medicines and care.',
      'icon': Icons.local_hospital_rounded,
      'color': PharmacoTokens.primaryBase,
    },
    {
      'title': 'AI Voice Assistant',
      'description': 'Talk to our AI to find medicines, set reminders, and more.',
      'icon': Icons.auto_awesome_rounded,
      'color': PharmacoTokens.secondaryBase,
    },
    {
      'title': 'Medicine Database',
      'description': 'Browse and search our extensive database of medicines.',
      'icon': Icons.medication_rounded,
      'color': PharmacoTokens.primaryBase,
    },
    {
      'title': '24/7 Emergency Support',
      'description': 'Quick access to emergency services when you need it most.',
      'icon': Icons.emergency_rounded,
      'color': PharmacoTokens.emergency,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(PharmacoTokens.space16),
                  child: TextButton(
                    onPressed: () async {
                      await LocalizationService.markTourSeen();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                    child: Text(LocalizationService.t('Skip')),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _tourData.length,
                  itemBuilder: (context, index) {
                    final data = _tourData[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PharmacoTokens.space32,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon in circle
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: (data['color'] as Color).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              data['icon'] as IconData,
                              size: 56,
                              color: data['color'] as Color,
                            ),
                          ),
                          const SizedBox(height: PharmacoTokens.space40),
                          Text(
                            LocalizationService.t(data['title'] as String),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: PharmacoTokens.space16),
                          Text(
                            LocalizationService.t(data['description'] as String),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: PharmacoTokens.neutral500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom: dots + button
              Padding(
                padding: const EdgeInsets.all(PharmacoTokens.space24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dots
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(
                          _tourData.length,
                          (index) => AnimatedContainer(
                            duration: PharmacoTokens.durationMedium,
                            margin: const EdgeInsets.only(right: PharmacoTokens.space4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? PharmacoTokens.primaryBase
                                  : PharmacoTokens.neutral300,
                              borderRadius: PharmacoTokens.borderRadiusFull,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Next / Get Started
                    SizedBox(
                      height: PharmacoTokens.buttonHeightRegular,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_currentPage == _tourData.length - 1) {
                            await LocalizationService.markTourSeen();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/home');
                            }
                          } else {
                            _pageController.nextPage(
                              duration: PharmacoTokens.durationMedium,
                              curve: PharmacoTokens.curveStandard,
                            );
                          }
                        },
                        child: Text(
                          _currentPage == _tourData.length - 1
                              ? LocalizationService.t('Get Started')
                              : LocalizationService.t('Next'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
