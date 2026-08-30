import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_mark.dart';
import '../widgets/primitives.dart';

/// Three questions, then the city.
///
/// Presented on a forest ground with a raised paper sheet — the app introducing
/// itself before handing over a document. The step indicator reuses the
/// segmented language of the confidence meter, so the same visual grammar means
/// "progress through a fixed set" in both places.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 1;
  List<String> _motives = ['explore'];
  String _role = '';
  String _locationMode = 'area';
  String _neighbourhood = 'Cyber City';

  static const _forest = Color(0xFF1E3B35);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: _forest,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.gutter, Space.s16, Space.s12, Space.s16),
              child: Row(
                children: [
                  const BrandMark(light: true),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context
                        .read<AppState>()
                        .finishOnboarding(context.read<AppState>().profile),
                    child: Text('SKIP',
                        style: AppType.labelS(color: const Color(0xFFAFC4BB))),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: p.canvas,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.sheet),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.gutter, Space.s24, Space.gutter, Space.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StepIndicator(step: _step),
                      const SizedBox(height: Space.s24),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Motion.base,
                          switchInCurve: Motion.standard,
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _body(),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.s12),
                      Row(
                        children: [
                          if (_step > 1)
                            TextButton.icon(
                              onPressed: () => setState(() => _step -= 1),
                              icon: const Icon(Icons.arrow_back_rounded, size: 15),
                              label: const Text('Back'),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _continue,
                            child: Text(_step == 3 ? 'Show my city' : 'Continue'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() => switch (_step) {
        1 => _MotiveStep(
            selected: _motives,
            onToggle: (id) => setState(() {
              _motives.contains(id) ? _motives.remove(id) : _motives.add(id);
              if (_motives.isEmpty) _motives = ['explore'];
            }),
          ),
        2 => _RoleStep(
            selected: _role,
            onSelect: (role) => setState(() => _role = role),
          ),
        _ => _LocationStep(
            mode: _locationMode,
            neighbourhood: _neighbourhood,
            onMode: (mode) async {
              setState(() => _locationMode = mode);
              if (mode == 'current') {
                await context.read<AppState>().useCurrentLocation();
              }
            },
            onArea: (area) => setState(() => _neighbourhood = area),
          ),
      };

  Future<void> _continue() async {
    if (_step < 3) {
      setState(() => _step += 1);
      return;
    }
    final state = context.read<AppState>();
    await state.finishOnboarding(state.profile.copyWith(
      motives: _motives,
      role: _role,
      locationMode: _locationMode,
      neighbourhood: _neighbourhood,
    ));
  }
}

/// Segmented progress, matching [ConfidenceMeter]'s visual grammar.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: Space.s4),
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.standard,
              width: i == step ? 28 : 14,
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? p.gold : p.border,
                borderRadius: Radii.rPill,
              ),
            ),
          ),
        const SizedBox(width: Space.s8),
        Text('0$step / 03', style: AppType.numeric(color: p.inkFaint, size: 10)),
      ],
    );
  }
}

class _MotiveStep extends StatelessWidget {
  const _MotiveStep({required this.selected, required this.onToggle});
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(
              text: 'What brings you\n', style: AppType.display(color: p.ink)),
          TextSpan(text: 'here?', style: AppType.displayAccent(color: p.gold)),
        ])),
        const SizedBox(height: Space.s12),
        Text('Pick as many as apply. You can change this later.',
            style: AppType.body(color: p.inkMuted)),
        const SizedBox(height: Space.s24),
        for (final (i, motive) in motives.indexed)
          Reveal(
            delay: Motion.stagger(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s8),
              child: _Choice(
                selected: selected.contains(motive.id),
                onTap: () => onToggle(motive.id),
                leading: Text(motive.icon,
                    style: TextStyle(fontSize: 17, color: p.accent)),
                title: motive.label,
                subtitle: motive.detail,
                multi: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Who are we\n', style: AppType.display(color: p.ink)),
          TextSpan(
              text: 'working for?', style: AppType.displayAccent(color: p.gold)),
        ])),
        const SizedBox(height: Space.s12),
        Text('Optional — it only changes what we surface first.',
            style: AppType.body(color: p.inkMuted)),
        const SizedBox(height: Space.s24),
        for (final (i, role) in roles.indexed)
          Reveal(
            delay: Motion.stagger(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.s6),
              child: _Choice(
                selected: selected == role,
                onTap: () => onSelect(role),
                title: role,
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.mode,
    required this.neighbourhood,
    required this.onMode,
    required this.onArea,
  });

  final String mode;
  final String neighbourhood;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onArea;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Where should\n', style: AppType.display(color: p.ink)),
          TextSpan(text: 'we start?', style: AppType.displayAccent(color: p.gold)),
        ])),
        const SizedBox(height: Space.s12),
        Text(
          'Location is used only to sort what you see. It never leaves your '
          'phone.',
          style: AppType.body(color: p.inkMuted),
        ),
        const SizedBox(height: Space.s24),
        _Choice(
          selected: mode == 'current',
          onTap: () => onMode('current'),
          leading: Icon(Icons.my_location_rounded, size: 17, color: p.accent),
          title: 'Use my location',
          subtitle: 'Most accurate distances',
        ),
        const SizedBox(height: Space.s6),
        _Choice(
          selected: mode == 'area',
          onTap: () => onMode('area'),
          leading: Icon(Icons.grid_view_rounded, size: 17, color: p.accent),
          title: 'Pick an area',
          subtitle: 'Stay approximate',
        ),
        if (mode == 'area') ...[
          const SizedBox(height: Space.s20),
          const SectionLabel('Neighbourhood'),
          for (final area in neighbourhoods)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s6),
              child: _Choice(
                selected: neighbourhood == area,
                onTap: () => onArea(area),
                title: area,
                subtitle: neighbourhoodNotes[area],
              ),
            ),
        ],
      ],
    );
  }
}

/// One selectable row.
///
/// Multi-select rows get a square indicator, single-select a round one — the
/// shape says whether picking this will deselect something else, before you
/// find out by tapping.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.leading,
    this.multi = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.rMd,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s16, vertical: Space.s16),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.surface,
          borderRadius: Radii.rMd,
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? Strokes.edge : Strokes.hair,
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 22, child: Center(child: leading!)),
              const SizedBox(width: Space.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.strong(color: p.ink, size: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppType.bodyS(color: p.inkMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.s12),
            AnimatedContainer(
              duration: Motion.fast,
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: selected ? p.accent : Colors.transparent,
                borderRadius:
                    multi ? Radii.rSm : BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: selected ? p.accent : p.borderStrong,
                  width: Strokes.hair,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 13, color: p.onAccent)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
