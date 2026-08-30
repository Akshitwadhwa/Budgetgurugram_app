import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'primitives.dart';

/// Place detail.
///
/// The old sheet opened with a 120px block of flat colour carrying the name in
/// white. This version leads with the facts — price, distance, category — set
/// as a small data table, because someone opening this sheet has already
/// decided they are interested and now wants specifics.
///
/// The sourcing footer is not boilerplate. Curated entries carry a real
/// "confirm before visiting" caveat, and saying so is the same rule the event
/// verdicts follow.
Future<void> showPlaceSheet({
  required BuildContext context,
  required Place place,
  required double distanceKm,
  required bool saved,
  required VoidCallback onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PlaceSheet(
      place: place,
      distanceKm: distanceKm,
      saved: saved,
      onSave: onSave,
    ),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({
    required this.place,
    required this.distanceKm,
    required this.saved,
    required this.onSave,
  });

  final Place place;
  final double distanceKm;
  final bool saved;
  final VoidCallback onSave;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  late bool _saved = widget.saved;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final place = widget.place;
    final category = place.category == 'food' &&
            RegExp(r'coffee|cafe|café', caseSensitive: false)
                .hasMatch(place.name)
        ? 'coffee'
        : place.category;
    final accent = p.categoryColor(category);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s12, Space.gutter, Space.s32),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.borderStrong,
                borderRadius: Radii.rPill,
              ),
            ),
          ),
          const SizedBox(height: Space.s20),
          Text(place.categoryLabel.toUpperCase(),
              style: AppType.label(color: accent)),
          const SizedBox(height: Space.s8),
          Text(place.name, style: AppType.display(color: p.ink)),

          if (place.description.isNotEmpty) ...[
            const SizedBox(height: Space.s16),
            Text(place.description, style: AppType.bodyL(color: p.inkMuted)),
          ],

          const SizedBox(height: Space.s24),
          // Facts as a table, not prose. Mono values line up into a column the
          // eye can scan without reading.
          _Row(label: 'Price', value: place.price, mono: true),
          _Row(label: 'Per', value: place.priceType),
          _Row(label: 'Area', value: place.area),
          _Row(
            label: 'Distance',
            value: '${widget.distanceKm.toStringAsFixed(1)} km',
            mono: true,
          ),
          _Row(label: 'Hours', value: place.open),

          if (place.tags.isNotEmpty) ...[
            const SizedBox(height: Space.s20),
            Wrap(
              spacing: Space.s6,
              runSpacing: Space.s6,
              children: [for (final t in place.tags) MetaPill(t)],
            ),
          ],

          const SizedBox(height: Space.s24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _saved = !_saved);
                    widget.onSave();
                  },
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 17,
                    color: _saved ? p.gold : p.ink,
                  ),
                  label: Text(_saved ? 'Saved' : 'Save'),
                ),
              ),
              const SizedBox(width: Space.s8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    final q = Uri.encodeComponent(
                        '${place.name}, ${place.area}, Gurugram');
                    launchUrl(
                      Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$q'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.directions_rounded, size: 17),
                  label: const Text('Directions'),
                ),
              ),
            ],
          ),

          const SizedBox(height: Space.s24),
          const Hairline(),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: p.inkFaint),
              const SizedBox(width: Space.s6),
              Expanded(
                child: Text(
                  'Source: ${place.source}. Confirm hours and price before you travel.',
                  style: AppType.bodyS(color: p.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label.toUpperCase(),
                style: AppType.labelS(color: p.inkFaint)),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppType.numeric(
                      color: p.ink, size: 13, weight: FontWeight.w700)
                  : AppType.body(color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}
