import 'package:flutter/material.dart';

import '../core/for_you.dart';
import '../models/event_intelligence.dart';
import '../models/event_item.dart';
import '../models/profile.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'primitives.dart';

/// About + why you + crowd. Sourced lines only; missing crowd is a prompt,
/// never a guessed number.
class EventBriefing extends StatelessWidget {
  const EventBriefing({
    super.key,
    required this.event,
    required this.profile,
    this.verdict,
  });

  final EventItem event;
  final UserProfile profile;
  final EventVerdict? verdict;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final about = event.about.trim().isNotEmpty
        ? event.about.trim()
        : (verdict?.expect.trim().isNotEmpty ?? false)
            ? verdict!.expect.trim()
            : event.description.trim();
    final forYou = forYouLine(profile: profile, event: event, verdict: verdict);
    final going = event.guestCount;

    if (about.isEmpty && forYou == null && going == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Briefing'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.s16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: Radii.rLg,
            border: Border.all(color: p.border, width: Strokes.hair),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (about.isNotEmpty) ...[
                Text('ABOUT', style: AppType.labelS(color: p.inkFaint)),
                const SizedBox(height: Space.s8),
                Text(about, style: AppType.bodyL(color: p.ink)),
                const SizedBox(height: Space.s6),
                Text(
                  verdict?.expect.trim().isNotEmpty == true
                      ? 'From the sourced reading'
                      : 'From the listing',
                  style: AppType.labelS(color: p.inkFaint),
                ),
              ],
              if (forYou != null) ...[
                if (about.isNotEmpty) ...[
                  const SizedBox(height: Space.s16),
                  const Hairline(),
                  const SizedBox(height: Space.s16),
                ],
                Text('FOR YOU', style: AppType.labelS(color: p.accent)),
                const SizedBox(height: Space.s8),
                Text(forYou, style: AppType.bodyL(color: p.ink)),
              ],
              if (about.isNotEmpty || forYou != null) ...[
                const SizedBox(height: Space.s16),
                const Hairline(),
                const SizedBox(height: Space.s16),
              ],
              _CrowdRow(event: event),
            ],
          ),
        ),
      ],
    );
  }
}

class _CrowdRow extends StatelessWidget {
  const _CrowdRow({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = event.guestCount;
    if (count == null) {
      return Row(
        children: [
          Icon(Icons.groups_outlined, size: 16, color: p.inkFaint),
          const SizedBox(width: Space.s8),
          Expanded(
            child: Text(
              'Crowd not listed publicly — confirm on ${event.source}',
              style: AppType.bodyS(color: p.inkMuted),
            ),
          ),
        ],
      );
    }

    final when = event.guestCountAt;
    var freshness = 'as listed on ${event.source}';
    if (when != null) {
      final hours = DateTime.now().difference(when).inHours;
      freshness = hours < 1
          ? 'as of this hour'
          : hours < 24
              ? 'as of ${hours}h ago'
              : 'as of ${when.day} ${ _month(when.month)}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.groups_rounded, size: 16, color: p.accent),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count going',
                style: AppType.numeric(color: p.ink, size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: Space.s2),
              Text(freshness.toUpperCase(), style: AppType.labelS(color: p.inkFaint)),
            ],
          ),
        ),
      ],
    );
  }

  String _month(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month - 1];
}
