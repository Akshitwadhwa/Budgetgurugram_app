/// Semantic colour, as a [ThemeExtension] so every surface is theme-aware.
///
/// Widgets must never reference a raw hex. They ask for a *role*
/// (`context.palette.inkMuted`) and the theme decides. That indirection is what
/// makes a genuine dark mode possible rather than an inverted afterthought.
library;

import 'package:flutter/material.dart';

/// Confidence bands, the product's central idea expressed as a type.
///
/// Deliberately *not* a red/amber/green scale: [unclear] is neutral, not an
/// error. An honest "we don't know" is a correct outcome, and colouring it like
/// a failure would teach users to distrust the one state that is always true.
enum ConfidenceBand {
  likely,
  possibly,
  unclear;

  static ConfidenceBand fromScore(double score) => switch (score) {
        >= 0.75 => ConfidenceBand.likely,
        >= 0.50 => ConfidenceBand.possibly,
        _ => ConfidenceBand.unclear,
      };
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.gold,
    required this.goldSoft,
    required this.likely,
    required this.likelySoft,
    required this.possibly,
    required this.possiblySoft,
    required this.unclear,
    required this.unclearSoft,
    required this.food,
    required this.coffee,
    required this.work,
    required this.gym,
    required this.events,
    required this.parks,
  });

  final Brightness brightness;

  /// Page background.
  final Color canvas;

  /// Default card / raised container.
  final Color surface;

  /// A card that sits *on* a card. Used sparingly.
  final Color surfaceRaised;

  /// Recessed wells — evidence quotes, input fields.
  final Color surfaceSunken;

  final Color border;
  final Color borderStrong;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  final Color accent;
  final Color onAccent;
  final Color accentSoft;

  final Color gold;
  final Color goldSoft;

  final Color likely;
  final Color likelySoft;
  final Color possibly;
  final Color possiblySoft;
  final Color unclear;
  final Color unclearSoft;

  final Color food;
  final Color coffee;
  final Color work;
  final Color gym;
  final Color events;
  final Color parks;

  bool get isDark => brightness == Brightness.dark;

  Color bandColor(ConfidenceBand band) => switch (band) {
        ConfidenceBand.likely => likely,
        ConfidenceBand.possibly => possibly,
        ConfidenceBand.unclear => unclear,
      };

  Color bandSoft(ConfidenceBand band) => switch (band) {
        ConfidenceBand.likely => likelySoft,
        ConfidenceBand.possibly => possiblySoft,
        ConfidenceBand.unclear => unclearSoft,
      };

  Color categoryColor(String id) => switch (id) {
        'food' => food,
        'coffee' => coffee,
        'work' => work,
        'gym' => gym,
        'events' => events,
        'public' || 'parks' => parks,
        _ => accent,
      };

  // ── Light: "Paper" ─────────────────────────────────────────────────────
  //
  // Warm, printed, editorial. Chosen over the default cool-grey app look
  // because the product is a briefing document, not a dashboard.
  static const light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFF4F0E8),
    surface: Color(0xFFFCFAF6),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEE9DF),
    border: Color(0xFFE1DBCF),
    borderStrong: Color(0xFFC9C1B1),
    ink: Color(0xFF151917),
    inkMuted: Color(0xFF5B6762),
    inkFaint: Color(0xFF8B948F),
    accent: Color(0xFF1E3B35),
    onAccent: Color(0xFFF7F4ED),
    accentSoft: Color(0xFFE0EAE5),
    gold: Color(0xFFB07D22),
    goldSoft: Color(0xFFF4E7CA),
    likely: Color(0xFF2C5D4F),
    likelySoft: Color(0xFFDDEAE3),
    possibly: Color(0xFF9A6B15),
    possiblySoft: Color(0xFFF6E8CD),
    unclear: Color(0xFF6E7772),
    unclearSoft: Color(0xFFE8E4DA),
    food: Color(0xFFC22F38),
    coffee: Color(0xFF8A5A33),
    work: Color(0xFF0B7FA8),
    gym: Color(0xFF35384A),
    events: Color(0xFF6D34C4),
    parks: Color(0xFF5C7F4E),
  );

  // ── Dark: "Ink" ────────────────────────────────────────────────────────
  //
  // Warm charcoal with a green undertone, not blue-black. The paper identity
  // survives the lights going out; it does not become a different product.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF11140F),
    surface: Color(0xFF191D18),
    surfaceRaised: Color(0xFF212620),
    surfaceSunken: Color(0xFF0C0F0B),
    border: Color(0xFF2B312A),
    borderStrong: Color(0xFF414940),
    ink: Color(0xFFECE7DC),
    inkMuted: Color(0xFF9AA49C),
    inkFaint: Color(0xFF6B746D),
    accent: Color(0xFF8CC0AC),
    onAccent: Color(0xFF0E1512),
    accentSoft: Color(0xFF1C2A25),
    gold: Color(0xFFDCA75A),
    goldSoft: Color(0xFF322717),
    likely: Color(0xFF7FBFA5),
    likelySoft: Color(0xFF17271F),
    possibly: Color(0xFFD9A85C),
    possiblySoft: Color(0xFF2C2314),
    unclear: Color(0xFF8B948C),
    unclearSoft: Color(0xFF1E221D),
    food: Color(0xFFF2686F),
    coffee: Color(0xFFC08B5C),
    work: Color(0xFF4FB8DC),
    gym: Color(0xFF9FA3BC),
    events: Color(0xFFA982F0),
    parks: Color(0xFF8FB37E),
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? gold,
    Color? goldSoft,
    Color? likely,
    Color? likelySoft,
    Color? possibly,
    Color? possiblySoft,
    Color? unclear,
    Color? unclearSoft,
    Color? food,
    Color? coffee,
    Color? work,
    Color? gym,
    Color? events,
    Color? parks,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      likely: likely ?? this.likely,
      likelySoft: likelySoft ?? this.likelySoft,
      possibly: possibly ?? this.possibly,
      possiblySoft: possiblySoft ?? this.possiblySoft,
      unclear: unclear ?? this.unclear,
      unclearSoft: unclearSoft ?? this.unclearSoft,
      food: food ?? this.food,
      coffee: coffee ?? this.coffee,
      work: work ?? this.work,
      gym: gym ?? this.gym,
      events: events ?? this.events,
      parks: parks ?? this.parks,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      gold: c(gold, other.gold),
      goldSoft: c(goldSoft, other.goldSoft),
      likely: c(likely, other.likely),
      likelySoft: c(likelySoft, other.likelySoft),
      possibly: c(possibly, other.possibly),
      possiblySoft: c(possiblySoft, other.possiblySoft),
      unclear: c(unclear, other.unclear),
      unclearSoft: c(unclearSoft, other.unclearSoft),
      food: c(food, other.food),
      coffee: c(coffee, other.coffee),
      work: c(work, other.work),
      gym: c(gym, other.gym),
      events: c(events, other.events),
      parks: c(parks, other.parks),
    );
  }
}

extension PaletteContext on BuildContext {
  /// `context.palette.ink` — the only sanctioned way to reach colour.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
