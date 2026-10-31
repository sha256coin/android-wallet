import 'package:flutter/material.dart';

import 'package:s256_wallet/widgets/app_background.dart';

/// "Digital Platinum": the look of sha256coin.eu. Graphite ground, flat
/// square cards with hairline borders, one amber accent from the coin logo.
class S256Theme {
  static const String display = 'ChakraPetch';
  static const String body = 'IBMPlexSans';
  static const String mono = 'IBMPlexMono';

  /// Corner radius of cards, buttons and inputs.
  static const double radius = 2;
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(radius));

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: S256Colors.primary,
      onPrimary: S256Colors.onPrimary,
      secondary: S256Colors.accent,
      onSecondary: S256Colors.onPrimary,
      tertiary: S256Colors.accent,
      surface: S256Colors.cardBg,
      onSurface: S256Colors.text,
      error: S256Colors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: body,
      scaffoldBackgroundColor: S256Colors.darkBg,
      colorScheme: scheme,
      dividerColor: S256Colors.line,
    );

    // Headings and numbers in Chakra Petch, everything else in Plex Sans.
    TextStyle? heading(TextStyle? s) => s?.copyWith(fontFamily: display, fontWeight: FontWeight.w600);
    final text = base.textTheme.apply(bodyColor: S256Colors.text, displayColor: S256Colors.text);

    const shape = RoundedRectangleBorder(borderRadius: borderRadius);

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: heading(text.displayLarge),
        displayMedium: heading(text.displayMedium),
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: heading(text.titleLarge),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: S256Colors.darkBg,
        foregroundColor: S256Colors.text,
        titleTextStyle: const TextStyle(
          fontFamily: display,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: 0.4,
          color: S256Colors.text,
        ),
        shape: const Border(bottom: BorderSide(color: S256Colors.line)),
      ),
      cardTheme: const CardThemeData(
        color: S256Colors.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: S256Colors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: S256Colors.primary,
          foregroundColor: S256Colors.onPrimary,
          disabledBackgroundColor: S256Colors.surface2,
          disabledForegroundColor: S256Colors.textLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: S256Colors.primary,
          foregroundColor: S256Colors.onPrimary,
          shape: shape,
          textStyle: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: S256Colors.text,
          side: const BorderSide(color: S256Colors.lineStrong),
          shape: shape,
          textStyle: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: S256Colors.primary,
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: S256Colors.darkBg,
        labelStyle: const TextStyle(color: S256Colors.textLight),
        hintStyle: const TextStyle(color: S256Colors.textLight),
        border: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: S256Colors.lineStrong),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: S256Colors.lineStrong),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: S256Colors.primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: S256Colors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: S256Colors.danger, width: 1.5),
        ),
      ),
      // Dialogs float over the wallet like a heads-up display: amber
      // corner brackets on a hairline frame (as in the web wallet).
      dialogTheme: const DialogThemeData(
        backgroundColor: S256Colors.cardBg,
        elevation: 0,
        shape: BracketBorder(),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: S256Colors.surface2,
          borderRadius: borderRadius,
          border: Border.fromBorderSide(BorderSide(color: S256Colors.lineStrong)),
        ),
        textStyle: TextStyle(color: S256Colors.text, fontSize: 12, fontFamily: body),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: S256Colors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: S256Colors.lineStrong),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: S256Colors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: S256Colors.lineStrong),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: S256Colors.surface2,
        contentTextStyle: TextStyle(color: S256Colors.text),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: S256Colors.lineStrong),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? S256Colors.onPrimary : S256Colors.textLight),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? S256Colors.primary : S256Colors.surface2),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? S256Colors.primary : S256Colors.lineStrong),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: borderRadius),
        side: const BorderSide(color: S256Colors.lineStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? S256Colors.primary : Colors.transparent),
        checkColor: WidgetStateProperty.all(S256Colors.onPrimary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: S256Colors.primary),
      dividerTheme: const DividerThemeData(color: S256Colors.line, thickness: 1),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: shape,
          selectedBackgroundColor: S256Colors.primary,
          selectedForegroundColor: S256Colors.onPrimary,
          side: const BorderSide(color: S256Colors.lineStrong),
        ),
      ),
    );
  }
}

/// A square frame with a hairline border and amber corner brackets, for
/// shapes that Flutter paints itself (dialogs).
class BracketBorder extends RoundedRectangleBorder {
  final Color bracketColor;

  const BracketBorder({this.bracketColor = S256Colors.primary})
      : super(
          borderRadius: S256Theme.borderRadius,
          side: const BorderSide(color: S256Colors.lineStrong),
        );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    super.paint(canvas, rect, textDirection: textDirection);
    const len = 14.0;
    final p = Paint()
      ..color = bracketColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    canvas.drawPath(
      Path()
        ..moveTo(l, t + len)..lineTo(l, t)..lineTo(l + len, t)
        ..moveTo(r - len, t)..lineTo(r, t)..lineTo(r, t + len)
        ..moveTo(r, b - len)..lineTo(r, b)..lineTo(r - len, b)
        ..moveTo(l + len, b)..lineTo(l, b)..lineTo(l, b - len),
      p,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}
