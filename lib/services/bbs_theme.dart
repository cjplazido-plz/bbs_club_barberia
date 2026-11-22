import 'package:flutter/material.dart';

// Paleta BBS CLUB - igual que Reservas (captura que mandaste)
// Fondo casi negro + tarjetas oscuras + dorado, no más índigo / azul.
class BbsTheme {
  static const Color bg = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF141414);
  static const Color input = Color(0xFF1E1E1E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Colors.redAccent;
  static const Color textWhite = Colors.white;
  static const Color textMuted = Colors.white54;
  static const Color textFaint = Colors.white38;

  static const TextStyle sectionTitle = TextStyle(
    color: gold,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  static const TextStyle cardTitle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  // Botón principal dorado, como "Como llegar" en Reservas: fondo dorado, texto negro
  static ButtonStyle goldButton = ElevatedButton.styleFrom(
    backgroundColor: gold,
    foregroundColor: Colors.black,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(vertical: 14),
    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
  );

  static InputDecoration inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: gold, size: 18) : null,
      filled: true,
      fillColor: input,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0, centerTitle: true),
      cardColor: card,
      colorScheme: const ColorScheme.dark(primary: gold, secondary: goldLight, surface: card, background: bg),
      elevatedButtonTheme: ElevatedButtonThemeData(style: goldButton),
    );
  }
}
