/// Three typefaces, three jobs, no overlap.
///
/// * **Instrument Serif** — display only. Voice, never information.
/// * **DM Sans** — everything a human reads in sentences.
/// * **JetBrains Mono** — *machine-adjacent* text: labels, timestamps,
///   confidence values, source attributions, counts.
///
/// That third role is the one doing the heavy lifting. Metadata set in mono
/// reads as *recorded* rather than *written* — it signals "this came from a
/// source" without a single word of explanation. It is the typographic
/// expression of the product's trust model.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppType {
  // ── Display: Instrument Serif ────────────────────────────────────────────
  // Tight leading (< 1.0) because these are one- to three-word statements, and
  // large serif set at normal leading looks like it is floating apart.

  static TextStyle display({Color? color}) => GoogleFonts.instrumentSerif(
        fontSize: 40,
        height: 0.98,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle titleXL({Color? color}) => GoogleFonts.instrumentSerif(
        fontSize: 32,
        height: 1.02,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle titleL({Color? color}) => GoogleFonts.instrumentSerif(
        fontSize: 26,
        height: 1.08,
        letterSpacing: -0.2,
        color: color,
      );

  /// The italic variant is reserved for the *second half* of a two-part
  /// headline — the turn in the sentence. Used sparingly, it becomes a
  /// recognisable signature; used everywhere it becomes noise.
  static TextStyle displayAccent({Color? color}) =>
      GoogleFonts.instrumentSerif(
        fontSize: 40,
        height: 0.98,
        letterSpacing: -0.4,
        fontStyle: FontStyle.italic,
        color: color,
      );

  // ── Body: DM Sans ────────────────────────────────────────────────────────

  static TextStyle bodyL({Color? color}) => GoogleFonts.dmSans(
        fontSize: 16,
        height: 1.55,
        letterSpacing: -0.1,
        color: color,
      );

  static TextStyle body({Color? color}) => GoogleFonts.dmSans(
        fontSize: 14.5,
        height: 1.55,
        color: color,
      );

  static TextStyle bodyS({Color? color}) => GoogleFonts.dmSans(
        fontSize: 13,
        height: 1.5,
        color: color,
      );

  static TextStyle strong({Color? color, double size = 15}) => GoogleFonts.dmSans(
        fontSize: size,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      );

  /// Serif quotations inside evidence. Italic serif reads as *cited speech* —
  /// it is visually obvious that these words belong to someone else.
  static TextStyle quote({Color? color}) => GoogleFonts.instrumentSerif(
        fontSize: 16,
        height: 1.45,
        fontStyle: FontStyle.italic,
        color: color,
      );

  // ── Metadata: JetBrains Mono ─────────────────────────────────────────────
  // Always uppercase at these sizes, always letterspaced. Mono at small sizes
  // without tracking is illegible; with tracking it becomes a rhythm.

  static TextStyle label({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
        color: color,
      );

  static TextStyle labelS({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: color,
      );

  /// Tabular figures for anything that sits in a column or animates — counts,
  /// distances, times. Stops numbers from shuffling as they change.
  static TextStyle numeric({Color? color, double size = 12, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        height: 1.2,
        fontWeight: weight ?? FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Base [TextTheme] so unstyled Material widgets inherit sane defaults
  /// instead of Roboto.
  static TextTheme textTheme(Color ink, Color muted) {
    return TextTheme(
      displayLarge: display(color: ink),
      displayMedium: titleXL(color: ink),
      headlineMedium: titleL(color: ink),
      titleMedium: strong(color: ink),
      bodyLarge: bodyL(color: ink),
      bodyMedium: body(color: ink),
      bodySmall: bodyS(color: muted),
      labelLarge: strong(color: ink, size: 14),
      labelMedium: label(color: muted),
      labelSmall: labelS(color: muted),
    );
  }
}
