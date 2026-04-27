import 'package:flutter/material.dart';
import 'plugin/remui.dart';
import 'plugin/remui_page.dart';

const Color _backgroundColor = Color(0xFFF5F1E8);
const Color _surfaceColor = Color(0xFFFFFCF7);
const Color _surfaceVariantColor = Color(0xFFE9DED0);
const Color _primaryColor = Color(0xFF153A7A);
const Color _secondaryColor = Color(0xFFB45309);
const Color _tertiaryColor = Color(0xFF0F766E);
const Color _inkColor = Color(0xFF16202F);
const Color _mutedInkColor = Color(0xFF5A6676);

ThemeData _buildTheme() {
  final colorScheme =
      ColorScheme.light(
        primary: _primaryColor,
        onPrimary: Colors.white,
        secondary: _secondaryColor,
        onSecondary: Colors.white,
        tertiary: _tertiaryColor,
        onTertiary: Colors.white,
        error: const Color(0xFFB42318),
        onError: Colors.white,
        background: _backgroundColor,
        onBackground: _inkColor,
        surface: _surfaceColor,
        onSurface: _inkColor,
      ).copyWith(
        surfaceVariant: _surfaceVariantColor,
        onSurfaceVariant: _mutedInkColor,
        outline: const Color(0xFFCDBFAE),
        outlineVariant: const Color(0xFFE0D7CA),
        primaryContainer: const Color(0xFFDCE7FF),
        onPrimaryContainer: _primaryColor,
        secondaryContainer: const Color(0xFFFDE5D2),
        onSecondaryContainer: _secondaryColor,
        tertiaryContainer: const Color(0xFFD7F3EE),
        onTertiaryContainer: _tertiaryColor,
        shadow: const Color(0x2E0F172A),
      );

  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _backgroundColor,
    canvasColor: _backgroundColor,
    fontFamily: 'Aptos',
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: const AppBarTheme(
      backgroundColor: _backgroundColor,
      foregroundColor: _inkColor,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 72,
      iconTheme: IconThemeData(color: _primaryColor, size: 22),
      titleTextStyle: TextStyle(
        color: _inkColor,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: _inkColor,
        fontSize: 56,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      displayMedium: TextStyle(
        color: _inkColor,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      displaySmall: TextStyle(
        color: _inkColor,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headlineLarge: TextStyle(
        color: _inkColor,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: _inkColor,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        color: _inkColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        color: _inkColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: _inkColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: _inkColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: _inkColor, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: _mutedInkColor, fontSize: 14, height: 1.45),
      bodySmall: TextStyle(color: _mutedInkColor, fontSize: 12, height: 1.4),
      labelLarge: TextStyle(
        color: _inkColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: _inkColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: _mutedInkColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    primaryTextTheme: const TextTheme(
      titleLarge: TextStyle(
        color: _inkColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: _inkColor, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: _mutedInkColor, fontSize: 14, height: 1.45),
    ),
    cardTheme: CardThemeData(
      color: _surfaceColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: colorScheme.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant ?? _surfaceVariantColor,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: const TextStyle(
        color: _inkColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: _mutedInkColor,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surfaceColor,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant ?? _surfaceVariantColor,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: _primaryColor, size: 22),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      iconColor: _primaryColor,
      textColor: _inkColor,
      titleTextStyle: TextStyle(
        color: _inkColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(
        color: _mutedInkColor,
        fontSize: 13,
        height: 1.45,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _inkColor,
      width: 450,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant ?? _surfaceVariantColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant ?? _surfaceVariantColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primaryColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB42318)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.6),
      ),
      hintStyle: const TextStyle(color: _mutedInkColor, fontSize: 14),
      labelStyle: const TextStyle(color: _mutedInkColor, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _tertiaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _inkColor,
        side: BorderSide(color: colorScheme.outline ?? _surfaceVariantColor),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: _primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return _primaryColor;
        }
        return Colors.transparent;
      }),
      checkColor: MaterialStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.white;
        }
        return const Color(0xFFF6F0E7);
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return _primaryColor;
        }
        return const Color(0xFFD8CFBF);
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return _primaryColor;
        }
        return _mutedInkColor;
      }),
    ),
  );
}

void main() {
  RemUI.init(
    "http://localhost:3000",
    {"mediaQuery": true},
    pageFunction: {
      ".main": (onClick, url) {
        if (url == "/next") {
          RemUI.changePage("/ui/next");
        }
      },
    },
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: RemUI.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const RemUIPage(path: "/ui/main"),
    );
  }
}
