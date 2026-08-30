import 'package:flutter/material.dart';

import '../models/place.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// A place in the list.
///
/// The previous card led with a 92px block of saturated colour behind the name.
/// It looked lively alone and turned a scroll into a stack of shouting
/// rectangles. Here colour is reduced to a 3px spine on the leading edge —
/// enough to encode category at a glance, not enough to compete with the name.
///
/// Price is set in mono and given the most weight after the name, because on a
/// product literally called *Budget* Gurugram, price is the second thing anyone
/// wants to know.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.distanceKm,
    required this.saved,
    required this.onOpen,
    required this.onSave,
  });

  final Place place;
  final double distanceKm;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final category = place.category == 'food' &&
            RegExp(r'coffee|cafe|café', caseSensitive: false)
                .hasMatch(place.name)
        ? 'coffee'
        : place.category;
    final accent = p.categoryColor(category);

    return Material(
      color: p.surface,
      borderRadius: Radii.rLg,
      child: InkWell(
        onTap: onOpen,
        borderRadius: Radii.rLg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.rLg,
            border: Border.all(color: p.border, width: Strokes.hair),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The category spine.
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(Radii.lg),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.s16, Space.s16, Space.s8, Space.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(place.categoryLabel.toUpperCase(),
                                style: AppType.labelS(color: accent)),
                            const Spacer(),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} KM',
                              style:
                                  AppType.numeric(color: p.inkFaint, size: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.s8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                place.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.titleL(color: p.ink),
                              ),
                            ),
                            _SaveButton(saved: saved, onTap: onSave),
                          ],
                        ),
                        const SizedBox(height: Space.s8),
                        Row(
                          children: [
                            Text(place.price,
                                style: AppType.numeric(
                                    color: p.ink,
                                    size: 13,
                                    weight: FontWeight.w700)),
                            const SizedBox(width: Space.s6),
                            Flexible(
                              child: Text(
                                '· ${place.area}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.bodyS(color: p.inkMuted),
                              ),
                            ),
                          ],
                        ),
                        if (place.tags.isNotEmpty) ...[
                          const SizedBox(height: Space.s12),
                          Wrap(
                            spacing: Space.s6,
                            runSpacing: Space.s6,
                            children: [
                              for (final tag in place.tags.take(3))
                                Text('#$tag',
                                    style:
                                        AppType.labelS(color: p.inkFaint)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      // The filled state is gold, not red: saving here is a bookmark, not
      // affection, and gold is already the app's "worth your attention" colour.
      icon: AnimatedSwitcher(
        duration: Motion.fast,
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          key: ValueKey(saved),
          color: saved ? p.gold : p.inkFaint,
        ),
      ),
    );
  }
}
