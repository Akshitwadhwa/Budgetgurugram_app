import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/event_card.dart';
import '../widgets/primitives.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  static const _filters = [
    ('best', 'Best for you'),
    ('all', 'Upcoming'),
    ('today', 'Today'),
    ('week', 'This week'),
    ('free', 'Free'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<AppState>();
    final events = state.visibleEvents;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.loadEvents,
        color: p.accent,
        backgroundColor: p.surface,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.s16, Space.gutter, 0),
              sliver: SliverList.list(children: [
                // Two-part headline: the italic serif turn is this app's
                // signature, used once per screen and never more.
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'What is actually\n',
                        style: AppType.display(color: p.ink)),
                    TextSpan(
                        text: 'happening.',
                        style: AppType.displayAccent(color: p.gold)),
                  ]),
                ),
                const SizedBox(height: Space.s12),
                Text(
                  'Gurugram events from public calendars, read against their '
                  'own history.',
                  style: AppType.body(color: p.inkMuted),
                ),
                const SizedBox(height: Space.s20),
              ]),
            ),

            // Filters pinned to the top edge so they stay reachable while the
            // list scrolls under them.
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterBar(
                selected: state.eventFilter,
                onSelect: state.setEventFilter,
                background: p.canvas,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.s4, Space.gutter, Space.s32),
              sliver: events.isEmpty
                  ? SliverToBoxAdapter(child: _Empty(filter: state.eventFilter))
                  : SliverList.separated(
                      itemCount: events.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Space.s12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: Space.s4),
                            child: Text(
                              '${events.length} EVENTS',
                              style: AppType.labelS(color: p.inkFaint),
                            ),
                          );
                        }
                        final event = events[i - 1];
                        return Reveal(
                          delay: Motion.stagger(i - 1),
                          child: EventCard(
                            event: event,
                            distanceLabel: event.hasRealCoords
                                ? '${state.eventDistanceKm(event).toStringAsFixed(1)} km'
                                : '',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(
                                  event: event,
                                  pool: events,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends SliverPersistentHeaderDelegate {
  _FilterBar({
    required this.selected,
    required this.onSelect,
    required this.background,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final Color background;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final p = context.palette;
    return Container(
      color: background,
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: [
                for (final (id, label) in EventsScreen._filters)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s6),
                    child: ChoiceChip(
                      label: Text(label.toUpperCase()),
                      selected: selected == id,
                      onSelected: (_) => onSelect(id),
                    ),
                  ),
              ],
            ),
          ),
          // A hairline appears only once content has scrolled beneath, so the
          // bar is invisible at rest and structural in motion.
          AnimatedOpacity(
            opacity: shrinkOffset > 2 ? 1 : 0,
            duration: Motion.fast,
            child: Container(height: Strokes.hair, color: p.border),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBar old) =>
      old.selected != selected || old.background != background;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (filter) {
              'today' => 'Nothing today.',
              'free' => 'Nothing free right now.',
              'week' => 'Nothing this week.',
              _ => 'Nothing upcoming.',
            },
            style: AppType.titleXL(color: p.ink),
          ),
          const SizedBox(height: Space.s8),
          Text(
            'Gurugram is a small calendar. Try a wider filter — or check back '
            'after the next refresh.',
            style: AppType.body(color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}
