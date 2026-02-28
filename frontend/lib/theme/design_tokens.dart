import 'package:flutter/material.dart';

/// PharmaCo Design Tokens
/// ---------------------
/// Central source of truth for all design constants.
/// All widgets and screens reference these tokens — never hardcode values.

class PharmacoTokens {
  PharmacoTokens._();

  // ──────────────────────────────────────────
  //  COLOR TOKENS
  // ──────────────────────────────────────────

  // Primary
  static const Color primaryBase = Color(0xFF246BFF);
  static const Color primaryLight = Color(0xFF5A93FF);
  static const Color primaryDark = Color(0xFF1A4FCC);
  static const Color primarySurface = Color(0xFFEBF2FF);
  static const Color primarySurfaceDark = Color(0xFF0D1B3E);

  // Secondary
  static const Color secondaryBase = Color(0xFF00BFA5);
  static const Color secondaryLight = Color(0xFF5DF2D6);
  static const Color secondaryDark = Color(0xFF008C7A);
  static const Color secondarySurface = Color(0xFFE0F7F4);

  // CTA Option A — Warm Orange
  static const Color ctaOrange = Color(0xFFFF8A3D);
  static const Color ctaOrangeLight = Color(0xFFFFAB6E);
  static const Color ctaOrangeDark = Color(0xFFE06E1F);

  // CTA Option B — Vibrant Green
  static const Color ctaGreen = Color(0xFF00C853);
  static const Color ctaGreenLight = Color(0xFF5EFC82);
  static const Color ctaGreenDark = Color(0xFF009624);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Neutral Palette
  static const Color white = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF6F8FA);
  static const Color neutral100 = Color(0xFFEEF1F5);
  static const Color neutral200 = Color(0xFFE6EAF0);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);
  static const Color black = Color(0xFF333333);

  // Dark Mode Surfaces
  static const Color darkBg = Color(0xFF0A1628);
  static const Color darkSurface = Color(0xFF111D32);
  static const Color darkSurfaceElevated = Color(0xFF1A2942);
  static const Color darkBorder = Color(0xFF2A3A52);

  // Emergency
  static const Color emergency = Color(0xFFDC2626);
  static const Color emergencyBg = Color(0xFFFEF2F2);

  // ──────────────────────────────────────────
  //  SPACING TOKENS (base = 8)
  // ──────────────────────────────────────────

  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  // ──────────────────────────────────────────
  //  CORNER RADII
  // ──────────────────────────────────────────

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusCard = 20.0;
  static const double radiusLarge = 28.0;
  static const double radiusFull = 999.0;

  static final BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static final BorderRadius borderRadiusCard = BorderRadius.circular(radiusCard);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // ──────────────────────────────────────────
  //  ELEVATION TOKENS (Material 3)
  // ──────────────────────────────────────────

  static const double elevationZ0 = 0.0;
  static const double elevationZ1 = 4.0;
  static const double elevationZ2 = 8.0;
  static const double elevationZ3 = 16.0;

  static List<BoxShadow> shadowZ1({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowZ2({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowZ3({Color? color}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  // Primary-tinted shadow (for primary cards / floating action buttons)
  static List<BoxShadow> shadowPrimary = [
        BoxShadow(
          color: primaryBase.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // ──────────────────────────────────────────
  //  TYPOGRAPHY (Inter / Roboto)
  // ──────────────────────────────────────────
  //  Defined as constants for TextStyle creation.
  //  Actual TextTheme is built in pharmaco_theme.dart.

  static const String fontFamily = 'Inter';
  static const String fontFamilyFallback = 'Roboto';

  // Type scale values
  static const double fontSizeDisplayXl = 28.0;
  static const double fontSizeH1 = 22.0;
  static const double fontSizeH2 = 18.0;
  static const double fontSizeBodyLarge = 16.0;
  static const double fontSizeBodyRegular = 14.0;
  static const double fontSizeCaption = 12.0;
  static const double fontSizeOverline = 10.0;

  static const double lineHeightDisplayXl = 34.0;
  static const double lineHeightH1 = 28.0;
  static const double lineHeightH2 = 22.0;
  static const double lineHeightBodyLarge = 20.0;
  static const double lineHeightBodyRegular = 18.0;
  static const double lineHeightCaption = 14.0;

  // Font weights
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightSemiBold = FontWeight.w600;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightRegular = FontWeight.w400;

  // Min accessible body size for older adults
  static const double minAccessibleBodySize = 14.0;

  // ──────────────────────────────────────────
  //  ANIMATION DURATIONS & CURVES
  // ──────────────────────────────────────────

  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationSplash = Duration(milliseconds: 700);
  static const Duration durationSpring = Duration(milliseconds: 300);
  static const Duration durationShimmer = Duration(milliseconds: 1200);
  static const Duration durationFlyToCart = Duration(milliseconds: 500);

  // Press animation
  static const Duration durationPressDown = Duration(milliseconds: 120);
  static const Duration durationPressRelease = Duration(milliseconds: 180);

  // Curves
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveFadeIn = Curves.easeIn;
  static const Curve curveStandard = Curves.easeInOutCubic;

  // ──────────────────────────────────────────
  //  COMPONENT DIMENSIONS
  // ──────────────────────────────────────────

  // Buttons
  static const double buttonHeightLarge = 52.0;
  static const double buttonHeightRegular = 44.0;
  static const double buttonHeightSmall = 36.0;

  // Tap targets (accessibility — min 44x44)
  static const double minTapTarget = 44.0;

  // FAB
  static const double fabSize = 56.0;
  static const double fabMiniSize = 40.0;

  // Bottom Nav
  static const double bottomNavHeight = 80.0;

  // App Bar
  static const double appBarHeight = 56.0;

  // Input
  static const double inputHeight = 48.0;

  // Card
  static const double cardMinHeight = 72.0;

  // Avatar
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 40.0;
  static const double avatarLarge = 56.0;

  // Badge
  static const double badgeSize = 18.0;

  // Icon
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconStrokeWeight = 2.0;

  // ──────────────────────────────────────────
  //  RESPONSIVE BREAKPOINTS
  // ──────────────────────────────────────────

  static const double viewportMin = 320.0;
  static const double viewportMax = 460.0;
}
