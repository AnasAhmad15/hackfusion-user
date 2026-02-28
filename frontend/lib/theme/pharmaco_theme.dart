import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// PharmaCo Theme
/// ──────────────
/// Material 3 theme system with light and dark variants.
/// Uses tokens from [PharmacoTokens] — never hardcode values in widgets.
///
/// Usage in main.dart:
///   theme: PharmacoTheme.lightTheme,
///   darkTheme: PharmacoTheme.darkTheme,
///   themeMode: ThemeMode.system,

class PharmacoTheme {
  PharmacoTheme._();

  // ──────────────────────────────────────────
  //  LIGHT THEME
  // ──────────────────────────────────────────

  static ThemeData get lightTheme {
    final colorScheme = _lightColorScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: PharmacoTokens.fontFamily,
      scaffoldBackgroundColor: PharmacoTokens.neutral50,

      // ─── Text Theme ───
      textTheme: _textTheme(Brightness.light),

      // ─── App Bar ───
      appBarTheme: AppBarTheme(
        backgroundColor: PharmacoTokens.white,
        foregroundColor: PharmacoTokens.neutral900,
        elevation: 0,
        scrolledUnderElevation: PharmacoTokens.elevationZ1,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeH2,
          fontWeight: PharmacoTokens.weightSemiBold,
          height: PharmacoTokens.lineHeightH2 / PharmacoTokens.fontSizeH2,
          color: PharmacoTokens.neutral900,
        ),
        iconTheme: const IconThemeData(
          color: PharmacoTokens.neutral700,
          size: PharmacoTokens.iconMedium,
        ),
      ),

      // ─── Bottom Navigation ───
      navigationBarTheme: NavigationBarThemeData(
        height: PharmacoTokens.bottomNavHeight,
        backgroundColor: PharmacoTokens.white,
        surfaceTintColor: Colors.transparent,
        elevation: PharmacoTokens.elevationZ2,
        indicatorColor: PharmacoTokens.primarySurface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: PharmacoTokens.fontFamily,
            fontSize: PharmacoTokens.fontSizeCaption,
            fontWeight: isSelected
                ? PharmacoTokens.weightSemiBold
                : PharmacoTokens.weightRegular,
            color: isSelected
                ? PharmacoTokens.primaryBase
                : PharmacoTokens.neutral400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: PharmacoTokens.iconMedium,
            color: isSelected
                ? PharmacoTokens.primaryBase
                : PharmacoTokens.neutral400,
          );
        }),
      ),

      // ─── Cards ───
      cardTheme: CardThemeData(
        color: PharmacoTokens.white,
        surfaceTintColor: Colors.transparent,
        elevation: PharmacoTokens.elevationZ1,
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusCard,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space16,
          vertical: PharmacoTokens.space8,
        ),
      ),

      // ─── Elevated Button (Primary CTA) ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PharmacoTokens.neutral200;
            }
            return PharmacoTokens.primaryBase;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PharmacoTokens.neutral400;
            }
            return PharmacoTokens.white;
          }),
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, PharmacoTokens.buttonHeightLarge),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: PharmacoTokens.borderRadiusMedium,
            ),
          ),
          elevation: const WidgetStatePropertyAll(PharmacoTokens.elevationZ1),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: PharmacoTokens.fontFamily,
              fontSize: PharmacoTokens.fontSizeBodyLarge,
              fontWeight: PharmacoTokens.weightSemiBold,
              letterSpacing: 0.5,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: PharmacoTokens.space24,
              vertical: PharmacoTokens.space16,
            ),
          ),
          animationDuration: PharmacoTokens.durationMedium,
          splashFactory: InkSparkle.splashFactory,
        ),
      ),

      // ─── Outlined Button (Secondary) ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PharmacoTokens.neutral400;
            }
            return PharmacoTokens.primaryBase;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: PharmacoTokens.neutral200);
            }
            return const BorderSide(
              color: PharmacoTokens.primaryBase,
              width: 1.5,
            );
          }),
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, PharmacoTokens.buttonHeightRegular),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: PharmacoTokens.borderRadiusMedium,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: PharmacoTokens.fontFamily,
              fontSize: PharmacoTokens.fontSizeBodyRegular,
              fontWeight: PharmacoTokens.weightSemiBold,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: PharmacoTokens.space24,
              vertical: PharmacoTokens.space12,
            ),
          ),
        ),
      ),

      // ─── Text Button ───
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(PharmacoTokens.primaryBase),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: PharmacoTokens.fontFamily,
              fontSize: PharmacoTokens.fontSizeBodyRegular,
              fontWeight: PharmacoTokens.weightSemiBold,
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(
            Size(PharmacoTokens.minTapTarget, PharmacoTokens.minTapTarget),
          ),
        ),
      ),

      // ─── Floating Action Button ───
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: PharmacoTokens.primaryBase,
        foregroundColor: PharmacoTokens.white,
        elevation: PharmacoTokens.elevationZ2,
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusFull,
        ),
        sizeConstraints: const BoxConstraints.tightFor(
          width: PharmacoTokens.fabSize,
          height: PharmacoTokens.fabSize,
        ),
      ),

      // ─── Input Decoration ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PharmacoTokens.neutral100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space16,
          vertical: PharmacoTokens.space12,
        ),
        hintStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightRegular,
          color: PharmacoTokens.neutral400,
        ),
        labelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightMedium,
          color: PharmacoTokens.neutral600,
        ),
        errorStyle: const TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeCaption,
          fontWeight: PharmacoTokens.weightRegular,
          color: PharmacoTokens.error,
        ),
        border: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(
            color: PharmacoTokens.primaryBase,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(
            color: PharmacoTokens.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(
            color: PharmacoTokens.error,
            width: 2.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
      ),

      // ─── Chip ───
      chipTheme: ChipThemeData(
        backgroundColor: PharmacoTokens.neutral100,
        selectedColor: PharmacoTokens.primarySurface,
        labelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeCaption,
          fontWeight: PharmacoTokens.weightMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusFull,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space12,
          vertical: PharmacoTokens.space4,
        ),
      ),

      // ─── Bottom Sheet ───
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PharmacoTokens.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(PharmacoTokens.radiusLarge),
            topRight: Radius.circular(PharmacoTokens.radiusLarge),
          ),
        ),
        elevation: PharmacoTokens.elevationZ3,
      ),

      // ─── Dialog ───
      dialogTheme: DialogThemeData(
        backgroundColor: PharmacoTokens.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusCard,
        ),
        elevation: PharmacoTokens.elevationZ3,
        titleTextStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeH2,
          fontWeight: PharmacoTokens.weightSemiBold,
          color: PharmacoTokens.neutral900,
        ),
      ),

      // ─── Snack Bar ───
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PharmacoTokens.neutral800,
        contentTextStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          color: PharmacoTokens.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: PharmacoTokens.elevationZ2,
      ),

      // ─── Divider ───
      dividerTheme: const DividerThemeData(
        color: PharmacoTokens.neutral200,
        thickness: 1,
        space: PharmacoTokens.space16,
      ),

      // ─── Switch / Toggle ───
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PharmacoTokens.primaryBase;
          }
          return PharmacoTokens.neutral400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PharmacoTokens.primarySurface;
          }
          return PharmacoTokens.neutral200;
        }),
      ),

      // ─── Tabs ───
      tabBarTheme: TabBarThemeData(
        labelColor: PharmacoTokens.primaryBase,
        unselectedLabelColor: PharmacoTokens.neutral400,
        indicatorColor: PharmacoTokens.primaryBase,
        labelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightSemiBold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightRegular,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  DARK THEME
  // ──────────────────────────────────────────

  static ThemeData get darkTheme {
    final colorScheme = _darkColorScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: PharmacoTokens.fontFamily,
      scaffoldBackgroundColor: PharmacoTokens.darkBg,

      textTheme: _textTheme(Brightness.dark),

      appBarTheme: AppBarTheme(
        backgroundColor: PharmacoTokens.darkSurface,
        foregroundColor: PharmacoTokens.white,
        elevation: 0,
        scrolledUnderElevation: PharmacoTokens.elevationZ1,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeH2,
          fontWeight: PharmacoTokens.weightSemiBold,
          height: PharmacoTokens.lineHeightH2 / PharmacoTokens.fontSizeH2,
          color: PharmacoTokens.white,
        ),
        iconTheme: const IconThemeData(
          color: PharmacoTokens.neutral300,
          size: PharmacoTokens.iconMedium,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: PharmacoTokens.bottomNavHeight,
        backgroundColor: PharmacoTokens.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: PharmacoTokens.elevationZ2,
        indicatorColor: PharmacoTokens.primarySurfaceDark,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: PharmacoTokens.fontFamily,
            fontSize: PharmacoTokens.fontSizeCaption,
            fontWeight: isSelected
                ? PharmacoTokens.weightSemiBold
                : PharmacoTokens.weightRegular,
            color: isSelected
                ? PharmacoTokens.primaryLight
                : PharmacoTokens.neutral500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: PharmacoTokens.iconMedium,
            color: isSelected
                ? PharmacoTokens.primaryLight
                : PharmacoTokens.neutral500,
          );
        }),
      ),

      cardTheme: CardThemeData(
        color: PharmacoTokens.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: PharmacoTokens.elevationZ1,
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusCard,
          side: const BorderSide(
            color: PharmacoTokens.darkBorder,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space16,
          vertical: PharmacoTokens.space8,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PharmacoTokens.darkSurfaceElevated;
            }
            return PharmacoTokens.primaryBase;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PharmacoTokens.neutral500;
            }
            return PharmacoTokens.white;
          }),
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, PharmacoTokens.buttonHeightLarge),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: PharmacoTokens.borderRadiusMedium,
            ),
          ),
          elevation: const WidgetStatePropertyAll(PharmacoTokens.elevationZ1),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: PharmacoTokens.fontFamily,
              fontSize: PharmacoTokens.fontSizeBodyLarge,
              fontWeight: PharmacoTokens.weightSemiBold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return PharmacoTokens.neutral500;
            }
            return PharmacoTokens.primaryLight;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: PharmacoTokens.darkBorder);
            }
            return const BorderSide(
              color: PharmacoTokens.primaryLight,
              width: 1.5,
            );
          }),
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, PharmacoTokens.buttonHeightRegular),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: PharmacoTokens.borderRadiusMedium,
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(PharmacoTokens.primaryLight),
          minimumSize: const WidgetStatePropertyAll(
            Size(PharmacoTokens.minTapTarget, PharmacoTokens.minTapTarget),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: PharmacoTokens.primaryBase,
        foregroundColor: PharmacoTokens.white,
        elevation: PharmacoTokens.elevationZ2,
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusFull,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PharmacoTokens.darkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PharmacoTokens.space16,
          vertical: PharmacoTokens.space12,
        ),
        hintStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightRegular,
          color: PharmacoTokens.neutral500,
        ),
        labelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightMedium,
          color: PharmacoTokens.neutral400,
        ),
        errorStyle: const TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeCaption,
          color: PharmacoTokens.error,
        ),
        border: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(color: PharmacoTokens.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(color: PharmacoTokens.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(
            color: PharmacoTokens.primaryLight,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(
            color: PharmacoTokens.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(
            color: PharmacoTokens.error,
            width: 2.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
          borderSide: const BorderSide(color: PharmacoTokens.darkBorder),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: PharmacoTokens.darkSurfaceElevated,
        selectedColor: PharmacoTokens.primarySurfaceDark,
        labelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeCaption,
          fontWeight: PharmacoTokens.weightMedium,
          color: PharmacoTokens.neutral300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusFull,
        ),
        side: const BorderSide(color: PharmacoTokens.darkBorder),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: PharmacoTokens.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(PharmacoTokens.radiusLarge),
            topRight: Radius.circular(PharmacoTokens.radiusLarge),
          ),
        ),
        elevation: PharmacoTokens.elevationZ3,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: PharmacoTokens.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusCard,
        ),
        elevation: PharmacoTokens.elevationZ3,
        titleTextStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeH2,
          fontWeight: PharmacoTokens.weightSemiBold,
          color: PharmacoTokens.white,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: PharmacoTokens.darkSurfaceElevated,
        contentTextStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          color: PharmacoTokens.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: PharmacoTokens.borderRadiusMedium,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      dividerTheme: const DividerThemeData(
        color: PharmacoTokens.darkBorder,
        thickness: 1,
        space: PharmacoTokens.space16,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PharmacoTokens.primaryLight;
          }
          return PharmacoTokens.neutral500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return PharmacoTokens.primarySurfaceDark;
          }
          return PharmacoTokens.darkSurfaceElevated;
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: PharmacoTokens.primaryLight,
        unselectedLabelColor: PharmacoTokens.neutral500,
        indicatorColor: PharmacoTokens.primaryLight,
        labelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightSemiBold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: PharmacoTokens.fontFamily,
          fontSize: PharmacoTokens.fontSizeBodyRegular,
          fontWeight: PharmacoTokens.weightRegular,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  COLOR SCHEMES
  // ──────────────────────────────────────────

  static ColorScheme get _lightColorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: PharmacoTokens.primaryBase,
        onPrimary: PharmacoTokens.white,
        primaryContainer: PharmacoTokens.primarySurface,
        onPrimaryContainer: PharmacoTokens.primaryDark,
        secondary: PharmacoTokens.secondaryBase,
        onSecondary: PharmacoTokens.white,
        secondaryContainer: PharmacoTokens.secondarySurface,
        onSecondaryContainer: PharmacoTokens.secondaryDark,
        tertiary: PharmacoTokens.ctaOrange,
        onTertiary: PharmacoTokens.white,
        error: PharmacoTokens.error,
        onError: PharmacoTokens.white,
        errorContainer: PharmacoTokens.errorLight,
        onErrorContainer: PharmacoTokens.error,
        surface: PharmacoTokens.white,
        onSurface: PharmacoTokens.neutral900,
        surfaceContainerHighest: PharmacoTokens.neutral100,
        onSurfaceVariant: PharmacoTokens.neutral600,
        outline: PharmacoTokens.neutral300,
        outlineVariant: PharmacoTokens.neutral200,
        shadow: Colors.black,
        inverseSurface: PharmacoTokens.neutral800,
        onInverseSurface: PharmacoTokens.neutral100,
      );

  static ColorScheme get _darkColorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: PharmacoTokens.primaryLight,
        onPrimary: PharmacoTokens.darkBg,
        primaryContainer: PharmacoTokens.primarySurfaceDark,
        onPrimaryContainer: PharmacoTokens.primaryLight,
        secondary: PharmacoTokens.secondaryLight,
        onSecondary: PharmacoTokens.darkBg,
        secondaryContainer: PharmacoTokens.secondaryDark,
        onSecondaryContainer: PharmacoTokens.secondaryLight,
        tertiary: PharmacoTokens.ctaOrangeLight,
        onTertiary: PharmacoTokens.darkBg,
        error: PharmacoTokens.error,
        onError: PharmacoTokens.white,
        errorContainer: Color(0xFF3B1010),
        onErrorContainer: PharmacoTokens.error,
        surface: PharmacoTokens.darkSurface,
        onSurface: PharmacoTokens.neutral100,
        surfaceContainerHighest: PharmacoTokens.darkSurfaceElevated,
        onSurfaceVariant: PharmacoTokens.neutral400,
        outline: PharmacoTokens.darkBorder,
        outlineVariant: PharmacoTokens.darkBorder,
        shadow: Colors.black,
        inverseSurface: PharmacoTokens.neutral100,
        onInverseSurface: PharmacoTokens.neutral800,
      );

  // ──────────────────────────────────────────
  //  TEXT THEME
  // ──────────────────────────────────────────

  static TextTheme _textTheme(Brightness brightness) {
    final onSurface = brightness == Brightness.light
        ? PharmacoTokens.neutral900
        : PharmacoTokens.neutral100;
    final onSurfaceVariant = brightness == Brightness.light
        ? PharmacoTokens.neutral600
        : PharmacoTokens.neutral400;

    return TextTheme(
      // Display XL — 28/34/700
      displayLarge: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeDisplayXl,
        fontWeight: PharmacoTokens.weightBold,
        height: PharmacoTokens.lineHeightDisplayXl / PharmacoTokens.fontSizeDisplayXl,
        color: onSurface,
        letterSpacing: -0.5,
      ),

      // H1 — 22/28/600
      headlineLarge: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeH1,
        fontWeight: PharmacoTokens.weightSemiBold,
        height: PharmacoTokens.lineHeightH1 / PharmacoTokens.fontSizeH1,
        color: onSurface,
        letterSpacing: -0.25,
      ),

      // H2 — 18/22/600
      headlineMedium: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeH2,
        fontWeight: PharmacoTokens.weightSemiBold,
        height: PharmacoTokens.lineHeightH2 / PharmacoTokens.fontSizeH2,
        color: onSurface,
      ),

      // Title Large (same as H2 for M3 compat)
      titleLarge: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeH2,
        fontWeight: PharmacoTokens.weightSemiBold,
        height: PharmacoTokens.lineHeightH2 / PharmacoTokens.fontSizeH2,
        color: onSurface,
      ),

      // Title Medium
      titleMedium: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeBodyLarge,
        fontWeight: PharmacoTokens.weightSemiBold,
        height: PharmacoTokens.lineHeightBodyLarge / PharmacoTokens.fontSizeBodyLarge,
        color: onSurface,
      ),

      // Body Large — 16/20/500
      bodyLarge: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeBodyLarge,
        fontWeight: PharmacoTokens.weightMedium,
        height: PharmacoTokens.lineHeightBodyLarge / PharmacoTokens.fontSizeBodyLarge,
        color: onSurface,
      ),

      // Body Regular — 14/18/400
      bodyMedium: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeBodyRegular,
        fontWeight: PharmacoTokens.weightRegular,
        height: PharmacoTokens.lineHeightBodyRegular / PharmacoTokens.fontSizeBodyRegular,
        color: onSurface,
      ),

      // Body Small — 12/14
      bodySmall: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeCaption,
        fontWeight: PharmacoTokens.weightRegular,
        height: PharmacoTokens.lineHeightCaption / PharmacoTokens.fontSizeCaption,
        color: onSurfaceVariant,
      ),

      // Label Large
      labelLarge: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeBodyRegular,
        fontWeight: PharmacoTokens.weightSemiBold,
        color: onSurface,
        letterSpacing: 0.5,
      ),

      // Label Medium
      labelMedium: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeCaption,
        fontWeight: PharmacoTokens.weightMedium,
        color: onSurfaceVariant,
      ),

      // Label Small / Overline
      labelSmall: TextStyle(
        fontFamily: PharmacoTokens.fontFamily,
        fontSize: PharmacoTokens.fontSizeOverline,
        fontWeight: PharmacoTokens.weightMedium,
        color: onSurfaceVariant,
        letterSpacing: 1.0,
      ),
    );
  }

  // ──────────────────────────────────────────
  //  CONVENIENCE GETTERS (for widget-level use)
  // ──────────────────────────────────────────

  /// Subtle gradient for the app bar / header area.
  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [PharmacoTokens.primaryBase, PharmacoTokens.primaryDark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// Soft surface gradient for feature cards (e.g., AI chat card).
  static LinearGradient get surfaceGradient => const LinearGradient(
        colors: [PharmacoTokens.primarySurface, PharmacoTokens.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

