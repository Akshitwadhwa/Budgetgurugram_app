import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// The wordmark.
///
/// The monogram is a serif **G** inside a hairline circle — a stamp, in the
/// postal sense. It reads as something applied to a document after it has been
/// checked, which is the whole promise: this listing has been looked at.
///
/// "BUDGET" is set in mono above the serif "Gurugram", so the two halves of the
/// name carry the two halves of the product — the plain, priced, factual part
/// and the city itself.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.compact = false});

  /// Renders for a dark ground (onboarding's forest panel), independent of the
  /// app's light/dark theme.
  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = light ? const Color(0xFFF7F4ED) : p.ink;
    final subdued = light ? const Color(0xFFAFC4BB) : p.inkFaint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 28 : 34,
          height: compact ? 28 : 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: Strokes.hair),
            shape: BoxShape.circle,
          ),
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: Text(
              'G',
              style: AppType.titleL(color: color).copyWith(
                fontSize: compact ? 15 : 18,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: Space.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('BUDGET', style: AppType.labelS(color: subdued)),
              const SizedBox(height: 1),
              Text(
                'Gurugram',
                style: AppType.titleL(color: color).copyWith(fontSize: 19),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
