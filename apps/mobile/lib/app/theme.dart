import 'package:flutter/material.dart';

@immutable
class WaydayColors extends ThemeExtension<WaydayColors> {
  const WaydayColors({
    required this.mist,
    required this.accent,
    required this.link,
  });
  final Color mist;
  final Color accent;
  final Color link;
  static const canvas = Color(0xFFFBFBF8);
  static const cornflower = Color(0xFF6AA6DA);
  static const referenceMist = Color(0xFFDBE3E9);
  static const black = Color(0xFF000000);
  @override
  WaydayColors copyWith({Color? mist, Color? accent, Color? link}) =>
      WaydayColors(
        mist: mist ?? this.mist,
        accent: accent ?? this.accent,
        link: link ?? this.link,
      );
  @override
  WaydayColors lerp(covariant WaydayColors? other, double t) => other == null
      ? this
      : WaydayColors(
          mist: Color.lerp(mist, other.mist, t)!,
          accent: Color.lerp(accent, other.accent, t)!,
          link: Color.lerp(link, other.link, t)!,
        );
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: WaydayColors.cornflower,
        brightness: Brightness.light,
      ).copyWith(
        primary: WaydayColors.cornflower,
        onPrimary: const Color(0xFF102D44),
        secondary: const Color(0xFF285C86),
        onSecondaryContainer: const Color(0xFF285C86),
        secondaryContainer: const Color(0xFFE5F0F9),
        surface: Colors.white,
        onSurface: const Color(0xFF1D2C38),
        onSurfaceVariant: const Color(0xFF5A6C7B),
        outlineVariant: const Color(0xFFDEE7ED),
        surfaceContainerHighest: const Color(0xFFF0F5F8),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Figtree',
    brightness: Brightness.light,
  );
  const actionSize = Size(48, 56);
  const actionPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);
  final actionShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  const actionText = TextStyle(
    fontFamily: 'Figtree',
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  return base.copyWith(
    scaffoldBackgroundColor: WaydayColors.canvas,
    extensions: const [
      WaydayColors(
        mist: WaydayColors.referenceMist,
        accent: WaydayColors.cornflower,
        link: Color(0xFF285C86),
      ),
    ],
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -.35,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: WaydayColors.canvas,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 24,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.secondaryContainer,
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        fontFamily: 'Figtree',
        color: scheme.onSecondaryContainer,
        height: 1.4,
      ),
      actionTextColor: scheme.onSecondaryContainer,
      elevation: 1,
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: actionSize,
        padding: actionPadding,
        elevation: 0,
        shape: actionShape,
        textStyle: actionText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: actionSize,
        padding: actionPadding,
        shape: actionShape,
        textStyle: actionText,
        foregroundColor: scheme.secondary,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.secondary,
        minimumSize: const Size(48, 48),
        shape: actionShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: scheme.onSurfaceVariant,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: WaydayColors.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      height: 76,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? scheme.secondary
              : scheme.onSurfaceVariant,
        ),
      ),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.secondary, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

extension WaydayTheme on BuildContext {
  WaydayColors get wayday => Theme.of(this).extension<WaydayColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get type => Theme.of(this).textTheme;
}
