import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_item.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/place_card.dart';
import '../widgets/place_sheet.dart';
import 'profile_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final places = state.visiblePlaces;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(), style: const TextStyle(color: AppColors.gold, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: 'Make the city\n', style: AppTheme.serif.copyWith(fontSize: 34)),
                        TextSpan(text: 'yours.', style: AppTheme.serif.copyWith(fontSize: 34, color: AppColors.gold, fontStyle: FontStyle.italic)),
                      ])),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  icon: Text(((state.profile.displayName.isEmpty ? 'A' : state.profile.displayName)[0]).toUpperCase()),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: Row(
                children: [
                  Text(state.weather.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${state.weather.temp}°', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.forest)),
                        Text(state.weather.label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: state.useCurrentLocation, child: Text(state.profile.neighbourhood)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Best for you today', style: AppTheme.serif.copyWith(fontSize: 28)),
            const SizedBox(height: 10),
            ...state.recommendations.map((item) {
              if (item.kind == 'event') {
                final event = item.item as EventItem;
                return _RecoTile(
                  kind: 'EVENT',
                  title: event.title,
                  detail: event.location,
                  onTap: event.url.isEmpty ? null : () => launchUrl(Uri.parse(event.url), mode: LaunchMode.externalApplication),
                );
              }
              final place = item.item as Place;
              return _RecoTile(
                kind: 'PLACE',
                title: place.name,
                detail: '${place.area} · ${place.price}',
                onTap: () => showPlaceSheet(context: context, place: place, distanceKm: state.distanceKm(place), saved: state.profile.saved.contains(place.id), onSave: () => state.toggleSaved(place.id)),
              );
            }),
            const SizedBox(height: 18),
            TextField(
              onChanged: state.setQuery,
              decoration: InputDecoration(
                hintText: 'Try “a quiet café under ₹300”',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in [
                    ('all', 'All'),
                    ('food', 'Eat'),
                    ('work', 'Work'),
                    ('public', 'Parks'),
                    ('events', 'Culture'),
                    ('services', 'Useful'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: state.category == item.$1,
                        onSelected: (_) => state.setCategory(item.$1),
                        selectedColor: AppColors.forest,
                        labelStyle: TextStyle(color: state.category == item.$1 ? Colors.white : AppColors.forest),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final area in ['all', ...neighbourhoods])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(area == 'all' ? 'All areas' : area),
                        selected: state.areaFilter == area,
                        onSelected: (_) => state.setArea(area),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('${places.length} places near ${state.profile.neighbourhood}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            ...places.map((place) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PlaceCard(
                    place: place,
                    distanceKm: state.distanceKm(place),
                    saved: state.profile.saved.contains(place.id),
                    onOpen: () => showPlaceSheet(context: context, place: place, distanceKm: state.distanceKm(place), saved: state.profile.saved.contains(place.id), onSave: () => state.toggleSaved(place.id)),
                    onSave: () => state.toggleSaved(place.id),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _RecoTile extends StatelessWidget {
  const _RecoTile({required this.kind, required this.title, required this.detail, this.onTap});
  final String kind;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.line)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(kind, style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
