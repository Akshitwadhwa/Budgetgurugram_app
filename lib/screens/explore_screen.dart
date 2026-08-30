import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/event_item.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/place_card.dart';
import '../widgets/place_sheet.dart';
import '../widgets/primitives.dart';
import 'event_detail_screen.dart';
import 'profile_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const _categories = [
    ('all', 'All'),
    ('food', 'Eat'),
    ('work', 'Work'),
    ('public', 'Parks'),
    ('services', 'Useful'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<AppState>();
    final places = state.visiblePlaces;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.refreshAll,
        color: p.accent,
        backgroundColor: p.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Space.gutter, Space.s16, Space.gutter, Space.s32),
          children: [
            _Masthead(state: state),
            const SizedBox(height: Space.s20),
            Reveal(child: _TodayBar(state: state)),

            const SizedBox(height: Space.s32),
            Reveal(delay: Motion.stagger(1), child: _BestForYou(state: state)),

            const SizedBox(height: Space.s32),
            const SectionLabel('Find a place'),
            TextField(
              onChanged: state.setQuery,
              style: AppType.body(color: p.ink),
              decoration: InputDecoration(
                hintText: 'A quiet café under ₹300…',
                prefixIcon: Icon(Icons.search_rounded, size: 19, color: p.inkFaint),
              ),
            ),
            const SizedBox(height: Space.s12),
            _Chips(
              options: _categories,
              selected: state.category,
              onSelect: state.setCategory,
            ),
            const SizedBox(height: Space.s8),
            _Chips(
              options: [
                ('all', 'All areas'),
                for (final area in neighbourhoods) (area, area),
              ],
              selected: state.areaFilter,
              onSelect: state.setArea,
              filter: true,
            ),

            const SizedBox(height: Space.s24),
            Row(
              children: [
                Text('${places.length} PLACES'.toUpperCase(),
                    style: AppType.labelS(color: p.inkFaint)),
                const SizedBox(width: Space.s8),
                Expanded(child: Hairline()),
              ],
            ),
            const SizedBox(height: Space.s16),

            if (places.isEmpty)
              _NoPlaces(onReset: () {
                state.setCategory('all');
                state.setQuery('');
              })
            else
              for (final (i, place) in places.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s12),
                  child: Reveal(
                    delay: Motion.stagger(i),
                    child: PlaceCard(
                      place: place,
                      distanceKm: state.distanceKm(place),
                      saved: state.profile.saved.contains(place.id),
                      onOpen: () => _openPlace(context, state, place),
                      onSave: () => state.toggleSaved(place.id),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _openPlace(BuildContext context, AppState state, Place place) {
    showPlaceSheet(
      context: context,
      place: place,
      distanceKm: state.distanceKm(place),
      saved: state.profile.saved.contains(place.id),
      onSave: () => state.toggleSaved(place.id),
    );
  }
}

// ── Masthead ──────────────────────────────────────────────────────────────

class _Masthead extends StatelessWidget {
  const _Masthead({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = state.profile.displayName;
    final initial = (name.isEmpty ? 'G' : name)[0].toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
                style: AppType.labelS(color: p.gold),
              ),
              const SizedBox(height: Space.s12),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: 'Make the city\n',
                    style: AppType.display(color: p.ink)),
                TextSpan(
                    text: 'yours.',
                    style: AppType.displayAccent(color: p.gold)),
              ])),
            ],
          ),
        ),
        const SizedBox(width: Space.s12),
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          borderRadius: Radii.rPill,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.borderStrong, width: Strokes.hair),
            ),
            child: Text(initial, style: AppType.titleL(color: p.ink)),
          ),
        ),
      ],
    );
  }
}

/// Weather, area and a one-line read on the day.
///
/// Replaces a plain temperature readout. The number alone is not actionable in
/// a city where the answer is always "warm"; what matters is whether today is
/// an indoors day, so that is what the line says.
class _TodayBar extends StatelessWidget {
  const _TodayBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.border, width: Strokes.hair),
      ),
      child: Row(
        children: [
          Text(state.weather.icon, style: TextStyle(fontSize: 26, color: p.gold)),
          const SizedBox(width: Space.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${state.weather.temp}°',
                        style: AppType.titleL(color: p.ink)),
                    const SizedBox(width: Space.s8),
                    Flexible(
                      child: Text(
                        state.weather.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodyS(color: p.inkMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.s8),
          InkWell(
            onTap: state.useCurrentLocation,
            borderRadius: Radii.rSm,
            child: Padding(
              padding: const EdgeInsets.all(Space.s6),
              child: Row(
                children: [
                  Icon(Icons.my_location_rounded, size: 12, color: p.accent),
                  const SizedBox(width: Space.s6),
                  Text(state.profile.neighbourhood.toUpperCase(),
                      style: AppType.labelS(color: p.accent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recommendations ───────────────────────────────────────────────────────

class _BestForYou extends StatelessWidget {
  const _BestForYou({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = state.recommendations;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Best for you today'),
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: _RecoTile(
              rank: i + 1,
              isEvent: item.kind == 'event',
              title: item.kind == 'event'
                  ? (item.item as EventItem).title
                  : (item.item as Place).name,
              detail: item.kind == 'event'
                  ? (item.item as EventItem).location
                  : '${(item.item as Place).area} · ${(item.item as Place).price}',
              accent: item.kind == 'event' ? p.events : p.accent,
              onTap: () {
                if (item.kind == 'event') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EventDetailScreen(
                      event: item.item as EventItem,
                      pool: state.visibleEvents,
                    ),
                  ));
                } else {
                  final place = item.item as Place;
                  showPlaceSheet(
                    context: context,
                    place: place,
                    distanceKm: state.distanceKm(place),
                    saved: state.profile.saved.contains(place.id),
                    onSave: () => state.toggleSaved(place.id),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}

class _RecoTile extends StatelessWidget {
  const _RecoTile({
    required this.rank,
    required this.isEvent,
    required this.title,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final int rank;
  final bool isEvent;
  final String title;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A ranked list, numbered like one. Numbering makes the ordering
            // legible as a judgement rather than an accident of layout.
            SizedBox(
              width: 22,
              child: Text('$rank'.padLeft(2, '0'),
                  style: AppType.numeric(color: p.inkFaint, size: 11)),
            ),
            const SizedBox(width: Space.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.strong(color: p.ink, size: 15)),
                  const SizedBox(height: 2),
                  Text(detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS(color: p.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: Space.s8),
            Text(isEvent ? 'EVENT' : 'PLACE',
                style: AppType.labelS(color: accent)),
          ],
        ),
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────

class _Chips extends StatelessWidget {
  const _Chips({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.filter = false,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool filter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (id, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: Space.s6),
              child: filter
                  ? FilterChip(
                      label: Text(label.toUpperCase()),
                      selected: selected == id,
                      onSelected: (_) => onSelect(id),
                    )
                  : ChoiceChip(
                      label: Text(label.toUpperCase()),
                      selected: selected == id,
                      onSelected: (_) => onSelect(id),
                    ),
            ),
        ],
      ),
    );
  }
}

class _NoPlaces extends StatelessWidget {
  const _NoPlaces({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing matches.', style: AppType.titleXL(color: p.ink)),
          const SizedBox(height: Space.s8),
          Text(
            'The guide is deliberately small — every place in it was chosen, '
            'not scraped. Try widening the filter.',
            style: AppType.body(color: p.inkMuted),
          ),
          const SizedBox(height: Space.s16),
          OutlinedButton(onPressed: onReset, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}
