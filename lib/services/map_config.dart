import 'package:flutter/material.dart';

/// Map tile configuration.
///
/// Mapbox is used through `flutter_map`'s raster tile layer rather than the
/// native `mapbox_maps_flutter` SDK. That is a deliberate choice, not a
/// shortcut:
///
/// * **Markers stay Flutter widgets.** The native SDK renders annotations from
///   pre-baked images, so a custom marker means shipping PNGs at three
///   densities and losing animation, theming and hit-testing. Here a marker is
///   a widget — it can animate, respond to the palette, and switch with dark
///   mode for free.
/// * **No native configuration.** No secret download token, no Gradle or
///   Podfile edits, no platform-specific build break before a demo.
/// * **The styling is the same.** The visual quality people mean when they say
///   "Mapbox" comes from the tiles, and these are the same tiles.
///
/// The token is injected at build time and never committed:
///
/// ```
/// flutter run --dart-define=MAPBOX_TOKEN=pk.your_token_here
/// ```
///
/// Without a token the app falls back to OpenStreetMap tiles and keeps working.
/// A missing key degrades the map's looks, never its function.
abstract final class MapConfig {
  static const token = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get hasToken => token.isNotEmpty;

  /// Mapbox's minimal styles are chosen over `streets`: this app's map is a
  /// backdrop for pins, so the basemap should recede. `light-v11` is nearly
  /// monochrome, which lets the category colours carry all the meaning.
  static String styleId(Brightness brightness) =>
      brightness == Brightness.dark ? 'dark-v11' : 'light-v11';

  static String urlTemplate(Brightness brightness) {
    if (!hasToken) {
      return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
    return 'https://api.mapbox.com/styles/v1/mapbox/${styleId(brightness)}'
        '/tiles/512/{z}/{x}/{y}@2x?access_token=$token';
  }

  /// Mapbox 512px tiles are served at one zoom level "behind" the 256px
  /// scheme flutter_map assumes, which is what this offset corrects.
  static int get zoomOffset => hasToken ? -1 : 0;

  static int get tileSize => hasToken ? 512 : 256;

  /// Attribution is a licence condition for both providers, not a nicety.
  static String get attribution =>
      hasToken ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap contributors';

  static String get attributionUrl => hasToken
      ? 'https://www.mapbox.com/about/maps/'
      : 'https://www.openstreetmap.org/copyright';
}
