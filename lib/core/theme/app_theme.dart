import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores de Celtas, extraída de `design-reference/` (export real de
/// Claude Design) y de la paleta ya verificada con WCAG en `celtas-admin`.
///
/// Nunca usar `Color(0xFF...)` suelto dentro de un widget: ir siempre a esta clase.
class CeltasColors {
  CeltasColors._();

  // Marca (de celtas-admin, contrastes WCAG verificados).
  static const black = Color(0xFF0D0D0D);
  static const orange = Color(0xFFE8590C);
  static const red = Color(0xFFC1121F); // solo iconos/acentos, NUNCA texto
  static const redLight = Color(0xFFF87171); // texto de error/estados
  static const gold = Color(0xFFFFB800);
  static const cream = Color(0xFFF5F1E8);

  // --- Escala neutra / superficies y bordes (del CSS real del mockup).
  static const card = Color(0xFF141110); // tarjetas/cards
  static const navBar = Color(0xFF111010); // fondo del bottom nav (mockup)
  static const surface = Color(0xFF17130F); // inputs, chips, fondos internos
  static const surfaceSelected = Color(0xFF1B140D); // tarjeta/input seleccionado
  static const border = Color(0xFF2A231C);
  static const borderStrong = Color(0xFF3A342C);
  static const cardBorder = Color(0xFF241F19);
  static const placeholder = Color(0xFF5C5548); // texto fantasma de inputs

  // --- Texto secundario/muted.
  static const textMuted = Color(0xFF8A8378); // descripciones, subtítulos
  static const textSubtle = Color(0xFF6B6357); // tabs inactivas, menos énfasis
  static const textLabel = Color(0xFFC9A96A); // labels de formularios (EMAIL, etc.)
}

/// Radios que se repiten en el mockup (`border-radius` real del CSS).
class CeltasRadii {
  CeltasRadii._();

  static const double badge = 6; // tags chicas (-20%)
  static const double control = 10; // steppers de cantidad en carrito
  static const double input = 12; // inputs, botones secundarios, cards checkout
  static const double card = 14; // tarjetas de direcciones/pedidos
  static const double banner = 16; // banner del home
  static const double pill = 20; // category chips y badges de estado
  static const double phone = 44; // marco de la pantalla en el mockup
}

/// Paddings/genéricos que se repiten en el mockup (24px horizontal de página).
class CeltasSpacing {
  CeltasSpacing._();

  static const double page = 24; // padding horizontal base de pantalla
  static const double card = 14; // padding interno de las cards
}

/// Tema oscuro de Celtas que replica los valores exactos de `design-reference/`:
/// fondo black `#0D0D0D`, primario orange `#E8590C`, texto crema `#F5F1E8`;
/// títulos con `Cinzel` (la fuente serif del mockup) y cuerpo con `Manrope`.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: CeltasColors.orange,
      onPrimary: CeltasColors.black,
      secondary: CeltasColors.gold,
      onSecondary: CeltasColors.black,
      surface: CeltasColors.card,
      onSurface: CeltasColors.cream,
      error: CeltasColors.redLight,
      onError: CeltasColors.black,
      outline: CeltasColors.border,
      outlineVariant: CeltasColors.borderStrong,
      surfaceContainerHighest: CeltasColors.surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CeltasColors.black,
    );

    final baseText = base.textTheme;
    final textTheme = TextTheme(
      displayLarge: GoogleFonts.cinzel(
        textStyle: baseText.displayLarge,
        fontSize: 44,
        fontWeight: FontWeight.w900,
        color: CeltasColors.cream,
        letterSpacing: 6,
      ),
      displayMedium: GoogleFonts.cinzel(
        textStyle: baseText.displayMedium,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: CeltasColors.cream,
        letterSpacing: 3,
      ),
      headlineMedium: GoogleFonts.cinzel(
        textStyle: baseText.headlineMedium,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: CeltasColors.cream,
      ),
      headlineSmall: GoogleFonts.cinzel(
        textStyle: baseText.headlineSmall,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: CeltasColors.cream,
      ),
      titleMedium: GoogleFonts.cinzel(
        textStyle: baseText.titleMedium,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: CeltasColors.cream,
        letterSpacing: 2,
      ),
      titleSmall: GoogleFonts.cinzel(
        textStyle: baseText.titleSmall,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: CeltasColors.cream,
      ),
      bodyLarge: GoogleFonts.manrope(
        textStyle: baseText.bodyLarge,
        fontSize: 16,
        color: CeltasColors.cream,
      ),
      bodyMedium: GoogleFonts.manrope(
        textStyle: baseText.bodyMedium,
        fontSize: 14,
        color: CeltasColors.cream,
      ),
      bodySmall: GoogleFonts.manrope(
        textStyle: baseText.bodySmall,
        fontSize: 12,
        color: CeltasColors.textMuted,
      ),
      labelLarge: GoogleFonts.manrope(
        textStyle: baseText.labelLarge,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: CeltasColors.black,
      ),
      labelMedium: GoogleFonts.manrope(
        textStyle: baseText.labelMedium,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CeltasColors.cream,
      ),
      labelSmall: GoogleFonts.manrope(
        textStyle: baseText.labelSmall,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: CeltasColors.textLabel,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: const IconThemeData(color: CeltasColors.cream),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CeltasColors.orange,
          foregroundColor: CeltasColors.black,
          disabledBackgroundColor: CeltasColors.border,
          disabledForegroundColor: CeltasColors.textSubtle,
          elevation: 0,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 17,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CeltasRadii.input),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CeltasColors.surface,
        hintStyle: GoogleFonts.manrope(
          color: CeltasColors.placeholder,
          fontSize: 15,
        ),
        labelStyle: textTheme.labelSmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CeltasRadii.input),
          borderSide: const BorderSide(color: CeltasColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CeltasRadii.input),
          borderSide: const BorderSide(color: CeltasColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CeltasRadii.input),
          borderSide: const BorderSide(color: CeltasColors.orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CeltasRadii.input),
          borderSide: const BorderSide(color: CeltasColors.redLight),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CeltasRadii.input),
          borderSide: const BorderSide(color: CeltasColors.redLight, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: CeltasColors.surface,
        side: const BorderSide(color: CeltasColors.border),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: CeltasColors.textLabel,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CeltasRadii.pill),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: CeltasColors.black,
        indicatorColor: CeltasColors.surface,
        iconTheme: WidgetStatePropertyAll(IconThemeData(
          color: CeltasColors.textSubtle,
        )),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
          fontSize: 10,
          color: CeltasColors.textSubtle,
          fontWeight: FontWeight.w600,
        )),
      ),
      dividerTheme: const DividerThemeData(
        color: CeltasColors.border,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CeltasColors.orange,
      ),
    );
  }
}