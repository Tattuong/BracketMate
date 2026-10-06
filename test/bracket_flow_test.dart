import 'dart:io';

import 'package:bracketmate/core/services/hive_service.dart';
import 'package:bracketmate/core/services/storage_service.dart';
import 'package:bracketmate/core/constants/app_colors.dart';
import 'package:bracketmate/models/app_theme_preset.dart';
import 'package:bracketmate/providers/shop_provider.dart';
import 'package:bracketmate/providers/tournament_provider.dart';
import 'package:bracketmate/screens/bracket_screen.dart';
import 'package:bracketmate/screens/setup_screen.dart';
import 'package:bracketmate/widgets/coin_balance_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('bm_flow');
    await HiveService.init(path: dir.path, suffix: '_flow');
    await StorageService.instance.init();
  });

  testWidgets('creating a bracket and entering the final opens the summary',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopProvider()),
          ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ],
        child: const MaterialApp(home: SetupScreen()),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byType(CoinBalanceChip), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('tournament-name')), 'Sunday Badminton');
    await _add(tester, 'Falcons');
    await _add(tester, 'Nova');
    await tester.tap(find.byKey(const Key('create-bracket')));
    await tester.pumpAndSettle();

    expect(find.byType(BracketScreen), findsOneWidget);
    expect(find.text('Sunday Badminton'), findsWidgets);
    expect(find.text('Enter result'), findsOneWidget);

    await tester.tap(find.text('Enter result'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('score-a')), '2');
    await tester.enterText(find.byKey(const Key('score-b')), '1');
    await tester.tap(find.byKey(const Key('save-score')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('CHAMPION'), findsOneWidget);
    expect(find.text('FALCONS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Share schedule'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Share schedule'), findsOneWidget);
  });

  testWidgets('setup and summary follow the active color theme',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopProvider()),
          ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ],
        child: MaterialApp(
          theme: AppThemePresets.peach.lightTheme(),
          darkTheme: AppThemePresets.defaultPreset.darkTheme(),
          home: const SetupScreen(),
        ),
      ),
    );
    await tester.pump();

    final label = tester.widget<Text>(find.text('01  /  SETUP'));
    expect(label.style?.color, AppThemePresets.peach.primary);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ShopProvider()),
          ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ],
        child: MaterialApp(
          theme: AppThemePresets.defaultPreset.lightTheme(),
          darkTheme: AppThemePresets.defaultPreset.darkTheme(),
          themeMode: ThemeMode.dark,
          home: const SetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headline =
        tester.widget<Text>(find.text('A good tournament\nstarts here.'));
    expect(headline.style?.color, AppColors.darkInk);
  });
}

Future<void> _add(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('add-team')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('team-name')), name);
  await tester.tap(find.byKey(const Key('confirm-team')));
  await tester.pumpAndSettle();
}
