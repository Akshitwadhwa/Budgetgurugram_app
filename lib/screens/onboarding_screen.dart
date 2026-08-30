import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 1;
  List<String> selectedMotives = ['explore'];
  String role = '';
  String locationMode = 'area';
  String neighbourhood = 'Cyber City';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
              child: Row(
                children: [
                  const BrandMark(light: true),
                  const Spacer(),
                  TextButton(
                    onPressed: () => state.finishOnboarding(state.profile),
                    child: const Text('Skip', style: TextStyle(color: Color(0xFFC2D2CA))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('0$step / 03', style: const TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: step / 3, color: AppColors.gold, backgroundColor: AppColors.line, minHeight: 3),
                    const SizedBox(height: 22),
                    Expanded(child: _stepBody()),
                    Row(
                      children: [
                        if (step > 1)
                          TextButton(onPressed: () => setState(() => step -= 1), child: const Text('Back')),
                        const Spacer(),
                        FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.forest, minimumSize: const Size(140, 48)),
                          child: Text(step == 3 ? 'Show my city' : 'Continue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBody() {
    if (step == 1) {
      return ListView(
        children: [
          Text('What brings you here?', style: AppTheme.serif.copyWith(fontSize: 34)),
          const SizedBox(height: 8),
          const Text('Choose what you want to make easier today.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          ...motives.map((motive) {
            final selected = selectedMotives.contains(motive.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => setState(() {
                  selected ? selectedMotives.remove(motive.id) : selectedMotives.add(motive.id);
                  if (selectedMotives.isEmpty) selectedMotives = ['explore'];
                }),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? AppColors.forest : AppColors.line)),
                tileColor: selected ? const Color(0xFFE4EEE7) : AppColors.white,
                leading: Text(motive.icon, style: const TextStyle(fontSize: 20)),
                title: Text(motive.label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                subtitle: Text(motive.detail),
              ),
            );
          }),
        ],
      );
    }
    if (step == 2) {
      return ListView(
        children: [
          Text('Who are you making the city work for?', style: AppTheme.serif.copyWith(fontSize: 32)),
          const SizedBox(height: 8),
          const Text('Optional — helps us surface the right mix.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: roles.map((item) {
              final selected = role == item;
              return ChoiceChip(
                label: Text(item),
                selected: selected,
                onSelected: (_) => setState(() => role = item),
                selectedColor: AppColors.forest,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.forest),
              );
            }).toList(),
          ),
        ],
      );
    }
    return ListView(
      children: [
        Text('Where should we start?', style: AppTheme.serif.copyWith(fontSize: 32)),
        const SizedBox(height: 8),
        const Text('Use your location or pick a Gurugram neighbourhood.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _locationChoice('current', 'Use my location', 'Only to personalise your view')),
            const SizedBox(width: 10),
            Expanded(child: _locationChoice('area', 'Choose an area', 'Stay approximate')),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: neighbourhood,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Neighbourhood'),
          items: neighbourhoods.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
          onChanged: (value) => setState(() => neighbourhood = value ?? neighbourhood),
        ),
      ],
    );
  }

  Widget _locationChoice(String id, String title, String detail) {
    final selected = locationMode == id;
    return InkWell(
      onTap: () async {
        setState(() => locationMode = id);
        if (id == 'current') await context.read<AppState>().useCurrentLocation();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4EEE7) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.forest : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (step < 3) {
      setState(() => step += 1);
      return;
    }
    final state = context.read<AppState>();
    await state.finishOnboarding(state.profile.copyWith(
      motives: selectedMotives,
      role: role,
      locationMode: locationMode,
      neighbourhood: neighbourhood,
    ));
  }
}
