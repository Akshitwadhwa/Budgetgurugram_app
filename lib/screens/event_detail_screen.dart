import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mock_intelligence.dart';
import '../models/event_intelligence.dart';
import '../models/event_item.dart';
import '../services/api_client.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/ask_sheet.dart';
import '../widgets/evidence_sheet.dart';
import '../widgets/primitives.dart';
import '../widgets/verdict_card.dart';

/// The screen the product exists for.
///
/// Reading order is an argument, made top to bottom:
///
/// 1. **What it calls itself** — the listing, plainly.
/// 2. **What it actually is** — our reading, with its confidence.
/// 3. **Why we think so** — one tap away, never hidden behind a menu.
/// 4. **What happened last time** — the history nobody else kept.
/// 5. **Ask** — for the part we did not anticipate.
///
/// Previously an event card's only action was `launchUrl` straight out to Luma,
/// which is precisely the behaviour this product exists to replace.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.pool = const [],
  });

  final EventItem event;

  /// Sibling events, used for the "similar" rail.
  final List<EventItem> pool;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  /// Opt-in sample verdicts, for demoing the intelligence UI before the
  /// enrichment worker has run:
  ///
  ///     flutter run --dart-define=DEMO_VERDICTS=true
  ///
  /// Off by default, and when on, every card is badged SAMPLE. Unlabelled
  /// fake data in a product whose entire promise is sourcing would be the one
  /// unforgivable shortcut.
  static const _demoVerdicts = bool.fromEnvironment(
    'DEMO_VERDICTS',
    defaultValue: false,
  );

  final _api = ApiClient();

  EventVerdict? _verdict;
  EventSeries? _series;
  List<EventItem> _similar = const [];
  bool _loading = true;
  bool _failed = false;
  bool _isSample = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final detail = await _api.eventDetail(widget.event.id);
      if (!mounted) return;
      setState(() {
        _verdict = detail.verdict;
        _series = detail.series;
        _loading = false;
        _isSample = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A failed detail call degrades the page; it never blanks it. The header,
      // venue and footer all come from the list item we already hold.
      setState(() {
        _loading = false;
        _failed = true;
      });
    }

    if (!mounted) return;
    if (_verdict == null && _demoVerdicts) {
      setState(() {
        _verdict = MockIntelligence.verdictFor(widget.event);
        _series = MockIntelligence.seriesFor(widget.event);
        _isSample = _verdict != null;
      });
    }
    setState(() {
      _similar = MockIntelligence.similarTo(widget.event, widget.pool);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = widget.event;
    // Locals so Dart can promote them to non-null; instance fields cannot be.
    final verdict = _verdict;
    final series = _series;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: p.canvas,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            actions: [
              IconButton(
                onPressed: () => _open(e.url),
                icon: const Icon(Icons.north_east_rounded, size: 18),
                tooltip: 'Open on ${e.source}',
              ),
              const SizedBox(width: Space.s4),
            ],
            title: Text(
              e.source.toUpperCase(),
              style: AppType.labelS(color: p.inkFaint),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.s8,
              Space.gutter,
              Space.s40,
            ),
            sliver: SliverList.list(
              children: [
                // ── 1. The listing ──────────────────────────────────────────
                Reveal(child: _Header(event: e)),
                const SizedBox(height: Space.s20),
                Reveal(
                  delay: Motion.stagger(1),
                  child: _Venue(event: e),
                ),
                const SizedBox(height: Space.s32),

                // ── 2. The reading ──────────────────────────────────────────
                if (_isSample) ...[
                  const _SampleBadge(),
                  const SizedBox(height: Space.s8),
                ],
                Reveal(
                  delay: Motion.stagger(2),
                  child: _loading
                      ? const _VerdictSkeleton()
                      : verdict == null
                      ? const VerdictPendingCard()
                      : VerdictCard(
                          verdict: verdict,
                          onEvidenceTap: () => showEvidenceSheet(
                            context: context,
                            evidence: verdict.evidence,
                            headline: verdict.headline,
                            confidence: verdict.confidence,
                          ),
                        ),
                ),

                if (verdict != null) ...[
                  if (verdict.whoShouldCome.isNotEmpty) ...[
                    const SizedBox(height: Space.s32),
                    Reveal(
                      delay: Motion.stagger(3),
                      child: _Bullets(
                        label: 'Who it suits',
                        items: verdict.whoShouldCome,
                        icon: Icons.check_rounded,
                        color: p.likely,
                      ),
                    ),
                  ],
                  if (verdict.prepNeeded != null) ...[
                    const SizedBox(height: Space.s24),
                    Reveal(
                      delay: Motion.stagger(4),
                      child: _Callout(
                        label: 'Come prepared',
                        body: verdict.prepNeeded!,
                        color: p.gold,
                        background: p.goldSoft,
                        icon: Icons.backpack_rounded,
                      ),
                    ),
                  ],
                  if (verdict.watchOuts.isNotEmpty) ...[
                    const SizedBox(height: Space.s24),
                    Reveal(
                      delay: Motion.stagger(5),
                      child: _Bullets(
                        label: 'Worth knowing',
                        items: verdict.watchOuts,
                        icon: Icons.priority_high_rounded,
                        color: p.inkMuted,
                      ),
                    ),
                  ],
                ],

                // ── 3. Ask ──────────────────────────────────────────────────
                const SizedBox(height: Space.s32),
                Reveal(
                  delay: Motion.stagger(6),
                  child: _AskBar(
                    onTap: () => showAskSheet(
                      context: context,
                      event: e,
                      verdict: verdict,
                    ),
                  ),
                ),

                // ── 4. History ──────────────────────────────────────────────
                if (series != null && series.hasHistory) ...[
                  const SizedBox(height: Space.s40),
                  _PastEditions(series: series),
                ],

                if (_similar.isNotEmpty) ...[
                  const SizedBox(height: Space.s40),
                  _Similar(events: _similar, pool: widget.pool),
                ],

                if (_failed) ...[
                  const SizedBox(height: Space.s16),
                  _RetryRow(onRetry: _load),
                ],

                const SizedBox(height: Space.s40),
                _Footer(event: e, onOpen: () => _open(e.url)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && url.isNotEmpty) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final start = event.start.toLocal();
    final now = DateTime.now();
    final isToday =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isToday) ...[
              MetaPill('Today', color: p.gold, background: p.goldSoft),
              const SizedBox(width: Space.s6),
            ],
            Text(
              DateFormat('EEE d MMM · h:mm a').format(start).toUpperCase(),
              style: AppType.numeric(color: p.inkMuted, size: 11),
            ),
          ],
        ),
        const SizedBox(height: Space.s16),
        Text(event.title, style: AppType.display(color: p.ink)),
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: Space.s16),
          Text(event.description, style: AppType.bodyL(color: p.inkMuted)),
        ],
      ],
    );
  }
}

// ── Venue: where the "no invented coordinates" rule becomes UI ────────────

class _Venue extends StatelessWidget {
  const _Venue({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final located = event.hasRealCoords;

    return Container(
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.border, width: Strokes.hair),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            located ? Icons.place_rounded : Icons.help_outline_rounded,
            size: 18,
            color: located ? p.accent : p.inkFaint,
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.location,
                  style: AppType.strong(color: p.ink, size: 14),
                ),
                const SizedBox(height: Space.s4),
                // Never a fabricated distance. If the venue was not resolved to
                // real coordinates we say so, rather than quoting a km figure
                // derived from a city-centre fallback.
                Text(
                  located
                      ? event.city
                      : 'Venue not confirmed — check the listing',
                  style: AppType.bodyS(color: p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small section types ───────────────────────────────────────────────────

class _Bullets extends StatelessWidget {
  const _Bullets({
    required this.label,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String label;
  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Text(item, style: AppType.body(color: p.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.label,
    required this.body,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final String body;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Space.s16),
      decoration: BoxDecoration(color: background, borderRadius: Radii.rLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppType.labelS(color: color)),
                const SizedBox(height: Space.s6),
                Text(body, style: AppType.body(color: p.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AskBar extends StatelessWidget {
  const _AskBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.rLg,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s16,
        ),
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: Radii.rLg,
          border: Border.all(
            color: p.accent.withValues(alpha: 0.2),
            width: Strokes.hair,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: p.accent),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask about this event',
                    style: AppType.strong(color: p.ink, size: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Answered only from sources we hold',
                    style: AppType.bodyS(color: p.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: p.accent),
          ],
        ),
      ),
    );
  }
}

// ── History ───────────────────────────────────────────────────────────────

class _PastEditions extends StatelessWidget {
  const _PastEditions({required this.series});
  final EventSeries series;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          'Past editions',
          trailing: Text(
            series.historyLine,
            style: AppType.numeric(color: p.inkMuted, size: 11),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: series.pastEditions.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.s8),
            itemBuilder: (context, i) {
              final ed = series.pastEditions[i];
              return Container(
                width: 168,
                padding: const EdgeInsets.all(Space.s12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: Radii.rMd,
                  border: Border.all(color: p.border, width: Strokes.hair),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM yyyy').format(ed.startedAt).toUpperCase(),
                      style: AppType.numeric(color: p.inkFaint, size: 10),
                    ),
                    const Spacer(),
                    if (ed.observedFormat != null)
                      Text(
                        ed.observedFormat!,
                        style: AppType.strong(color: p.ink, size: 15),
                      ),
                    const SizedBox(height: Space.s6),
                    if (ed.attendance != null)
                      Text(
                        '~${ed.attendance} attended',
                        style: AppType.bodyS(color: p.inkMuted),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Similar extends StatelessWidget {
  const _Similar({required this.events, required this.pool});
  final List<EventItem> events;
  final List<EventItem> pool;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('If this is not it'),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: e, pool: pool),
                ),
              ),
              borderRadius: Radii.rMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.strong(color: p.ink, size: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('E d MMM').format(e.start.toLocal()),
                            style: AppType.numeric(color: p.inkFaint, size: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: p.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.event, required this.onOpen});
  final EventItem event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Hairline(),
        const SizedBox(height: Space.s20),
        if (event.url.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.north_east_rounded, size: 16),
              label: Text('Open on ${event.source}'),
            ),
          ),
        const SizedBox(height: Space.s16),
        Text(
          'Readings are generated from public sources and can be wrong. '
          'Confirm timing, price and venue with the organiser before you travel.',
          style: AppType.bodyS(color: p.inkFaint),
        ),
      ],
    );
  }
}

/// Shown while the detail request is in flight. A skeleton in the verdict's
/// own shape, so the page does not jump when the real card lands.
class _VerdictSkeleton extends StatelessWidget {
  const _VerdictSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Space.s20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rXl,
        border: Border.all(color: p.border, width: Strokes.hair),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 96, height: 10),
          SizedBox(height: Space.s20),
          Skeleton(width: 210, height: 24),
          SizedBox(height: Space.s12),
          Skeleton(height: 13),
          SizedBox(height: Space.s6),
          Skeleton(width: 260, height: 13),
        ],
      ),
    );
  }
}

/// Marks demo data as demo data, unmissably.
class _SampleBadge extends StatelessWidget {
  const _SampleBadge();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        MetaPill(
          'Sample verdict',
          icon: Icons.science_rounded,
          color: p.gold,
          background: p.goldSoft,
        ),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            'Illustrative only — not from real sources',
            style: AppType.bodyS(color: p.inkFaint),
          ),
        ),
      ],
    );
  }
}

class _RetryRow extends StatelessWidget {
  const _RetryRow({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 14, color: p.inkFaint),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            "Couldn't load our reading for this event.",
            style: AppType.bodyS(color: p.inkMuted),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
