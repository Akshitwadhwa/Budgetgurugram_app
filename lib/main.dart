import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_mark.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const BudgetGurugramApp());
}

class BudgetGurugramApp extends StatelessWidget {
  const BudgetGurugramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Budget Gurugram',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          home: const AppToastListener(child: _Root()),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: state.loading
          ? const _Boot()
          : state.onboarded
              ? const HomeShell()
              : const OnboardingScreen(),
    );
  }
}

/// Boot screen.
///
/// A wordmark rather than a spinner. This state lasts a few hundred
/// milliseconds; a spinner in that window reads as a stutter, whereas a mark
/// reads as the app introducing itself.
class _Boot extends StatelessWidget {
  const _Boot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: const Center(child: BrandMark()),
    );
  }
}
