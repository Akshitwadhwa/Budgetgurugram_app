import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController name;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: context.read<AppState>().profile.displayName);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tune your city', style: AppTheme.serif.copyWith(fontSize: 32)),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: state.profile.role.isEmpty ? null : state.profile.role,
            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
            items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
            onChanged: (value) => state.finishOnboarding(state.profile.copyWith(role: value ?? '', displayName: name.text.trim())),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: state.profile.neighbourhood,
            decoration: const InputDecoration(labelText: 'Starting area', border: OutlineInputBorder()),
            items: neighbourhoods.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
            onChanged: (value) => state.setArea(value ?? state.profile.neighbourhood),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              await state.finishOnboarding(state.profile.copyWith(displayName: name.text.trim()));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save preferences'),
          ),
        ],
      ),
    );
  }
}
