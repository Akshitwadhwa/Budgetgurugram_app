import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/place_card.dart';
import '../widgets/place_sheet.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final saved = state.curated.where((place) => state.profile.saved.contains(place.id)).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Text('Your saved edit', style: AppTheme.serif.copyWith(fontSize: 34)),
          const SizedBox(height: 8),
          Text(saved.isEmpty ? 'Save a place from Explore to build your personal list.' : '${saved.length} saved places'),
          const SizedBox(height: 16),
          ...saved.map((place) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PlaceCard(
                  place: place,
                  distanceKm: state.distanceKm(place),
                  saved: true,
                  onOpen: () => showPlaceSheet(context: context, place: place, distanceKm: state.distanceKm(place), saved: true, onSave: () => state.toggleSaved(place.id)),
                  onSave: () => state.toggleSaved(place.id),
                ),
              )),
        ],
      ),
    );
  }
}
