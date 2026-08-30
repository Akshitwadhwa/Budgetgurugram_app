import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_intelligence.dart';
import '../models/event_item.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'confidence_meter.dart';

/// A card in the events list.
///
/// The verdict line is the reason this card exists in this shape. A list of
/// titles and times is what every other app already shows; putting the reading
/// *in the list* means the intelligence is the browsing experience, not a
/// reward for tapping through.
///
/// Structure is deliberately flat — a hairline border, no drop shadow, no
/// coloured banner. The old card used a large saturated colour block behind the
/// title, which looked lively in isolation and turned a scrolling list into a
/// stack of competing rectangles.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.distanceLabel,
    this.onTap,
  });

  final EventItem event;
  final String distanceLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final start = event.start.toLocal();
    final now = DateTime.now();
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;

    return Material(
      color: p.surface,
      borderRadius: Radii.rLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.rLg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.rLg,
            border: Border.all(color: p.border, width: Strokes.hair),
          ),
          padding: const EdgeInsets.all(Space.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(event.source.toUpperCase(),
                      style: AppType.labelS(color: p.inkFaint)),
                  const Spacer(),
                  if (isToday) ...[
                    Container(
                      width: 5,
                      height: 5,
                      decoration:
                          BoxDecoration(color: p.gold, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Space.s6),
                  ],
                  Text(
                    DateFormat('E d MMM · h:mm a').format(start).toUpperCase(),
                    style: AppType.numeric(
                      color: isToday ? p.gold : p.inkMuted,
                      size: 11,
                      weight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s12),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.titleL(color: p.ink),
              ),

              // The hook: our reading, in the list. Straight from the API —
              // a card never invents a verdict, and an unanalysed event simply
              // shows no line rather than a placeholder.
              if (event.hasVerdict && event.verdictBand != null) ...[
                const SizedBox(height: Space.s12),
                Builder(builder: (context) {
                  final band = _bandOf(event.verdictBand!);
                  return Row(
                    children: [
                      ConfidenceMeter(
                        confidence: _representativeScore(band),
                        showLabel: false,
                        segmentWidth: 9,
                        animate: false,
                      ),
                      const SizedBox(width: Space.s8),
                      Flexible(
                        child: Text(
                          _headline(band, event.verdictFormat),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.strong(
                            color: p.bandColor(band),
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],

              const SizedBox(height: Space.s12),
              Row(
                children: [
                  Icon(
                    event.hasRealCoords
                        ? Icons.place_outlined
                        : Icons.help_outline_rounded,
                    size: 13,
                    color: p.inkFaint,
                  ),
                  const SizedBox(width: Space.s6),
                  Expanded(
                    child: Text(
                      event.hasRealCoords
                          ? '${event.location} · $distanceLabel'
                          : 'Confirm venue on source',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyS(color: p.inkMuted),
                    ),
                  ),
                  if (event.guestCount != null) ...[
                    const SizedBox(width: Space.s8),
                    Text('${event.guestCount} GOING',
                        style: AppType.labelS(color: p.inkMuted)),
                  ],
                  if (event.fitPercent != null) ...[
                    const SizedBox(width: Space.s8),
                    Text('${event.fitPercent}% FIT',
                        style: AppType.labelS(color: p.accent)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ConfidenceBand _bandOf(String raw) => switch (raw) {
      'likely' => ConfidenceBand.likely,
      'possibly' => ConfidenceBand.possibly,
      _ => ConfidenceBand.unclear,
    };

/// The list carries a band, not a score. This maps back to a representative
/// score purely so the meter can draw the right number of segments — the card
/// never displays a number, so no false precision escapes.
double _representativeScore(ConfidenceBand band) => switch (band) {
      ConfidenceBand.likely => 0.85,
      ConfidenceBand.possibly => 0.62,
      ConfidenceBand.unclear => 0.35,
    };

String _headline(ConfidenceBand band, String? format) {
  final name = EventFormat.parse(format).label.toLowerCase();
  return switch (band) {
    ConfidenceBand.likely => 'Likely a $name',
    ConfidenceBand.possibly => 'Possibly a $name',
    ConfidenceBand.unclear => 'Format unclear',
  };
}
