import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../services/api_config.dart';
import '../services/map_config.dart';
import '../state/app_state.dart';
import '../state/theme_controller.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/primitives.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<AppState>().profile.displayName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: Text('PROFILE', style: AppType.labelS(color: p.inkFaint)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.gutter, Space.s8, Space.gutter, Space.s40),
        children: [
          Text('Tune your city', style: AppType.display(color: p.ink)),
          const SizedBox(height: Space.s8),
          Text(
            'These only shape what gets surfaced first. Everything stays on '
            'this device.',
            style: AppType.body(color: p.inkMuted),
          ),

          const SizedBox(height: Space.s32),
          const SectionLabel('Appearance'),
          const _ThemePicker(),

          const SizedBox(height: Space.s24),
          const SectionLabel('Name'),
          TextField(
            controller: _name,
            style: AppType.body(color: p.ink),
            decoration: const InputDecoration(hintText: 'What should we call you?'),
          ),

          const SizedBox(height: Space.s24),
          const SectionLabel('Role'),
          _Options(
            values: roles,
            selected: state.profile.role,
            onSelect: (role) => state.finishOnboarding(
              state.profile.copyWith(
                role: role,
                displayName: _name.text.trim(),
              ),
            ),
          ),

          const SizedBox(height: Space.s24),
          const SectionLabel('Starting area'),
          _Options(
            values: neighbourhoods,
            selected: state.profile.neighbourhood,
            onSelect: state.setArea,
            notes: neighbourhoodNotes,
          ),

          const SizedBox(height: Space.s32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await state.finishOnboarding(
                  state.profile.copyWith(displayName: _name.text.trim()),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),

          const SizedBox(height: Space.s32),
          const Hairline(),
          const SizedBox(height: Space.s16),
          // Honest about what is and is not live. A demo build without a
          // Mapbox token should say so rather than quietly look worse.
          _Diagnostic(
            label: 'Backend',
            value: ApiConfig.baseUrl.replaceFirst(RegExp(r'^https?://'), ''),
          ),
          _Diagnostic(
            label: 'Events',
            value: state.eventsAreLive
                ? '${state.events.length} live'
                : '${state.events.length} cached/offline',
          ),
          _Diagnostic(
            label: 'Map tiles',
            value: MapConfig.hasToken ? 'Mapbox' : 'OpenStreetMap (no token)',
          ),
          _Diagnostic(
            label: 'Nearby',
            value: state.nearbyStatus,
          ),
        ],
      ),
    );
  }
}

/// Light / Dark / Match device.
///
/// A segmented control rather than a switch: "dark mode on/off" cannot express
/// three states, and following the device is a real choice, not the absence of
/// one. The selected segment slides, so the control reads as one object with a
/// position rather than three buttons that light up.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  static const _options = [
    (ThemeMode.light, 'Light', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
    (ThemeMode.system, 'Device', Icons.phone_iphone_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final controller = context.watch<ThemeController>();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        borderRadius: Radii.rMd,
        border: Border.all(color: p.border, width: Strokes.hair),
      ),
      child: Row(
        children: [
          for (final (mode, label, icon) in _options)
            Expanded(
              child: GestureDetector(
                onTap: () => controller.setMode(mode),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.standard,
                  padding: const EdgeInsets.symmetric(vertical: Space.s12),
                  decoration: BoxDecoration(
                    color: controller.mode == mode ? p.surface : Colors.transparent,
                    borderRadius: Radii.rSm,
                    border: Border.all(
                      color: controller.mode == mode ? p.borderStrong : Colors.transparent,
                      width: Strokes.hair,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 17,
                        color: controller.mode == mode ? p.accent : p.inkFaint,
                      ),
                      const SizedBox(height: Space.s6),
                      Text(
                        label.toUpperCase(),
                        style: AppType.labelS(
                          color: controller.mode == mode ? p.ink : p.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Inline option list instead of a dropdown.
///
/// Dropdowns hide the range of choices behind a tap and read as a form. With
/// seven roles and six neighbourhoods, showing them all is both faster and a
/// better introduction to how small and deliberate the city coverage is.
class _Options extends StatelessWidget {
  const _Options({
    required this.values,
    required this.selected,
    required this.onSelect,
    this.notes,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelect;
  final Map<String, String>? notes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s6),
            child: InkWell(
              onTap: () => onSelect(value),
              borderRadius: Radii.rMd,
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.s16, vertical: Space.s12),
                decoration: BoxDecoration(
                  color: selected == value ? p.accentSoft : p.surface,
                  borderRadius: Radii.rMd,
                  border: Border.all(
                    color: selected == value ? p.accent : p.border,
                    width: selected == value ? Strokes.edge : Strokes.hair,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value,
                              style: AppType.strong(color: p.ink, size: 14)),
                          if (notes?[value] != null) ...[
                            const SizedBox(height: 2),
                            Text(notes![value]!,
                                style: AppType.bodyS(color: p.inkMuted)),
                          ],
                        ],
                      ),
                    ),
                    if (selected == value)
                      Icon(Icons.check_rounded, size: 16, color: p.accent),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Diagnostic extends StatelessWidget {
  const _Diagnostic({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s8),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: AppType.labelS(color: p.inkFaint)),
          const Spacer(),
          Text(value, style: AppType.numeric(color: p.inkMuted, size: 11)),
        ],
      ),
    );
  }
}
