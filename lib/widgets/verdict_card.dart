import 'package:flutter/material.dart';

import '../models/event_intelligence.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'confidence_meter.dart';
import 'primitives.dart';

/// The centrepiece.
///
/// **The design thesis in one card:** the listing's own words are set small, in
/// mono, greyed and struck through; our reading is set large in serif directly
/// beneath, connected by a downward arrow. The eye travels *claim → reality* in
/// one movement, which is the entire product expressed as a layout.
///
/// The card's own chrome carries the confidence too. At [ConfidenceBand.likely]
/// it is a solid-bordered, tinted surface. At [ConfidenceBand.unclear] the
/// border goes dashed and the fill drops away — the container looks unsure,
/// before a single word is read.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    super.key,
    required this.verdict,
    required this.onEvidenceTap,
  });

  final EventVerdict verdict;
  final VoidCallback onEvidenceTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final band = verdict.band;
    final color = p.bandColor(band);
    final isUnclear = band == ConfidenceBand.unclear;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(Space.s20, Space.s16, Space.s20, Space.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('OUR READING', style: AppType.label(color: color)),
              const Spacer(),
              ConfidenceMeter(confidence: verdict.confidence),
            ],
          ),
          const SizedBox(height: Space.s20),

          // ── The gap: what it says it is → what it is ──────────────────
          if (verdict.contradictsListing && verdict.listedAs != null) ...[
            Row(
              children: [
                Text('LISTED AS', style: AppType.labelS(color: p.inkFaint)),
                const SizedBox(width: Space.s8),
                Text(
                  verdict.listedAs!,
                  style: AppType.numeric(color: p.inkFaint, size: 12).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: p.inkFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s6),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: Space.s4),
              child: Icon(Icons.subdirectory_arrow_right_rounded,
                  size: 15, color: color),
            ),
          ],

          Text(
            verdict.headline,
            style: AppType.titleXL(color: isUnclear ? p.inkMuted : p.ink),
          ),
          const SizedBox(height: Space.s6),
          Text(verdict.subline, style: AppType.bodyS(color: p.inkMuted)),

          if (verdict.expect.isNotEmpty) ...[
            const SizedBox(height: Space.s16),
            Text(verdict.expect, style: AppType.body(color: p.ink)),
          ],

          if (!isUnclear) ...[
            const SizedBox(height: Space.s16),
            Wrap(
              spacing: Space.s6,
              runSpacing: Space.s6,
              children: [
                if (verdict.level != null)
                  MetaPill(verdict.level!, icon: Icons.signal_cellular_alt_rounded),
                if (verdict.handsOn == true)
                  MetaPill('Hands-on',
                      icon: Icons.build_rounded,
                      color: color,
                      background: p.bandSoft(band)),
                if (verdict.handsOn == false)
                  MetaPill('Listen only', icon: Icons.hearing_rounded),
              ],
            ),
          ],

          const SizedBox(height: Space.s16),
          Hairline(),
          _EvidenceButton(
            count: verdict.evidence.length,
            color: color,
            onTap: onEvidenceTap,
          ),
        ],
      ),
    );

    // Unclear surfaces are drawn, not decorated — a dashed border cannot be
    // expressed with BoxDecoration, and the difference is the whole point.
    if (isUnclear) {
      return CustomPaint(
        painter: DashedBorderPainter(color: p.borderStrong, radius: Radii.xl),
        child: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.bandSoft(band),
        borderRadius: Radii.rXl,
        border: Border.all(
          color: color.withValues(alpha: p.isDark ? 0.34 : 0.22),
          width: Strokes.hair,
        ),
      ),
      child: body,
    );
  }
}

class _EvidenceButton extends StatelessWidget {
  const _EvidenceButton({
    required this.count,
    required this.color,
    required this.onTap,
  });

  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.rSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s12),
        child: Row(
          children: [
            Icon(Icons.format_quote_rounded, size: 15, color: color),
            const SizedBox(width: Space.s8),
            Text(
              count == 1 ? 'BASED ON 1 SOURCE' : 'BASED ON $count SOURCES',
              style: AppType.label(color: color),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, size: 15, color: color),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of [VerdictCard] when the backend has no verdict yet.
///
/// Deliberately not an error and not a spinner. "We haven't looked yet" is a
/// legitimate state, and saying so plainly costs less trust than implying
/// something is broken.
class VerdictPendingCard extends StatelessWidget {
  const VerdictPendingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: DashedBorderPainter(color: p.border, radius: Radii.xl),
      child: Padding(
        padding: const EdgeInsets.all(Space.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OUR READING', style: AppType.label(color: p.inkFaint)),
            const SizedBox(height: Space.s12),
            Text('Not analysed yet',
                style: AppType.titleL(color: p.inkMuted)),
            const SizedBox(height: Space.s6),
            Text(
              'We only publish a reading once we have sources to back it. '
              'Until then, the organiser’s listing is all we can show you.',
              style: AppType.bodyS(color: p.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
