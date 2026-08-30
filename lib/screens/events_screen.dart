import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/city_map.dart';
import '../widgets/event_card.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final events = state.visibleEvents;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.loadEvents,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Tech & fitness\n', style: AppTheme.serif.copyWith(fontSize: 34)),
              TextSpan(text: 'near you.', style: AppTheme.serif.copyWith(fontSize: 34, color: AppColors.gold, fontStyle: FontStyle.italic)),
            ])),
            const SizedBox(height: 8),
            Text('${events.length} Gurugram events from public calendars', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in [('best', 'Best for you'), ('all', 'Upcoming'), ('today', 'Today'), ('week', 'This week'), ('free', 'Free')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: state.eventFilter == item.$1,
                        onSelected: (_) => state.setEventFilter(item.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CityMap(
              center: LatLng(state.profile.lat, state.profile.lng),
              places: const [],
              events: events,
              height: 240,
              onEventTap: (event) {
                if (event.url.isNotEmpty) {
                  launchUrl(Uri.parse(event.url), mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('No matching Gurugram events right now. Pull to refresh.'),
              )
            else
              ...events.map((event) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EventCard(
                      event: event,
                      distanceLabel: event.hasRealCoords ? '${state.eventDistanceKm(event).toStringAsFixed(1)} km away' : 'Confirm venue on source',
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
