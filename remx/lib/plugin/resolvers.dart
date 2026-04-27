import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Resolv {
  static const Map<String, Color> _namedColors = {
    'transparent': Colors.transparent,
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'pink': Colors.pink,
    'purple': Colors.purple,
    'deeppurple': Colors.deepPurple,
    'indigo': Colors.indigo,
    'blue': Colors.blue,
    'lightblue': Colors.lightBlue,
    'cyan': Colors.cyan,
    'teal': Colors.teal,
    'green': Colors.green,
    'lightgreen': Colors.lightGreen,
    'lime': Colors.lime,
    'yellow': Colors.yellow,
    'amber': Colors.amber,
    'orange': Colors.orange,
    'deeporange': Colors.deepOrange,
    'brown': Colors.brown,
    'grey': Colors.grey,
    'bluegrey': Colors.blueGrey,
  };

  static IconData? icon(dynamic value, {IconData? fallback}) {
    if (value == null) return fallback;

    if (value is IconData) return value;

    if (value is int) {
      return IconData(int.parse(value.toString()), fontFamily: 'MaterialIcons');
    }

    if (value is! String) {
      return fallback;
    }

    final raw = value.trim();
    if (raw.isEmpty) return fallback;

    var token = raw;
    if (token.toLowerCase().startsWith('m:')) {
      token = token.substring(2).trim();
    }

    final codePoint = _parseMaterialCodePoint(token);
    if (codePoint == null) return fallback;

    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }

  static Color? color(dynamic value, {BuildContext? context, Color? fallback}) {
    if (value == null) return fallback;

    if (value is Color) return value;

    if (value is int) {
      return Color(value);
    }

    if (value is! String) {
      return fallback;
    }

    final raw = value.trim();
    if (raw.isEmpty) return fallback;

    final normalized = raw.replaceAll(' ', '');

    final hex = _parseHex(normalized);
    if (hex != null) return hex;

    final token = _normalizeToken(normalized);

    final named = _namedColors[token];
    if (named != null) return named;

    if (context != null) {
      final scheme = Theme.of(context).colorScheme;
      final themeColor = _themeColor(token, scheme);
      if (themeColor != null) return themeColor;
    }

    return fallback;
  }

  static FontWeight? fontWeight(dynamic value, {FontWeight? fallback}) {
    if (value == null) return fallback;

    if (value is FontWeight) return value;

    if (value is int) {
      switch (value) {
        case 100:
          return FontWeight.w100;
        case 200:
          return FontWeight.w200;
        case 300:
          return FontWeight.w300;
        case 400:
          return FontWeight.w400;
        case 500:
          return FontWeight.w500;
        case 600:
          return FontWeight.w600;
        case 700:
          return FontWeight.w700;
        case 800:
          return FontWeight.w800;
        case 900:
          return FontWeight.w900;
      }
    }

    if (value is! String) {
      return fallback;
    }

    final token = value.trim().toLowerCase();
    switch (token) {
      case 'thin':
      case 'w100':
      case '100':
        return FontWeight.w100;
      case 'extralight':
      case 'ultralight':
      case 'w200':
      case '200':
        return FontWeight.w200;
      case 'light':
      case 'w300':
      case '300':
        return FontWeight.w300;
      case 'normal':
      case 'regular':
      case 'w400':
      case '400':
        return FontWeight.w400;
      case 'medium':
      case 'w500':
      case '500':
        return FontWeight.w500;
      case 'semibold':
      case 'demibold':
      case 'w600':
      case '600':
        return FontWeight.w600;
      case 'bold':
      case 'w700':
      case '700':
        return FontWeight.w700;
      case 'extrabold':
      case 'ultrabold':
      case 'w800':
      case '800':
        return FontWeight.w800;
      case 'black':
      case 'heavy':
      case 'w900':
      case '900':
        return FontWeight.w900;
      default:
        return fallback;
    }
  }

  static Alignment? resolveAlignment(dynamic value, {Alignment? fallback}) {
    if (value is Alignment) return value;
    if (value is! String) return fallback;

    switch (_normalizeToken(value.trim())) {
      case 'topleft':
        return Alignment.topLeft;
      case 'topcenter':
      case 'top':
        return Alignment.topCenter;
      case 'topright':
        return Alignment.topRight;
      case 'centerleft':
      case 'left':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'centerright':
      case 'right':
        return Alignment.centerRight;
      case 'bottomleft':
        return Alignment.bottomLeft;
      case 'bottomcenter':
      case 'bottom':
        return Alignment.bottomCenter;
      case 'bottomright':
        return Alignment.bottomRight;
      default:
        return fallback;
    }
  }

  static MainAxisAlignment resolvMainAxis(
    dynamic value, {
    MainAxisAlignment fallback = MainAxisAlignment.start,
  }) {
    if (value is MainAxisAlignment) return value;
    if (value is! String) return fallback;

    switch (_normalizeToken(value.trim())) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'center':
        return MainAxisAlignment.center;
      case 'spacebetween':
      case 'between':
        return MainAxisAlignment.spaceBetween;
      case 'spacearound':
      case 'around':
        return MainAxisAlignment.spaceAround;
      case 'spaceevenly':
      case 'evenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return fallback;
    }
  }

  static CrossAxisAlignment resolveCrossAxis(
    dynamic value, {
    CrossAxisAlignment fallback = CrossAxisAlignment.center,
  }) {
    if (value is CrossAxisAlignment) return value;
    if (value is! String) return fallback;

    switch (_normalizeToken(value.trim())) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'center':
        return CrossAxisAlignment.center;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'baseline':
        return CrossAxisAlignment.baseline;
      default:
        return fallback;
    }
  }

  static int? _parseMaterialCodePoint(String input) {
    final token = input.trim();
    if (token.isEmpty) return null;

    if (token.startsWith('0x') || token.startsWith('0X')) {
      return int.tryParse(token.substring(2), radix: 16);
    }

    if (token.startsWith('u+') || token.startsWith('U+')) {
      return int.tryParse(token.substring(2), radix: 16);
    }

    if (token.startsWith('#')) {
      return int.tryParse(token.substring(1), radix: 16);
    }

    // Hex token without prefix, e.g. E145.
    if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(token) &&
        RegExp(r'[A-Fa-f]').hasMatch(token)) {
      return int.tryParse(token, radix: 16);
    }

    return null;
  }

  static Color? _parseHex(String input) {
    if (!input.startsWith('#')) return null;

    final hex = input.substring(1);

    if (hex.length == 3) {
      final r = hex[0];
      final g = hex[1];
      final b = hex[2];
      return _fromHex('FF$r$r$g$g$b$b');
    }

    if (hex.length == 4) {
      final a = hex[0];
      final r = hex[1];
      final g = hex[2];
      final b = hex[3];
      return _fromHex('$a$a$r$r$g$g$b$b');
    }

    if (hex.length == 6) {
      return _fromHex('FF$hex');
    }

    if (hex.length == 8) {
      return _fromHex(hex);
    }

    return null;
  }

  static Color? _fromHex(String hex) {
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static String _normalizeToken(String input) {
    if (input.isEmpty) return input;

    final lower = input.toLowerCase();

    return lower
        .replaceAll('color.', '')
        .replaceAll('theme:', '')
        .replaceAll('scheme.', '');
  }

  static Color? _themeColor(String token, ColorScheme s) {
    switch (token) {
      case 'primary':
        return s.primary;
      case 'onprimary':
        return s.onPrimary;
      case 'primarycontainer':
        return s.primaryContainer;
      case 'onprimarycontainer':
        return s.onPrimaryContainer;
      case 'secondary':
        return s.secondary;
      case 'onsecondary':
        return s.onSecondary;
      case 'secondarycontainer':
        return s.secondaryContainer;
      case 'onsecondarycontainer':
        return s.onSecondaryContainer;
      case 'tertiary':
        return s.tertiary;
      case 'ontertiary':
        return s.onTertiary;
      case 'tertiarycontainer':
        return s.tertiaryContainer;
      case 'ontertiarycontainer':
        return s.onTertiaryContainer;
      case 'error':
        return s.error;
      case 'onerror':
        return s.onError;
      case 'errorcontainer':
        return s.errorContainer;
      case 'onerrorcontainer':
        return s.onErrorContainer;
      case 'surface':
        return s.surface;
      case 'onsurface':
        return s.onSurface;
      case 'surfacevariant':
        return s.surfaceVariant;
      case 'onsurfacevariant':
        return s.onSurfaceVariant;
      case 'outline':
        return s.outline;
      case 'outlinevariant':
        return s.outlineVariant;
      case 'shadow':
        return s.shadow;
      case 'scrim':
        return s.scrim;
      case 'inverseprimary':
        return s.inversePrimary;
      case 'inversesurface':
        return s.inverseSurface;
      case 'oninversesurface':
        return s.onInverseSurface;
      default:
        return null;
    }
  }
}
