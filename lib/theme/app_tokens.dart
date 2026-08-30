/// Design tokens: the non-colour half of the system.
///
/// Everything spatial, temporal and geometric lives here so that rhythm is a
/// decision made once rather than a number typed 400 times. If a widget needs a
/// magic number, it belongs in this file first.
library;

import 'package:flutter/widgets.dart';

/// Spacing scale. 4pt base, with a deliberate gap between [s24] and [s32] —
/// that jump is what separates "related" from "a new thought".
abstract final class Space {
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s56 = 56.0;

  /// Horizontal page gutter. One value, used everywhere, so every screen shares
  /// a spine.
  static const gutter = 20.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const sheet = 28.0;
  static const pill = 999.0;

  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rPill = BorderRadius.all(Radius.circular(pill));
  static const rSheet = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Motion. Short enough to feel instant, long enough to be read as movement.
///
/// [emphasized] is the only curve with overshoot and is reserved for things
/// that *arrive* — sheets, the verdict card. Everything else uses [standard]
/// so the app doesn't feel bouncy.
abstract final class Motion {
  static const instant = Duration(milliseconds: 110);
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutBack;
  static const exit = Curves.easeInCubic;

  /// Per-item delay for staggered list entrances, capped so long lists don't
  /// make the user wait on the tenth card.
  static Duration stagger(int index) =>
      Duration(milliseconds: (index.clamp(0, 6)) * 45);
}

/// Border weights. Hairlines do most of the structural work in this design —
/// there is very little shadow — so the difference between [hair] and [edge]
/// carries real hierarchy.
abstract final class Strokes {
  static const hair = 1.0;
  static const edge = 1.5;
  static const heavy = 2.0;
}
