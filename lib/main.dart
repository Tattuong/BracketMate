import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/ad_constants.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/ad_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/storage_service.dart';
import 'core/bracket/demo_seed.dart';
import 'models/app_theme_preset.dart';
import 'providers/shop_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/tournament_provider.dart';
import 'screens/home/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/shop/shop_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/coin_reward_listener.dart';

late final ThemeProvider appThemeProvider;
late final ShopProvider appShopProvider;
late final TournamentProvider appTournamentProvider;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await StorageService.instance.init();

  appThemeProvider = ThemeProvider();
  await appThemeProvider.init();

  appShopProvider = ShopProvider();
  await appShopProvider.init(remote: false);

  appTournamentProvider = TournamentProvider();
  await appTournamentProvider.init();
  const demoKey = 'bm_demo_seeded';
  if (!(await StorageService.instance.getBool(demoKey) ?? false)) {
    final current = appTournamentProvider.event;
    final photoReady = current != null &&
        current.name == DemoSeed.name &&
        current.champion == null &&
        current.playedCount == 3 &&
        current.teams.length == 7;
    if (!photoReady) {
      await appTournamentProvider.adopt(DemoSeed.semis());
    }
    await StorageService.instance.saveBool(demoKey, true);
  }

  runApp(const BracketMateApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(appShopProvider.connectRemote());
    if (AdConstants.isConfigured) unawaited(AdService.init());
  });
}

class BracketMateApp extends StatelessWidget {
  const BracketMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appThemeProvider),
        ChangeNotifierProvider.value(value: appShopProvider),
        ChangeNotifierProvider.value(value: appTournamentProvider),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final themeMode =
        context.select<ThemeProvider, ThemeMode>((t) => t.themeMode);
    final themeId =
        context.select<ShopProvider, String>((s) => s.activeThemeId);
    final preset = AppThemePresets.get(themeId);
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'BracketMate',
      debugShowCheckedModeBanner: false,
      theme: preset.lightTheme(),
      darkTheme: preset.darkTheme(),
      themeMode: themeMode,
      locale: const Locale('en'),
      builder: (context, child) =>
          CoinRewardListener(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi'), Locale('en')],
      home: const SplashScreen(),
      routes: {
        '/shop': (_) => const ShopScreen(),
        '/privacy': (_) => const PrivacyPolicyScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
