import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../providers/tournament_provider.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_ui.dart';
import 'setup_screen.dart';
import 'summary_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final event = context.read<TournamentProvider>().event;
    final page =
        event?.champion != null ? const SummaryScreen() : const SetupScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return FtrScaffold(
      extendBody: false,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/logo.png',
                width: 160,
                height: 160,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.t(context, 'appName'),
              style: AppTypography.display(
                  size: 32,
                  context: context,
                  color: AppColors.primaryOf(context)),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.t(context, 'appTagline'),
              style: AppTypography.body(size: 15, context: context),
            ),
          ],
        ),
      ),
    );
  }
}
