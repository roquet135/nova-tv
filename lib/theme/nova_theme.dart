import 'package:flutter/material.dart';

/// Identite visuelle NOVA : cyan electrique -> violet, fond quasi noir.
class NovaColors {
  static const Color bg = Color(0xFF05060A);
  static const Color surface = Color(0xFF0E1018);
  static const Color surfaceHigh = Color(0xFF161A26);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color magenta = Color(0xFFD946EF);
  static const Color text = Color(0xFFF2F4F8);
  static const Color textDim = Color(0xFF8A91A6);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, violet, magenta],
  );

  static const LinearGradient focusGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, violet],
  );
}

class NovaTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: NovaColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: NovaColors.cyan,
        secondary: NovaColors.violet,
        surface: NovaColors.surface,
      ),
      cardColor: NovaColors.surface,
      dividerColor: Colors.white10,
    );
  }
}
