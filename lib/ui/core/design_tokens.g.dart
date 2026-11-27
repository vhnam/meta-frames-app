// GENERATED FILE. DO NOT EDIT.
// Source: meta-frames-design-tokens/tokens/tokens.json (not in Git), sha256 ad9868c2dde00f25d599d23d7c494b5d412909549b979806762a56ec6db9385a
// Generator: sha256 27fbb33eec4c5f09f60c35320294a0dc787249951abf0432dd40f1af6fd2355b of package.json, pnpm-lock.yaml, src/build.ts, src/hooks.ts, tokens/bindings.json (meta-frames-design-tokens/, sorted by path)
// Regenerate: node meta-frames-design-tokens/src/build.ts. Verify: node meta-frames-design-tokens/src/build.ts --check

import 'package:material_ui/material_ui.dart';

abstract final class DesignTokens {
  // Padding inside a component, smallest step. Use space.gap for the space between components.
  static const double semanticSpaceInsetXs = 4.0;
  // Padding inside a compact component, such as a badge or a small button.
  static const double semanticSpaceInsetSm = 8.0;
  // Default padding inside a component, such as an input or a list row.
  static const double semanticSpaceInsetMd = 12.0;
  // Padding inside a card or a panel.
  static const double semanticSpaceInsetLg = 16.0;
  // Padding inside a large section or a dialog.
  static const double semanticSpaceInsetXl = 24.0;
  // Smallest space between related elements, such as an icon and its label. Use space.inset for padding inside a component.
  static const double semanticSpaceGapXs = 4.0;
  // Space between closely related elements, such as form label and field.
  static const double semanticSpaceGapSm = 8.0;
  // Default space between sibling elements in a group.
  static const double semanticSpaceGapMd = 12.0;
  // Space between groups of elements, such as form fields.
  static const double semanticSpaceGapLg = 16.0;
  // Space between page sections.
  static const double semanticSpaceGapXl = 24.0;
  // Largest space between major page areas.
  static const double semanticSpaceGap2xl = 32.0;
  // Page side margin on narrow screens, such as phones.
  static const double semanticSpaceGutterCompact = 16.0;
  // Page side margin on wide screens, such as desktop.
  static const double semanticSpaceGutterWide = 32.0;
  // Smallest touch target height and width. Make every tap target at least this size.
  static const double semanticSizeTouchMin = 44.0;
  // Height of a small control, such as a compact button or input. It is smaller than size.touch-min, so add hit area around it.
  static const double semanticSizeControlSm = 32.0;
  // Height of the default control, such as a button or input.
  static const double semanticSizeControlMd = 40.0;
  // Height of a large control, such as a main call-to-action button.
  static const double semanticSizeControlLg = 48.0;
  // Small icon size, for icons inside dense rows or badges.
  static const double semanticSizeIconSm = 16.0;
  // Default icon size, for icons next to body text and in buttons.
  static const double semanticSizeIconMd = 20.0;
  // Large icon size, for icons in headers and empty states.
  static const double semanticSizeIconLg = 24.0;
  // Corner radius of controls such as buttons and inputs. Use radius.surface for cards.
  static const double semanticRadiusControl = 6.0;
  // Corner radius of cards, panels and dialogs. Use radius.control for buttons and inputs.
  static const double semanticRadiusSurface = 8.0;
  // Fully rounded corner, for badges, chips and avatars.
  static const double semanticRadiusPill = 9999.0;
  // Width of normal borders and dividers.
  static const double semanticBorderWidthDefault = 1.0;
  // Width of the focus ring. Use it with color.border.focus.
  static const double semanticBorderWidthFocus = 2.0;
  // Font family of the display style.
  static const String semanticTextDisplayFontFamily = 'SpaceGrotesk';
  // Largest text style, for the main title of a page or a hero area.
  static const double semanticTextDisplayFontSize = 30.0;
  // Line height of the display style.
  static const double semanticTextDisplayLineHeight = 1.25;
  // Font weight of the display style.
  static const FontWeight semanticTextDisplayFontWeight = FontWeight.w700;
  // Font family of the heading-1 style.
  static const String semanticTextHeading1FontFamily = 'SpaceGrotesk';
  // Style of the main heading on a page.
  static const double semanticTextHeading1FontSize = 24.0;
  // Line height of the heading-1 style.
  static const double semanticTextHeading1LineHeight = 1.25;
  // Font weight of the heading-1 style.
  static const FontWeight semanticTextHeading1FontWeight = FontWeight.w600;
  // Font family of the heading-2 style.
  static const String semanticTextHeading2FontFamily = 'SpaceGrotesk';
  // Style of a section heading.
  static const double semanticTextHeading2FontSize = 20.0;
  // Line height of the heading-2 style.
  static const double semanticTextHeading2LineHeight = 1.375;
  // Font weight of the heading-2 style.
  static const FontWeight semanticTextHeading2FontWeight = FontWeight.w600;
  // Font family of the heading-3 style.
  static const String semanticTextHeading3FontFamily = 'SpaceGrotesk';
  // Style of a sub-section or card heading.
  static const double semanticTextHeading3FontSize = 18.0;
  // Line height of the heading-3 style.
  static const double semanticTextHeading3LineHeight = 1.375;
  // Font weight of the heading-3 style.
  static const FontWeight semanticTextHeading3FontWeight = FontWeight.w600;
  // Font family of the body style.
  static const String semanticTextBodyFontFamily = 'GeistMono';
  // Default style for paragraphs and most interface text.
  static const double semanticTextBodyFontSize = 16.0;
  // Line height of the body style.
  static const double semanticTextBodyLineHeight = 1.5;
  // Font weight of the body style.
  static const FontWeight semanticTextBodyFontWeight = FontWeight.w400;
  // Font family of the body-sm style.
  static const String semanticTextBodySmFontFamily = 'GeistMono';
  // Smaller body style, for secondary text and dense areas.
  static const double semanticTextBodySmFontSize = 14.0;
  // Line height of the body-sm style.
  static const double semanticTextBodySmLineHeight = 1.5;
  // Font weight of the body-sm style.
  static const FontWeight semanticTextBodySmFontWeight = FontWeight.w400;
  // Font family of the label style.
  static const String semanticTextLabelFontFamily = 'JetBrainsMono';
  // Style of form labels and button text.
  static const double semanticTextLabelFontSize = 14.0;
  // Line height of the label style.
  static const double semanticTextLabelLineHeight = 1.25;
  // Font weight of the label style.
  static const FontWeight semanticTextLabelFontWeight = FontWeight.w500;
  // Font family of the caption style.
  static const String semanticTextCaptionFontFamily = 'GeistMono';
  // Smallest style, for captions, helper text and metadata.
  static const double semanticTextCaptionFontSize = 12.0;
  // Line height of the caption style.
  static const double semanticTextCaptionLineHeight = 1.375;
  // Font weight of the caption style.
  static const FontWeight semanticTextCaptionFontWeight = FontWeight.w400;
  // Font family of the data style.
  static const String semanticTextDataFontFamily = 'JetBrainsMono';
  // Monospace style, for numbers, codes and technical values.
  static const double semanticTextDataFontSize = 14.0;
  // Line height of the data style.
  static const double semanticTextDataLineHeight = 1.5;
  // Font weight of the data style.
  static const FontWeight semanticTextDataFontWeight = FontWeight.w400;
  // Duration of an element that appears, such as a menu or dialog opening. Use motion.duration.exit when it leaves.
  static const Duration semanticMotionDurationEnter = Duration(
    milliseconds: 200,
  );
  // Duration of an element that leaves. It is shorter than the enter duration, so the screen feels fast.
  static const Duration semanticMotionDurationExit = Duration(
    milliseconds: 150,
  );
  // Duration of a larger movement that needs attention, such as a page-level change.
  static const Duration semanticMotionDurationEmphasis = Duration(
    milliseconds: 300,
  );
  // Easing curve for an element that appears. Use motion.easing.exit when it leaves.
  static const Cubic semanticMotionEasingEnter = Cubic(0.2, 0.0, 0.0, 1.0);
  // Easing curve for an element that leaves. It speeds up as it goes.
  static const Cubic semanticMotionEasingExit = Cubic(0.4, 0.0, 1.0, 1.0);
  // Opacity for the text and icon colours of a disabled control. The app theme applies it to those colours, not to the whole control.
  static const double semanticOpacityDisabled = 0.38;
  static const double componentButtonHeightSm = 32.0;
  static const double componentButtonHeightMd = 40.0;
  static const double componentButtonHeightLg = 48.0;
  static const double componentButtonPaddingX = 16.0;
  static const double componentButtonGap = 8.0;
  static const double componentButtonRadius = 6.0;
  static const double componentButtonFontSize = 14.0;
  static const FontWeight componentButtonFontWeight = FontWeight.w500;
  static const double componentButtonDisabledOpacity = 0.38;
  static const double componentInputHeight = 40.0;
  static const double componentInputPaddingX = 12.0;
  static const double componentInputRadius = 6.0;
  static const double componentInputFontSize = 16.0;
  static const double componentCardRadius = 8.0;
  static const double componentCardPadding = 16.0;
  static const double componentDialogRadius = 8.0;
  static const double componentDialogPadding = 24.0;
  static const double componentBadgeRadius = 9999.0;
  static const double componentBadgePaddingX = 8.0;
  static const double componentBadgeFontSize = 12.0;
  static const double componentTableCellPaddingX = 12.0;
  static const double componentTableCellPaddingY = 8.0;
  static const double componentTableFontSize = 14.0;
  static const double componentNavItemHeight = 44.0;
  static const double componentFocusRingWidth = 2.0;
  static const double componentFocusRingOffset = 2.0;
}

abstract final class DesignTokensLight {
  // Page background behind all other surfaces. Use bg.surface for cards and panels on top of it.
  static const Color semanticColorBgCanvas = Color(0xFFF8FAFC);
  // Background of cards and panels on the page canvas. Use bg.surface-raised for dialogs, menus and popovers.
  static const Color semanticColorBgSurface = Color(0xFFFFFFFF);
  // Background of layers that float above a surface, such as dialogs, menus and popovers. Use bg.surface for flat cards and panels.
  static const Color semanticColorBgSurfaceRaised = Color(0xFFFFFFFF);
  // Quiet fill for hover rows, table headers and grouped areas. Do not use it as a page or card background.
  static const Color semanticColorBgSubtle = Color(0xFFF1F5F9);
  // Dark fill in light mode and light fill in dark mode, for tooltips and toasts. Put fg.inverse text on it.
  static const Color semanticColorBgInverse = Color(0xFF0F172A);
  // Overlay behind a modal dialog or sheet. It is the same in light and dark mode.
  static const Color semanticColorBgScrim = Color(0x990F172A);
  // Main text and icon colour. Use fg.muted for secondary text.
  static const Color semanticColorFgDefault = Color(0xFF0F172A);
  // Secondary text such as descriptions and helper text. It passes text contrast on bg.canvas and bg.surface. Use fg.subtle only for non-essential text.
  static const Color semanticColorFgMuted = Color(0xFF475569);
  // Weakest text colour, for hints and non-essential detail. Its contrast is not tested. Use fg.muted for text a user must read.
  static const Color semanticColorFgSubtle = Color(0xFF64748B);
  // Text and icons on bg.inverse. Do not use it on action.primary: use fg.on-primary.
  static const Color semanticColorFgInverse = Color(0xFFFFFFFF);
  // Text and icons on action.primary and action.primary-hover. Do not use it on other fills.
  static const Color semanticColorFgOnPrimary = Color(0xFFFFFFFF);
  // Text and icons on action.accent and action.accent-hover.
  static const Color semanticColorFgOnAccent = Color(0xFFFFFFFF);
  // Text and icons on action.danger and action.danger-hover.
  static const Color semanticColorFgOnDanger = Color(0xFFFFFFFF);
  // Divider and card outline. It is decorative. Use border.control for the edge of an input or button.
  static const Color semanticColorBorderDefault = Color(0xFFE2E8F0);
  // Edge of form controls such as inputs, selects and checkboxes. It passes the 3:1 contrast needed for controls. Use border.default for dividers.
  static const Color semanticColorBorderControl = Color(0xFF64748B);
  // Focus ring colour on any interactive element. Pair it with border-width.focus. It passes 3:1 contrast on the page backgrounds.
  static const Color semanticColorBorderFocus = Color(0xFF059669);
  // Fill of the main button. Put fg.on-primary text on it. Use action.accent for the brand call to action.
  static const Color semanticColorActionPrimary = Color(0xFF334155);
  // Fill of the main button on hover or press. Put fg.on-primary text on it.
  static const Color semanticColorActionPrimaryHover = Color(0xFF1E293B);
  // Fill of the brand call-to-action button. Put fg.on-accent text on it. Use action.primary for normal main buttons.
  static const Color semanticColorActionAccent = Color(0xFF047857);
  // Fill of the accent button on hover or press. Put fg.on-accent text on it.
  static const Color semanticColorActionAccentHover = Color(0xFF065F46);
  // Fill of the secondary button. Use fg.default text on it.
  static const Color semanticColorActionSecondary = Color(0xFFF1F5F9);
  // Fill of the secondary button on hover or press.
  static const Color semanticColorActionSecondaryHover = Color(0xFFE2E8F0);
  // Fill of a destructive button, such as delete. Put fg.on-danger text on it. Use status.danger for messages.
  static const Color semanticColorActionDanger = Color(0xFFDC2626);
  // Fill of the destructive button on hover or press. Put fg.on-danger text on it.
  static const Color semanticColorActionDangerHover = Color(0xFFB91C1C);
  // Text and icon colour for a success message or badge. Use it on status.success.bg.
  static const Color semanticColorStatusSuccessFg = Color(0xFF047857);
  // Background of a success message or badge. Put status.success.fg on it.
  static const Color semanticColorStatusSuccessBg = Color(0xFFECFDF5);
  // Text and icon colour for a warning message or badge. Use it on status.warning.bg.
  static const Color semanticColorStatusWarningFg = Color(0xFFB45309);
  // Background of a warning message or badge. Put status.warning.fg on it.
  static const Color semanticColorStatusWarningBg = Color(0xFFFFFBEB);
  // Text and icon colour for an error message or badge. Use it on status.danger.bg. Use action.danger for buttons.
  static const Color semanticColorStatusDangerFg = Color(0xFFB91C1C);
  // Background of an error message or badge. Put status.danger.fg on it.
  static const Color semanticColorStatusDangerBg = Color(0xFFFEF2F2);
  // Text and icon colour for an information message or badge. Use it on status.info.bg.
  static const Color semanticColorStatusInfoFg = Color(0xFF0369A1);
  // Background of an information message or badge. Put status.info.fg on it.
  static const Color semanticColorStatusInfoBg = Color(0xFFF0F9FF);
  // Text and icon colour for a neutral status badge with no good or bad meaning. Use it on status.neutral.bg.
  static const Color semanticColorStatusNeutralFg = Color(0xFF334155);
  // Background of a neutral status badge. Put status.neutral.fg on it.
  static const Color semanticColorStatusNeutralBg = Color(0xFFF1F5F9);
  // First series colour in a chart. Use the chart colours in order 1 to 5.
  static const Color semanticColorChart1 = Color(0xFF334155);
  // Second series colour in a chart.
  static const Color semanticColorChart2 = Color(0xFF059669);
  // Third series colour in a chart.
  static const Color semanticColorChart3 = Color(0xFFF59E0B);
  // Fourth series colour in a chart.
  static const Color semanticColorChart4 = Color(0xFF0284C7);
  // Fifth series colour in a chart.
  static const Color semanticColorChart5 = Color(0xFFEF4444);
  // Background of the C-41 label: the color film type and the C-41 process label. Put process.c41.fg on it. The app uses only the fg.
  static const Color semanticColorProcessC41Bg = Color(0xFFFEF3C7);
  // Text of the C-41 label on process.c41.bg. The app uses this color for the C-41 stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessC41Fg = Color(0xFF451A03);
  // Background of the E-6 label: the slide film type and the E-6 process label. Put process.e6.fg on it. The app uses only the fg.
  static const Color semanticColorProcessE6Bg = Color(0xFFE0F2FE);
  // Text of the E-6 label on process.e6.bg. The app uses this color for the E-6 stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessE6Fg = Color(0xFF082F49);
  // Background of the ECN-2 process label and the respooled packaging label. Put process.ecn2.fg on it. The app uses only the fg.
  static const Color semanticColorProcessEcn2Bg = Color(0xFFEDE9FE);
  // Text of the ECN-2 label on process.ecn2.bg. The app uses this color for the ECN-2 stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessEcn2Fg = Color(0xFF2E1065);
  // Background of the black and white label: the BW film type and the BW process label. Put process.bw.fg on it. The app uses only the fg.
  static const Color semanticColorProcessBwBg = Color(0xFFE2E8F0);
  // Text of the black and white label on process.bw.bg. The app uses this color for the B&W stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessBwFg = Color(0xFF1E293B);
  // Background of a metadata chip, such as a lens specification. Put highlight.fg on it.
  static const Color semanticColorHighlightBg = Color(0xFFFFFBEB);
  // Text of a metadata chip on highlight.bg.
  static const Color semanticColorHighlightFg = Color(0xFF451A03);
  // Outline of a metadata chip. Use it with highlight.bg.
  static const Color semanticColorHighlightBorder = Color(0xFFFCD34D);
  // Background of the activate button on equipment detail pages, such as cameras and lenses. Put activate.fg on it. Active and Inactive badges use status colors.
  static const Color semanticColorActivateBg = Color(0xFFECFDF5);
  // Text and icons of the activate button, on activate.bg.
  static const Color semanticColorActivateFg = Color(0xFF065F46);
  // Outline of the activate button. Use it with activate.bg.
  static const Color semanticColorActivateBorder = Color(0xFF6EE7B7);
  // Background of the activate button on hover or press.
  static const Color semanticColorActivateBgHover = Color(0xFFD1FAE5);
  // Text and icons of the activate button on hover, on activate.bg-hover.
  static const Color semanticColorActivateFgHover = Color(0xFF064E3B);
  // Background of the deactivate button on equipment detail pages, such as cameras and lenses. Put deactivate.fg on it. Active and Inactive badges use status colors.
  static const Color semanticColorDeactivateBg = Color(0xFFFFFBEB);
  // Text and icons of the deactivate button, on deactivate.bg.
  static const Color semanticColorDeactivateFg = Color(0xFF92400E);
  // Outline of the deactivate button. Use it with deactivate.bg.
  static const Color semanticColorDeactivateBorder = Color(0xFFFCD34D);
  // Background of the deactivate button on hover or press.
  static const Color semanticColorDeactivateBgHover = Color(0xFFFEF3C7);
  // Text and icons of the deactivate button on hover, on deactivate.bg-hover.
  static const Color semanticColorDeactivateFgHover = Color(0xFF78350F);
  // Colour of the decorative brand stripe on the auth card. It is the same in light and dark mode. Do not use it for text or controls.
  static const Color semanticColorBrandStripe = Color(0xFF511805);
  static const Color componentButtonPrimaryBg = Color(0xFF334155);
  static const Color componentButtonPrimaryBgHover = Color(0xFF1E293B);
  static const Color componentButtonPrimaryFg = Color(0xFFFFFFFF);
  static const Color componentButtonAccentBg = Color(0xFF047857);
  static const Color componentButtonAccentBgHover = Color(0xFF065F46);
  static const Color componentButtonAccentFg = Color(0xFFFFFFFF);
  static const Color componentButtonSecondaryBg = Color(0xFFF1F5F9);
  static const Color componentButtonSecondaryBgHover = Color(0xFFE2E8F0);
  static const Color componentButtonSecondaryFg = Color(0xFF0F172A);
  static const Color componentButtonSecondaryBorder = Color(0xFFE2E8F0);
  static const Color componentButtonGhostBg = Color(0xFFFFFFFF);
  static const Color componentButtonGhostBgHover = Color(0xFFF1F5F9);
  static const Color componentButtonGhostFg = Color(0xFF0F172A);
  static const Color componentButtonDangerBg = Color(0xFFDC2626);
  static const Color componentButtonDangerBgHover = Color(0xFFB91C1C);
  static const Color componentButtonDangerFg = Color(0xFFFFFFFF);
  static const Color componentButtonActivateBg = Color(0xFFECFDF5);
  static const Color componentButtonActivateFg = Color(0xFF065F46);
  static const Color componentButtonActivateBorder = Color(0xFF6EE7B7);
  static const Color componentButtonActivateBgHover = Color(0xFFD1FAE5);
  static const Color componentButtonActivateFgHover = Color(0xFF064E3B);
  static const Color componentButtonDeactivateBg = Color(0xFFFFFBEB);
  static const Color componentButtonDeactivateFg = Color(0xFF92400E);
  static const Color componentButtonDeactivateBorder = Color(0xFFFCD34D);
  static const Color componentButtonDeactivateBgHover = Color(0xFFFEF3C7);
  static const Color componentButtonDeactivateFgHover = Color(0xFF78350F);
  static const Color componentInputBg = Color(0xFFFFFFFF);
  static const Color componentInputFg = Color(0xFF0F172A);
  static const Color componentInputPlaceholder = Color(0xFF64748B);
  static const Color componentInputBorder = Color(0xFF64748B);
  static const Color componentInputBorderFocus = Color(0xFF059669);
  static const Color componentInputBorderInvalid = Color(0xFFDC2626);
  static const Color componentInputHelper = Color(0xFF475569);
  static const Color componentInputError = Color(0xFFB91C1C);
  static const Color componentCardBg = Color(0xFFFFFFFF);
  static const Color componentCardFg = Color(0xFF0F172A);
  static const Color componentCardBorder = Color(0xFFE2E8F0);
  static const Color componentDialogBg = Color(0xFFFFFFFF);
  static const Color componentDialogFg = Color(0xFF0F172A);
  static const Color componentDialogBorder = Color(0xFFE2E8F0);
  static const Color componentDialogScrim = Color(0x990F172A);
  static const Color componentBadgeNeutralBg = Color(0xFFF1F5F9);
  static const Color componentBadgeNeutralFg = Color(0xFF334155);
  static const Color componentBadgeSuccessBg = Color(0xFFECFDF5);
  static const Color componentBadgeSuccessFg = Color(0xFF047857);
  static const Color componentBadgeWarningBg = Color(0xFFFFFBEB);
  static const Color componentBadgeWarningFg = Color(0xFFB45309);
  static const Color componentBadgeDangerBg = Color(0xFFFEF2F2);
  static const Color componentBadgeDangerFg = Color(0xFFB91C1C);
  static const Color componentBadgeInfoBg = Color(0xFFF0F9FF);
  static const Color componentBadgeInfoFg = Color(0xFF0369A1);
  static const Color componentChipHighlightBg = Color(0xFFFFFBEB);
  static const Color componentChipHighlightFg = Color(0xFF451A03);
  static const Color componentChipHighlightBorder = Color(0xFFFCD34D);
  static const Color componentAuthCardStripe = Color(0xFF511805);
  static const Color componentTableHeaderBg = Color(0xFFF1F5F9);
  static const Color componentTableHeaderFg = Color(0xFF475569);
  static const Color componentTableRowBorder = Color(0xFFE2E8F0);
  static const Color componentTableRowHover = Color(0xFFF1F5F9);
  static const Color componentNavBg = Color(0xFFFFFFFF);
  static const Color componentNavBorder = Color(0xFFE2E8F0);
  static const Color componentNavItemFg = Color(0xFF475569);
  static const Color componentNavItemFgActive = Color(0xFF0F172A);
  static const Color componentNavItemBgActive = Color(0xFFF1F5F9);
  static const Color componentNavIndicator = Color(0xFF047857);
  static const Color componentFocusRingColor = Color(0xFF059669);

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: semanticColorActionPrimary,
    onPrimary: semanticColorFgOnPrimary,
    primaryContainer: semanticColorBgSubtle,
    onPrimaryContainer: semanticColorFgDefault,
    secondary: semanticColorActionSecondary,
    onSecondary: semanticColorFgDefault,
    secondaryContainer: semanticColorBgSubtle,
    onSecondaryContainer: semanticColorFgDefault,
    tertiary: semanticColorActionAccent,
    onTertiary: semanticColorFgOnAccent,
    tertiaryContainer: semanticColorStatusSuccessBg,
    onTertiaryContainer: semanticColorStatusSuccessFg,
    error: semanticColorActionDanger,
    onError: semanticColorFgOnDanger,
    errorContainer: semanticColorStatusDangerBg,
    onErrorContainer: semanticColorStatusDangerFg,
    surface: semanticColorBgCanvas,
    onSurface: semanticColorFgDefault,
    onSurfaceVariant: semanticColorFgMuted,
    surfaceContainerLowest: semanticColorBgCanvas,
    surfaceContainerLow: semanticColorBgSurface,
    surfaceContainer: semanticColorBgSurface,
    surfaceContainerHigh: semanticColorBgSubtle,
    surfaceContainerHighest: semanticColorBgSurfaceRaised,
    outline: semanticColorBorderControl,
    outlineVariant: semanticColorBorderDefault,
    inverseSurface: semanticColorBgInverse,
    onInverseSurface: semanticColorFgInverse,
    shadow: semanticColorBgScrim,
    scrim: semanticColorBgScrim,
    inversePrimary: DesignTokensDark.semanticColorActionPrimary,
  );
}

abstract final class DesignTokensDark {
  // Page background behind all other surfaces. Use bg.surface for cards and panels on top of it.
  static const Color semanticColorBgCanvas = Color(0xFF020617);
  // Background of cards and panels on the page canvas. Use bg.surface-raised for dialogs, menus and popovers.
  static const Color semanticColorBgSurface = Color(0xFF0F172A);
  // Background of layers that float above a surface, such as dialogs, menus and popovers. Use bg.surface for flat cards and panels.
  static const Color semanticColorBgSurfaceRaised = Color(0xFF1E293B);
  // Quiet fill for hover rows, table headers and grouped areas. Do not use it as a page or card background.
  static const Color semanticColorBgSubtle = Color(0xFF1E293B);
  // Dark fill in light mode and light fill in dark mode, for tooltips and toasts. Put fg.inverse text on it.
  static const Color semanticColorBgInverse = Color(0xFFF8FAFC);
  // Overlay behind a modal dialog or sheet. It is the same in light and dark mode.
  static const Color semanticColorBgScrim = Color(0x990F172A);
  // Main text and icon colour. Use fg.muted for secondary text.
  static const Color semanticColorFgDefault = Color(0xFFF8FAFC);
  // Secondary text such as descriptions and helper text. It passes text contrast on bg.canvas and bg.surface. Use fg.subtle only for non-essential text.
  static const Color semanticColorFgMuted = Color(0xFFCBD5E1);
  // Weakest text colour, for hints and non-essential detail. Its contrast is not tested. Use fg.muted for text a user must read.
  static const Color semanticColorFgSubtle = Color(0xFF94A3B8);
  // Text and icons on bg.inverse. Do not use it on action.primary: use fg.on-primary.
  static const Color semanticColorFgInverse = Color(0xFF020617);
  // Text and icons on action.primary and action.primary-hover. Do not use it on other fills.
  static const Color semanticColorFgOnPrimary = Color(0xFF0F172A);
  // Text and icons on action.accent and action.accent-hover.
  static const Color semanticColorFgOnAccent = Color(0xFF020617);
  // Text and icons on action.danger and action.danger-hover.
  static const Color semanticColorFgOnDanger = Color(0xFF020617);
  // Divider and card outline. It is decorative. Use border.control for the edge of an input or button.
  static const Color semanticColorBorderDefault = Color(0xFF1E293B);
  // Edge of form controls such as inputs, selects and checkboxes. It passes the 3:1 contrast needed for controls. Use border.default for dividers.
  static const Color semanticColorBorderControl = Color(0xFF64748B);
  // Focus ring colour on any interactive element. Pair it with border-width.focus. It passes 3:1 contrast on the page backgrounds.
  static const Color semanticColorBorderFocus = Color(0xFF34D399);
  // Fill of the main button. Put fg.on-primary text on it. Use action.accent for the brand call to action.
  static const Color semanticColorActionPrimary = Color(0xFFE2E8F0);
  // Fill of the main button on hover or press. Put fg.on-primary text on it.
  static const Color semanticColorActionPrimaryHover = Color(0xFFCBD5E1);
  // Fill of the brand call-to-action button. Put fg.on-accent text on it. Use action.primary for normal main buttons.
  static const Color semanticColorActionAccent = Color(0xFF34D399);
  // Fill of the accent button on hover or press. Put fg.on-accent text on it.
  static const Color semanticColorActionAccentHover = Color(0xFF6EE7B7);
  // Fill of the secondary button. Use fg.default text on it.
  static const Color semanticColorActionSecondary = Color(0xFF1E293B);
  // Fill of the secondary button on hover or press.
  static const Color semanticColorActionSecondaryHover = Color(0xFF334155);
  // Fill of a destructive button, such as delete. Put fg.on-danger text on it. Use status.danger for messages.
  static const Color semanticColorActionDanger = Color(0xFFF87171);
  // Fill of the destructive button on hover or press. Put fg.on-danger text on it.
  static const Color semanticColorActionDangerHover = Color(0xFFFCA5A5);
  // Text and icon colour for a success message or badge. Use it on status.success.bg.
  static const Color semanticColorStatusSuccessFg = Color(0xFF34D399);
  // Background of a success message or badge. Put status.success.fg on it.
  static const Color semanticColorStatusSuccessBg = Color(0xFF022C22);
  // Text and icon colour for a warning message or badge. Use it on status.warning.bg.
  static const Color semanticColorStatusWarningFg = Color(0xFFFBBF24);
  // Background of a warning message or badge. Put status.warning.fg on it.
  static const Color semanticColorStatusWarningBg = Color(0xFF451A03);
  // Text and icon colour for an error message or badge. Use it on status.danger.bg. Use action.danger for buttons.
  static const Color semanticColorStatusDangerFg = Color(0xFFF87171);
  // Background of an error message or badge. Put status.danger.fg on it.
  static const Color semanticColorStatusDangerBg = Color(0xFF450A0A);
  // Text and icon colour for an information message or badge. Use it on status.info.bg.
  static const Color semanticColorStatusInfoFg = Color(0xFF38BDF8);
  // Background of an information message or badge. Put status.info.fg on it.
  static const Color semanticColorStatusInfoBg = Color(0xFF082F49);
  // Text and icon colour for a neutral status badge with no good or bad meaning. Use it on status.neutral.bg.
  static const Color semanticColorStatusNeutralFg = Color(0xFFCBD5E1);
  // Background of a neutral status badge. Put status.neutral.fg on it.
  static const Color semanticColorStatusNeutralBg = Color(0xFF1E293B);
  // First series colour in a chart. Use the chart colours in order 1 to 5.
  static const Color semanticColorChart1 = Color(0xFFCBD5E1);
  // Second series colour in a chart.
  static const Color semanticColorChart2 = Color(0xFF34D399);
  // Third series colour in a chart.
  static const Color semanticColorChart3 = Color(0xFFFBBF24);
  // Fourth series colour in a chart.
  static const Color semanticColorChart4 = Color(0xFF38BDF8);
  // Fifth series colour in a chart.
  static const Color semanticColorChart5 = Color(0xFFF87171);
  // Background of the C-41 label: the color film type and the C-41 process label. Put process.c41.fg on it. The app uses only the fg.
  static const Color semanticColorProcessC41Bg = Color(0xFF451A03);
  // Text of the C-41 label on process.c41.bg. The app uses this color for the C-41 stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessC41Fg = Color(0xFFFEF3C7);
  // Background of the E-6 label: the slide film type and the E-6 process label. Put process.e6.fg on it. The app uses only the fg.
  static const Color semanticColorProcessE6Bg = Color(0xFF082F49);
  // Text of the E-6 label on process.e6.bg. The app uses this color for the E-6 stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessE6Fg = Color(0xFFE0F2FE);
  // Background of the ECN-2 process label and the respooled packaging label. Put process.ecn2.fg on it. The app uses only the fg.
  static const Color semanticColorProcessEcn2Bg = Color(0xFF2E1065);
  // Text of the ECN-2 label on process.ecn2.bg. The app uses this color for the ECN-2 stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessEcn2Fg = Color(0xFFEDE9FE);
  // Background of the black and white label: the BW film type and the BW process label. Put process.bw.fg on it. The app uses only the fg.
  static const Color semanticColorProcessBwBg = Color(0xFF334155);
  // Text of the black and white label on process.bw.bg. The app uses this color for the B&W stamp, which draws its own tinted fill and border.
  static const Color semanticColorProcessBwFg = Color(0xFFF1F5F9);
  // Background of a metadata chip, such as a lens specification. Put highlight.fg on it.
  static const Color semanticColorHighlightBg = Color(0xFF451A03);
  // Text of a metadata chip on highlight.bg.
  static const Color semanticColorHighlightFg = Color(0xFFFEF3C7);
  // Outline of a metadata chip. Use it with highlight.bg.
  static const Color semanticColorHighlightBorder = Color(0xFF92400E);
  // Background of the activate button on equipment detail pages, such as cameras and lenses. Put activate.fg on it. Active and Inactive badges use status colors.
  static const Color semanticColorActivateBg = Color(0xFF022C22);
  // Text and icons of the activate button, on activate.bg.
  static const Color semanticColorActivateFg = Color(0xFFA7F3D0);
  // Outline of the activate button. Use it with activate.bg.
  static const Color semanticColorActivateBorder = Color(0xFF065F46);
  // Background of the activate button on hover or press.
  static const Color semanticColorActivateBgHover = Color(0xFF064E3B);
  // Text and icons of the activate button on hover, on activate.bg-hover.
  static const Color semanticColorActivateFgHover = Color(0xFFA7F3D0);
  // Background of the deactivate button on equipment detail pages, such as cameras and lenses. Put deactivate.fg on it. Active and Inactive badges use status colors.
  static const Color semanticColorDeactivateBg = Color(0xFF451A03);
  // Text and icons of the deactivate button, on deactivate.bg.
  static const Color semanticColorDeactivateFg = Color(0xFFFDE68A);
  // Outline of the deactivate button. Use it with deactivate.bg.
  static const Color semanticColorDeactivateBorder = Color(0xFF92400E);
  // Background of the deactivate button on hover or press.
  static const Color semanticColorDeactivateBgHover = Color(0xFF78350F);
  // Text and icons of the deactivate button on hover, on deactivate.bg-hover.
  static const Color semanticColorDeactivateFgHover = Color(0xFFFDE68A);
  // Colour of the decorative brand stripe on the auth card. It is the same in light and dark mode. Do not use it for text or controls.
  static const Color semanticColorBrandStripe = Color(0xFF511805);
  static const Color componentButtonPrimaryBg = Color(0xFFE2E8F0);
  static const Color componentButtonPrimaryBgHover = Color(0xFFCBD5E1);
  static const Color componentButtonPrimaryFg = Color(0xFF0F172A);
  static const Color componentButtonAccentBg = Color(0xFF34D399);
  static const Color componentButtonAccentBgHover = Color(0xFF6EE7B7);
  static const Color componentButtonAccentFg = Color(0xFF020617);
  static const Color componentButtonSecondaryBg = Color(0xFF1E293B);
  static const Color componentButtonSecondaryBgHover = Color(0xFF334155);
  static const Color componentButtonSecondaryFg = Color(0xFFF8FAFC);
  static const Color componentButtonSecondaryBorder = Color(0xFF1E293B);
  static const Color componentButtonGhostBg = Color(0xFF0F172A);
  static const Color componentButtonGhostBgHover = Color(0xFF1E293B);
  static const Color componentButtonGhostFg = Color(0xFFF8FAFC);
  static const Color componentButtonDangerBg = Color(0xFFF87171);
  static const Color componentButtonDangerBgHover = Color(0xFFFCA5A5);
  static const Color componentButtonDangerFg = Color(0xFF020617);
  static const Color componentButtonActivateBg = Color(0xFF022C22);
  static const Color componentButtonActivateFg = Color(0xFFA7F3D0);
  static const Color componentButtonActivateBorder = Color(0xFF065F46);
  static const Color componentButtonActivateBgHover = Color(0xFF064E3B);
  static const Color componentButtonActivateFgHover = Color(0xFFA7F3D0);
  static const Color componentButtonDeactivateBg = Color(0xFF451A03);
  static const Color componentButtonDeactivateFg = Color(0xFFFDE68A);
  static const Color componentButtonDeactivateBorder = Color(0xFF92400E);
  static const Color componentButtonDeactivateBgHover = Color(0xFF78350F);
  static const Color componentButtonDeactivateFgHover = Color(0xFFFDE68A);
  static const Color componentInputBg = Color(0xFF0F172A);
  static const Color componentInputFg = Color(0xFFF8FAFC);
  static const Color componentInputPlaceholder = Color(0xFF94A3B8);
  static const Color componentInputBorder = Color(0xFF64748B);
  static const Color componentInputBorderFocus = Color(0xFF34D399);
  static const Color componentInputBorderInvalid = Color(0xFFF87171);
  static const Color componentInputHelper = Color(0xFFCBD5E1);
  static const Color componentInputError = Color(0xFFF87171);
  static const Color componentCardBg = Color(0xFF0F172A);
  static const Color componentCardFg = Color(0xFFF8FAFC);
  static const Color componentCardBorder = Color(0xFF1E293B);
  static const Color componentDialogBg = Color(0xFF1E293B);
  static const Color componentDialogFg = Color(0xFFF8FAFC);
  static const Color componentDialogBorder = Color(0xFF1E293B);
  static const Color componentDialogScrim = Color(0x990F172A);
  static const Color componentBadgeNeutralBg = Color(0xFF1E293B);
  static const Color componentBadgeNeutralFg = Color(0xFFCBD5E1);
  static const Color componentBadgeSuccessBg = Color(0xFF022C22);
  static const Color componentBadgeSuccessFg = Color(0xFF34D399);
  static const Color componentBadgeWarningBg = Color(0xFF451A03);
  static const Color componentBadgeWarningFg = Color(0xFFFBBF24);
  static const Color componentBadgeDangerBg = Color(0xFF450A0A);
  static const Color componentBadgeDangerFg = Color(0xFFF87171);
  static const Color componentBadgeInfoBg = Color(0xFF082F49);
  static const Color componentBadgeInfoFg = Color(0xFF38BDF8);
  static const Color componentChipHighlightBg = Color(0xFF451A03);
  static const Color componentChipHighlightFg = Color(0xFFFEF3C7);
  static const Color componentChipHighlightBorder = Color(0xFF92400E);
  static const Color componentAuthCardStripe = Color(0xFF511805);
  static const Color componentTableHeaderBg = Color(0xFF1E293B);
  static const Color componentTableHeaderFg = Color(0xFFCBD5E1);
  static const Color componentTableRowBorder = Color(0xFF1E293B);
  static const Color componentTableRowHover = Color(0xFF1E293B);
  static const Color componentNavBg = Color(0xFF0F172A);
  static const Color componentNavBorder = Color(0xFF1E293B);
  static const Color componentNavItemFg = Color(0xFFCBD5E1);
  static const Color componentNavItemFgActive = Color(0xFFF8FAFC);
  static const Color componentNavItemBgActive = Color(0xFF1E293B);
  static const Color componentNavIndicator = Color(0xFF34D399);
  static const Color componentFocusRingColor = Color(0xFF34D399);

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: semanticColorActionPrimary,
    onPrimary: semanticColorFgOnPrimary,
    primaryContainer: semanticColorBgSubtle,
    onPrimaryContainer: semanticColorFgDefault,
    secondary: semanticColorActionSecondary,
    onSecondary: semanticColorFgDefault,
    secondaryContainer: semanticColorBgSubtle,
    onSecondaryContainer: semanticColorFgDefault,
    tertiary: semanticColorActionAccent,
    onTertiary: semanticColorFgOnAccent,
    tertiaryContainer: semanticColorStatusSuccessBg,
    onTertiaryContainer: semanticColorStatusSuccessFg,
    error: semanticColorActionDanger,
    onError: semanticColorFgOnDanger,
    errorContainer: semanticColorStatusDangerBg,
    onErrorContainer: semanticColorStatusDangerFg,
    surface: semanticColorBgCanvas,
    onSurface: semanticColorFgDefault,
    onSurfaceVariant: semanticColorFgMuted,
    surfaceContainerLowest: semanticColorBgCanvas,
    surfaceContainerLow: semanticColorBgSurface,
    surfaceContainer: semanticColorBgSurface,
    surfaceContainerHigh: semanticColorBgSubtle,
    surfaceContainerHighest: semanticColorBgSurfaceRaised,
    outline: semanticColorBorderControl,
    outlineVariant: semanticColorBorderDefault,
    inverseSurface: semanticColorBgInverse,
    onInverseSurface: semanticColorFgInverse,
    shadow: semanticColorBgScrim,
    scrim: semanticColorBgScrim,
    inversePrimary: DesignTokensLight.semanticColorActionPrimary,
  );
}
