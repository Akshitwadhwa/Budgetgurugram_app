import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/place_card.dart';
import '../widgets/place_sheet.dart';
import '../widgets/primitives.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<AppState>();
    final saved = state.curated
        .where((place) => state.profile.saved.contains(place.id))
        .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s16, Space.gutter, Space.s32),
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Your\n', style: AppType.display(color: p.ink)),
            TextSpan(
                text: 'shortlist.',
                style: AppType.displayAccent(color: p.gold)),
          ])),
          const SizedBox(height: Space.s12),
          Text(
            saved.isEmpty
                ? 'Nothing saved yet.'
                : '${saved.length} ${saved.length == 1 ? "place" : "places"}, kept on this device.',
            style: AppType.body(color: p.inkMuted),
          ),
          const SizedBox(height: Space.s24),

          if (saved.isEmpty)
            const _EmptyState()
          else
            for (final (i, place) in saved.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s12),
                child: Reveal(
                  delay: Motion.stagger(i),
                  child: PlaceCard(
                    place: place,
                    distanceKm: state.distanceKm(place),
                    saved: true,
                    onOpen: () => showPlaceSheet(
                      context: context,
                      place: place,
                      distanceKm: state.distanceKm(place),
                      saved: true,
                      onSave: () => state.toggleSaved(place.id),
                    ),
                    onSave: () => state.toggleSaved(place.id),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// The empty state does real work here.
///
/// An empty list is the first thing every new user sees on this tab, so rather
/// than an apologetic illustration it explains the one thing worth knowing:
/// saves live on the device, and nothing is being collected.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.s20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.border, width: Strokes.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 20, color: p.inkFaint),
          const SizedBox(height: Space.s16),
          Text('Save as you browse', style: AppType.titleL(color: p.ink)),
          const SizedBox(height: Space.s8),
          Text(
            'Tap the bookmark on any place to keep it here. Your list stays on '
            'this phone — there is no account, and nothing is sent anywhere.',
            style: AppType.body(color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}
