import 'package:material_ui/material_ui.dart';

import 'design_tokens.g.dart';

/// Slate and emerald look from the design tokens: hairline rules, Space Grotesk
/// headings, Geist Mono body, JetBrains Mono for labels and data.

/// Corner radius for surfaces (cards, inputs, buttons, sheets).
const kRadius = DesignTokens.semanticRadiusSurface;

/// Corner radius for stamps (badges, tags, chips).
const kStampRadius = 2.0;

/// Hairline rule width shared by borders and dividers.
const kHairline = 1.0;

BorderRadius get kCorners => BorderRadius.circular(kRadius);

/// Corner radius for controls (buttons, inputs, segments, nav indicator).
BorderRadius get _controlCorners =>
    BorderRadius.circular(DesignTokens.semanticRadiusControl);

// Bundled variable fonts (assets/fonts, declared in pubspec.yaml); nothing is
// fetched at runtime.
const _heading = DesignTokens.semanticTextDisplayFontFamily;
const _mono = DesignTokens.semanticTextLabelFontFamily;
const _body = DesignTokens.semanticTextBodyFontFamily;

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
  double fontSize = DesignTokens.semanticTextCaptionFontSize,
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
  TextStyle? role(
    TextStyle? style,
    String family,
    double size,
    double height,
    FontWeight weight,
    double? letterSpacing,
  ) => style?.copyWith(
    fontFamily: family,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
  );
  TextStyle? display(TextStyle? style) => role(
    style,
    _heading,
    DesignTokens.semanticTextDisplayFontSize,
    DesignTokens.semanticTextDisplayLineHeight,
    DesignTokens.semanticTextDisplayFontWeight,
    -0.3,
  );
  TextStyle? heading1(TextStyle? style) => role(
    style,
    _heading,
    DesignTokens.semanticTextHeading1FontSize,
    DesignTokens.semanticTextHeading1LineHeight,
    DesignTokens.semanticTextHeading1FontWeight,
    -0.3,
  );
  TextStyle? heading2(TextStyle? style) => role(
    style,
    _heading,
    DesignTokens.semanticTextHeading2FontSize,
    DesignTokens.semanticTextHeading2LineHeight,
    DesignTokens.semanticTextHeading2FontWeight,
    -0.3,
  );
  TextStyle? heading3(TextStyle? style) => role(
    style,
    _heading,
    DesignTokens.semanticTextHeading3FontSize,
    DesignTokens.semanticTextHeading3LineHeight,
    DesignTokens.semanticTextHeading3FontWeight,
    -0.3,
  );
  TextStyle? body(TextStyle? style) => role(
    style,
    _body,
    DesignTokens.semanticTextBodyFontSize,
    DesignTokens.semanticTextBodyLineHeight,
    DesignTokens.semanticTextBodyFontWeight,
    null, // Flutter keeps the Material body spacing (0.5, 0.25, 0.4)
  );
  TextStyle? bodySm(TextStyle? style) => role(
    style,
    _body,
    DesignTokens.semanticTextBodySmFontSize,
    DesignTokens.semanticTextBodySmLineHeight,
    DesignTokens.semanticTextBodySmFontWeight,
    null, // Flutter keeps the Material body spacing (0.5, 0.25, 0.4)
  );
  TextStyle? caption(TextStyle? style, String family) => role(
    style,
    family,
    DesignTokens.semanticTextCaptionFontSize,
    DesignTokens.semanticTextCaptionLineHeight,
    DesignTokens.semanticTextCaptionFontWeight,
    family == _mono ? 0.8 : null,
  );
  TextStyle? label(TextStyle? style) => role(
    style,
    _mono,
    DesignTokens.semanticTextLabelFontSize,
    DesignTokens.semanticTextLabelLineHeight,
    DesignTokens.semanticTextLabelFontWeight,
    0.8,
  );
  return TextTheme(
    displayLarge: display(base.displayLarge),
    displayMedium: display(base.displayMedium),
    displaySmall: display(base.displaySmall),
    headlineLarge: heading1(base.headlineLarge),
    headlineMedium: heading1(base.headlineMedium),
    headlineSmall: heading1(base.headlineSmall),
    titleLarge: heading2(base.titleLarge),
    titleMedium: heading3(base.titleMedium),
    titleSmall: label(base.titleSmall),
    bodyLarge: body(base.bodyLarge),
    bodyMedium: bodySm(base.bodyMedium),
    bodySmall: caption(base.bodySmall, _body),
    labelLarge: label(base.labelLarge),
    labelMedium: label(base.labelMedium),
    labelSmall: caption(base.labelSmall, _mono),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final cs = light
      ? DesignTokensLight.colorScheme
      : DesignTokensDark.colorScheme;
  final text = _textTheme(cs);
  final rule = BorderSide(color: cs.outlineVariant, width: kHairline);
  final shape = RoundedRectangleBorder(borderRadius: _controlCorners);
  final stamp = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kStampRadius),
  );
  final buttonText = monoStyle(
    fontSize: DesignTokens.componentButtonFontSize,
    fontWeight: DesignTokens.componentButtonFontWeight,
    letterSpacing: 0.6,
  );
  const buttonSize = Size(0, DesignTokens.componentButtonHeightLg);
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: DesignTokens.componentButtonPaddingX,
  );
  final disabled = cs.onSurface.withValues(
    alpha: DesignTokens.semanticOpacityDisabled,
  );
  final navBg = light
      ? DesignTokensLight.componentNavBg
      : DesignTokensDark.componentNavBg;
  final navIndicator = light
      ? DesignTokensLight.componentNavIndicator
      : DesignTokensDark.componentNavIndicator;
  final navFg = light
      ? DesignTokensLight.componentNavItemFg
      : DesignTokensDark.componentNavItemFg;
  final navFgActive = light
      ? DesignTokensLight.componentNavItemFgActive
      : DesignTokensDark.componentNavItemFgActive;
  final onAccent = light
      ? DesignTokensLight.semanticColorFgOnAccent
      : DesignTokensDark.semanticColorFgOnAccent;
  final cardBg = light
      ? DesignTokensLight.componentCardBg
      : DesignTokensDark.componentCardBg;
  final dialogBg = light
      ? DesignTokensLight.componentDialogBg
      : DesignTokensDark.componentDialogBg;
  final inputFocus = light
      ? DesignTokensLight.componentInputBorderFocus
      : DesignTokensDark.componentInputBorderFocus;

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
        fontSize: DesignTokens.semanticTextHeading2FontSize,
        letterSpacing: -0.2,
        color: cs.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
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
      backgroundColor: navBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: navIndicator,
      indicatorShape: shape,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => monoStyle(
          fontSize: DesignTokens.semanticTextCaptionFontSize,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          letterSpacing: 0.8,
          color: s.contains(WidgetState.selected) ? navFgActive : navFg,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? onAccent : navFg,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        textStyle: buttonText,
        elevation: 0,
        padding: buttonPadding,
        minimumSize: buttonSize,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        textStyle: buttonText,
        side: BorderSide(color: cs.outline, width: kHairline),
        padding: buttonPadding,
        minimumSize: buttonSize,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: buttonText,
        foregroundColor: cs.primary,
        iconColor: cs.primary,
        disabledForegroundColor: disabled,
        disabledIconColor: disabled,
      ),
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
        textStyle: monoStyle(
          fontSize: DesignTokens.semanticTextCaptionFontSize,
          letterSpacing: 0.4,
        ),
        side: BorderSide(color: cs.outline, width: kHairline),
        selectedBackgroundColor: cs.primaryContainer,
        selectedForegroundColor: cs.onPrimaryContainer,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: stamp,
      side: BorderSide(color: cs.outline, width: kHairline),
      labelStyle: monoStyle(
        fontSize: DesignTokens.semanticTextCaptionFontSize,
        letterSpacing: 0.6,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: monoStyle(
        fontSize: DesignTokens.semanticTextLabelFontSize,
        letterSpacing: 0.4,
        color: cs.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: _controlCorners,
        borderSide: BorderSide(color: cs.outline, width: kHairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _controlCorners,
        borderSide: BorderSide(color: cs.outline, width: kHairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _controlCorners,
        borderSide: BorderSide(
          color: inputFocus,
          width: DesignTokens.componentFocusRingWidth,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: cs.onSurface,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: monoStyle(
        fontSize: DesignTokens.semanticTextCaptionFontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      unselectedLabelStyle: monoStyle(
        fontSize: DesignTokens.semanticTextCaptionFontSize,
        letterSpacing: 1.2,
      ),
      indicatorColor: cs.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: cs.outlineVariant,
      dividerHeight: kHairline,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(color: cs.outline, width: kHairline),
      ),
      titleTextStyle: headingStyle(
        fontSize: DesignTokens.semanticTextHeading2FontSize,
        color: cs.onSurface,
      ),
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
