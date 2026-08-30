import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_intelligence.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'primitives.dart';

/// The receipts.
///
/// Every claim is shown with the words it came from and a link to go check.
/// Layout borrows from a citation margin: a hairline rail runs down the left of
/// each entry, quotations are set in italic serif so they are visibly *someone
/// else's words*, and the domain is set in mono beneath.
///
/// This screen is the reason the app is allowed to make judgements at all. It
/// is intentionally over-built relative to its traffic.
Future<void> showEvidenceSheet({
  required BuildContext context,
  required List<Evidence> evidence,
  required String headline,
  required double confidence,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _EvidenceSheet(
      evidence: evidence,
      headline: headline,
      confidence: confidence,
    ),
  );
}

class _EvidenceSheet extends StatelessWidget {
  const _EvidenceSheet({
    required this.evidence,
    required this.headline,
    required this.confidence,
  });

  final List<Evidence> evidence;
  final String headline;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final band = ConfidenceBand.fromScore(confidence);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          const _Grabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.s8, Space.gutter, Space.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHY WE SAY THIS', style: AppType.label(color: p.bandColor(band))),
                const SizedBox(height: Space.s8),
                Text(headline, style: AppType.titleL(color: p.ink)),
                const SizedBox(height: Space.s6),
                Text(
                  evidence.length == 1
                      ? 'One source supports this reading. Check it yourself.'
                      : '${evidence.length} sources support this reading. Check them yourself.',
                  style: AppType.bodyS(color: p.inkMuted),
                ),
              ],
            ),
          ),
          const Hairline(),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.s20, Space.gutter, Space.s40),
              itemCount: evidence.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.s24),
              itemBuilder: (context, i) => Reveal(
                delay: Motion.stagger(i),
                child: _EvidenceEntry(evidence: evidence[i], index: i + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceEntry extends StatelessWidget {
  const _EvidenceEntry({required this.evidence, required this.index});

  final Evidence evidence;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The provenance rail. A citation margin, borrowed from print.
          Column(
            children: [
              Text('$index'.padLeft(2, '0'),
                  style: AppType.numeric(color: p.inkFaint, size: 11)),
              const SizedBox(height: Space.s8),
              Expanded(
                child: Container(width: Strokes.hair, color: p.border),
              ),
            ],
          ),
          const SizedBox(width: Space.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(evidence.claim, style: AppType.strong(color: p.ink, size: 15)),
                if (evidence.quote != null && evidence.quote!.isNotEmpty) ...[
                  const SizedBox(height: Space.s12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                        Space.s16, Space.s12, Space.s16, Space.s12),
                    decoration: BoxDecoration(
                      color: p.surfaceSunken,
                      borderRadius: Radii.rMd,
                    ),
                    child: Text('“${evidence.quote}”',
                        style: AppType.quote(color: p.ink)),
                  ),
                ],
                const SizedBox(height: Space.s12),
                _SourceLink(evidence: evidence),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.evidence});
  final Evidence evidence;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: () {
        final uri = Uri.tryParse(evidence.sourceUrl);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: Radii.rSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s4),
        child: Row(
          children: [
            Icon(Icons.north_east_rounded, size: 13, color: p.accent),
            const SizedBox(width: Space.s6),
            Flexible(
              child: Text(
                evidence.sourceTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.bodyS(color: p.accent),
              ),
            ),
            const SizedBox(width: Space.s8),
            Text(evidence.host, style: AppType.numeric(color: p.inkFaint, size: 11)),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s12),
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: context.palette.borderStrong,
          borderRadius: Radii.rPill,
        ),
      ),
    );
  }
}
