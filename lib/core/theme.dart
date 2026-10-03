import 'package:flutter/material.dart';

/// Vintage darkroom look: flat paper surfaces, hairline rules, square corners,
/// Space Grotesk headings, Geist Mono body, JetBrains Mono for labels and data.

/// Corner radius for surfaces (cards, inputs, buttons, sheets).
const kRadius = 4.0;

/// Corner radius for stamps (badges, tags, chips).
const kStampRadius = 2.0;

/// Hairline rule width shared by borders and dividers.
const kHairline = 1.0;

BorderRadius get kCorners => BorderRadius.circular(kRadius);

// Tokens converted from the oklch theme (zinc neutrals + orange primary).
const _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFCA3500),
  onPrimary: Color(0xFFFFF7ED),
  primaryContainer: Color(0xFFFFEDD5),
  onPrimaryContainer: Color(0xFFAA2C00),
  secondary: Color(0xFFF4F4F5),
  onSecondary: Color(0xFF18181B),
  secondaryContainer: Color(0xFFF4F4F5),
  onSecondaryContainer: Color(0xFF18181B),
  tertiary: Color(0xFF52525C),
  onTertiary: Color(0xFFFAFAFA),
  tertiaryContainer: Color(0xFFE4E4E7),
  onTertiaryContainer: Color(0xFF27272A),
  error: Color(0xFFE7000B),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF9F0712),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF09090B),
  onSurfaceVariant: Color(0xFF71717B),
  outline: Color(0xFF9F9FA9),
  outlineVariant: Color(0xFFC4C4CA),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFF4F4F5),
  surfaceContainerHigh: Color(0xFFF4F4F5),
  surfaceContainerHighest: Color(0xFFE4E4E7),
  inverseSurface: Color(0xFF18181B),
  onInverseSurface: Color(0xFFFAFAFA),
  inversePrimary: Color(0xFFFF6900),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9F2D00),
  onPrimary: Color(0xFFFFF7ED),
  primaryContainer: Color(0xFF3A1405),
  // Bright orange: 4.5:1+ on the dark surfaces, for text and icons.
  onPrimaryContainer: Color(0xFFFF6900),
  secondary: Color(0xFF27272A),
  onSecondary: Color(0xFFFAFAFA),
  secondaryContainer: Color(0xFF27272A),
  onSecondaryContainer: Color(0xFFFAFAFA),
  tertiary: Color(0xFFD4D4D8),
  onTertiary: Color(0xFF09090B),
  tertiaryContainer: Color(0xFF3F3F46),
  onTertiaryContainer: Color(0xFFE4E4E7),
  error: Color(0xFFFF6467),
  onError: Color(0xFF09090B),
  errorContainer: Color(0xFF4A1416),
  onErrorContainer: Color(0xFFFFB3B5),
  surface: Color(0xFF09090B),
  onSurface: Color(0xFFFAFAFA),
  onSurfaceVariant: Color(0xFF9F9FA9),
  outline: Color(0xFF71717B),
  // Stronger than oklch(1 0 0 / 10%) so card borders read on dark surfaces.
  outlineVariant: Color(0xFF3A3A40),
  surfaceContainerLowest: Color(0xFF09090B),
  surfaceContainerLow: Color(0xFF18181B),
  surfaceContainer: Color(0xFF1F1F22),
  surfaceContainerHigh: Color(0xFF27272A),
  surfaceContainerHighest: Color(0xFF27272A),
  inverseSurface: Color(0xFFFAFAFA),
  onInverseSurface: Color(0xFF18181B),
  inversePrimary: Color(0xFFCA3500),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

// Bundled variable fonts (assets/fonts, declared in pubspec.yaml); nothing is
// fetched at runtime.
const _heading = 'SpaceGrotesk';
const _mono = 'JetBrainsMono';
const _body = 'GeistMono';

/// Heading face (Space Grotesk).
TextStyle headingStyle({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w600,
  double? letterSpacing,
  double? height,
  Color? color,
}) => TextStyle(
  fontFamily: _heading,
  fontSize: fontSize,
  fontWeight: fontWeight,
  letterSpacing: letterSpacing,
  height: height,
  color: color,
);

/// Small uppercase-style label / data face (JetBrains Mono).
TextStyle monoStyle({
  double fontSize = 11,
  FontWeight fontWeight = FontWeight.w500,
  double letterSpacing = 1.0,
  double? height,
  Color? color,
}) => TextStyle(
  fontFamily: _mono,
  fontSize: fontSize,
  fontWeight: fontWeight,
  letterSpacing: letterSpacing,
  height: height,
  color: color,
);

/// One page transition on every platform, so iOS does not get the Cupertino slide.
const _transitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
  },
);

TextTheme _textTheme(ColorScheme cs) {
  final base = ThemeData(brightness: cs.brightness).textTheme
      .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
  TextStyle? b(TextStyle? s) => s?.copyWith(fontFamily: _body);
  TextStyle? h(TextStyle? s) => s?.copyWith(
    fontFamily: _heading,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  TextStyle? m(TextStyle? s) =>
      s?.copyWith(fontFamily: _mono, letterSpacing: 0.8);
  return TextTheme(
    displayLarge: h(base.displayLarge),
    displayMedium: h(base.displayMedium),
    displaySmall: h(base.displaySmall),
    headlineLarge: h(base.headlineLarge),
    headlineMedium: h(base.headlineMedium),
    headlineSmall: h(base.headlineSmall),
    titleLarge: h(base.titleLarge),
    titleMedium: h(base.titleMedium),
    titleSmall: m(base.titleSmall),
    bodyLarge: b(base.bodyLarge),
    bodyMedium: b(base.bodyMedium),
    bodySmall: b(base.bodySmall),
    labelLarge: m(base.labelLarge),
    labelMedium: m(base.labelMedium),
    labelSmall: m(base.labelSmall),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final cs = brightness == Brightness.light ? _light : _dark;
  final text = _textTheme(cs);
  final rule = BorderSide(color: cs.outlineVariant, width: kHairline);
  final shape = RoundedRectangleBorder(borderRadius: kCorners);
  final stamp = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kStampRadius),
  );
  final dark = brightness == Brightness.dark;
  final navBg = dark ? const Color(0xFF27272A) : const Color(0xFF18181B);
  const navFg = Color(0xFFFAFAFA);
  const navFgMuted = Color(0xFFA1A1AA);
  final buttonText = monoStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    brightness: brightness,
    scaffoldBackgroundColor: cs.surface,
    canvasColor: cs.surface,
    pageTransitionsTheme: _transitions,
    textTheme: text,
    primaryTextTheme: text,
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant,
      thickness: kHairline,
      space: kHairline,
    ),
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      shape: Border(bottom: rule),
      titleTextStyle: headingStyle(
        fontSize: 19,
        letterSpacing: -0.2,
        color: cs.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: kCorners, side: rule),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      subtitleTextStyle: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Dark "film canister" bar: stands apart from the page in both modes.
      backgroundColor: navBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: cs.primary,
      indicatorShape: shape,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => monoStyle(
          fontSize: 10.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          letterSpacing: 0.8,
          color: s.contains(WidgetState.selected) ? navFg : navFgMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? cs.onPrimary : navFgMuted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        textStyle: buttonText,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        textStyle: buttonText,
        side: BorderSide(color: cs.outline, width: kHairline),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: shape, textStyle: buttonText),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: shape,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: shape,
        textStyle: monoStyle(fontSize: 12, letterSpacing: 0.4),
        side: BorderSide(color: cs.outline, width: kHairline),
        selectedBackgroundColor: cs.primaryContainer,
        selectedForegroundColor: cs.onPrimaryContainer,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: stamp,
      side: BorderSide(color: cs.outline, width: kHairline),
      labelStyle: monoStyle(fontSize: 11.5, letterSpacing: 0.6),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: monoStyle(
        fontSize: 13,
        letterSpacing: 0.4,
        color: cs.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide(color: cs.outline, width: kHairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide(color: cs.outline, width: kHairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kCorners,
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: cs.onSurface,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: monoStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      unselectedLabelStyle: monoStyle(fontSize: 11.5, letterSpacing: 1.2),
      indicatorColor: dark ? cs.onPrimaryContainer : cs.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: cs.outlineVariant,
      dividerHeight: kHairline,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(color: cs.outline, width: kHairline),
      ),
      titleTextStyle: headingStyle(fontSize: 19, color: cs.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kRadius),
        ),
        side: rule,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(color: cs.outline, width: kHairline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
      shape: shape,
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: cs.primary,
      linearTrackColor: cs.outlineVariant,
    ),
    checkboxTheme: CheckboxThemeData(shape: stamp),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(cs.outline),
    ),
  );
}
