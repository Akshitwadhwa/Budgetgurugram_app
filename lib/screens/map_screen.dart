import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/map_config.dart';
import '../state/app_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/city_map.dart';
import '../widgets/place_sheet.dart';
import '../widgets/primitives.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _categories = [
    ('all', 'All', Icons.grain_rounded),
    ('food', 'Food', Icons.restaurant_rounded),
    ('coffee', 'Coffee', Icons.local_cafe_rounded),
    ('work', 'Work', Icons.laptop_mac_rounded),
    ('gym', 'Gym', Icons.fitness_center_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<AppState>();
    final center = LatLng(state.profile.lat, state.profile.lng);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s16, Space.gutter, Space.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Near you', style: AppType.display(color: p.ink)),
                      const SizedBox(height: Space.s8),
                      _StatusLine(state: state),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: state.loadNearby,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: p.surface,
                    foregroundColor: p.ink,
                    side: BorderSide(color: p.border, width: Strokes.hair),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: [
                for (final (id, label, icon) in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s6),
                    child: ChoiceChip(
                      avatar: Icon(
                        icon,
                        size: 13,
                        color: state.mapCategory == id
                            ? p.onAccent
                            : p.categoryColor(id),
                      ),
                      label: Text(label.toUpperCase()),
                      selected: state.mapCategory == id,
                      onSelected: (_) => state.setMapCategory(id),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: Space.gutter),
                  child: FilterChip(
                    label: Text(
                      (state.showGuidePins ? 'Guide pins on' : 'Guide pins off')
                          .toUpperCase(),
                    ),
                    selected: state.showGuidePins,
                    onSelected: (_) => state.toggleGuidePins(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.s12, 0, Space.s12, Space.s12),
              child: CityMap(
                center: center,
                height: double.infinity,
                places: state.mapPlaces,
                events: state.visibleEvents,
                activeCategory: state.mapCategory,
                userLocation:
                    state.profile.locationMode == 'current' ? center : null,
                onPlaceTap: (place) => showPlaceSheet(
                  context: context,
                  place: place,
                  distanceKm: state.distanceKm(place),
                  saved: state.profile.saved.contains(place.id),
                  onSave: () => state.toggleSaved(place.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says where the pins came from and how fresh they are.
///
/// The trust model applies to the map too: "live pins" and "guide pins" are
/// different claims about how current the data is, and conflating them would
/// let a hand-written entry from months ago pass as something just fetched.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final (text, color, dot) = switch (state.nearbyStatus) {
      'loaded' => (
          '${state.nearbyPlaces.length} live pins',
          p.likely,
          true,
        ),
      'loading' => ('Finding places nearby…', p.inkMuted, false),
      'unavailable' => ('Live data unavailable · guide pins', p.possibly, true),
      'empty' => ('Nothing live nearby · guide pins', p.inkMuted, true),
      _ => ('Guide pins', p.inkMuted, false),
    };

    return Row(
      children: [
        if (dot) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.s6),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.labelS(color: color),
          ),
        ),
        if (!MapConfig.hasToken) ...[
          const SizedBox(width: Space.s8),
          const MetaPill('OSM tiles'),
        ],
      ],
    );
  }
}
