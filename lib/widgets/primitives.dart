import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// A mono, letterspaced section label with a trailing rule.
///
/// The rule is what makes the page read as a document rather than a feed: it
/// gives every section a visible top edge and does the work a heading weight
/// would otherwise have to do.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.inkFaint;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(text.toUpperCase(), style: AppType.label(color: c)),
          const SizedBox(width: Space.s12),
          Expanded(child: Container(height: Strokes.hair, color: p.border)),
          if (trailing != null) ...[
            const SizedBox(width: Space.s12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Small mono pill for factual metadata — level, price, format.
class MetaPill extends StatelessWidget {
  const MetaPill(
    this.text, {
    super.key,
    this.color,
    this.background,
    this.icon,
    this.dashed = false,
  });

  final String text;
  final Color? color;
  final Color? background;
  final IconData? icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = color ?? p.inkMuted;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s8, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? p.surfaceSunken,
        borderRadius: Radii.rSm,
        border: dashed ? null : Border.all(color: p.border, width: Strokes.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: Space.s4),
          ],
          Text(text.toUpperCase(), style: AppType.labelS(color: fg)),
        ],
      ),
    );
    return child;
  }
}

/// Full-bleed hairline. Structure in this design comes from rules, not shadow.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: Strokes.hair, color: context.palette.border),
    );
  }
}

/// Fades and lifts a child into place. Applied per list item with a staggered
/// delay so a screen resolves top-to-bottom rather than appearing at once.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.standard);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Skeleton block for loading states.
///
/// Skeletons over spinners throughout: the page has known structure, so
/// showing that structure is more honest than a spinner that implies the app
/// has no idea what is coming.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.height = 14,
    this.width,
    this.radius = Radii.sm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(p.surfaceSunken, p.border, _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
