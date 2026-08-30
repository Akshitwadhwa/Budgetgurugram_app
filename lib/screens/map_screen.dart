import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/city_map.dart';
import '../widgets/place_sheet.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final center = LatLng(state.profile.lat, state.profile.lng);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              children: [
                Expanded(child: Text('Near you', style: AppTheme.serif.copyWith(fontSize: 32))),
                IconButton(onPressed: state.loadNearby, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              state.nearbyStatus == 'loaded'
                  ? 'Live pins · ${state.nearbyPlaces.length} places'
                  : state.nearbyStatus == 'unavailable'
                      ? 'Live pins unavailable · guide pins shown'
                      : 'Loading nearby places…',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                for (final item in [('all', 'All'), ('food', 'Food'), ('coffee', 'Coffee'), ('work', 'Work'), ('gym', 'Gym')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.$2),
                      selected: state.mapCategory == item.$1,
                      onSelected: (_) => state.setMapCategory(item.$1),
                    ),
                  ),
                FilterChip(label: Text(state.showGuidePins ? 'Hide guide pins' : 'Show guide pins'), selected: state.showGuidePins, onSelected: (_) => state.toggleGuidePins()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: CityMap(
                center: center,
                height: double.infinity,
                places: state.mapPlaces,
                events: state.visibleEvents,
                userLocation: state.profile.locationMode == 'current' ? center : null,
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
