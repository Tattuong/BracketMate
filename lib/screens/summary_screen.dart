import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/bracket/demo_seed.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigator.dart';
import '../models/app_theme_preset.dart';
import '../providers/tournament_provider.dart';
import '../widgets/app_scaffold.dart';
import '../core/bracket/bracket_engine.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/team_badge.dart';
import 'bracket_screen.dart';
import 'setup_screen.dart';

class SummaryScreen extends StatelessWidget {
  final bool previewFinish;

  const SummaryScreen({super.key, this.previewFinish = false});

  @override
  Widget build(BuildContext context) {
    final live = context.watch<TournamentProvider>().event;
    if (live == null) {
      return const FtrScaffold(body: Center(child: Text('No tournament yet')));
    }
    final event =
        previewFinish && live.champion == null && live.name == DemoSeed.name
            ? DemoSeed.finish(live)
            : live;
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final winner = event.champion;
    final second = event.runnerUp;
    final finalMatch = event.finalMatch;
    return FtrScaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text('Tournament summary',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: scheme.onSurface)),
            Text(event.name,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
        actions: const [
          Center(
            child: CoinBalanceChip(variant: CoinChipVariant.header),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: AppTabs.goSettings,
            icon: Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                        ftr.primary, Colors.white, isDark ? 0.08 : 0.16)!,
                    ftr.primary,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: scheme.onPrimary, size: 36),
                  const SizedBox(height: 8),
                  Text('CHAMPION',
                      style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    (winner?.name ?? 'Not finished').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  if (winner != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Color.lerp(ftr.primary, Colors.black, 0.22),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          '${event.winsOf(winner.id)} ${event.winsOf(winner.id) == 1 ? 'win' : 'wins'}',
                          style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('FINAL',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ftr.border),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _Finalist(
                          name: event.teamOf(finalMatch.aId)?.name ?? '—',
                          team: event.teamOf(finalMatch.aId))),
                  Text(
                    finalMatch.winnerId == null
                        ? '–'
                        : '${finalMatch.scoreA} - ${finalMatch.scoreB}',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  Expanded(
                      child: _Finalist(
                          name: event.teamOf(finalMatch.bId)?.name ?? '—',
                          team: event.teamOf(finalMatch.bId))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(value: '${event.teams.length}', label: 'Teams'),
                const SizedBox(width: 8),
                _Stat(value: '${event.realMatches.length}', label: 'Matches'),
                const SizedBox(width: 8),
                _Stat(value: '${event.byeCount}', label: 'Byes'),
              ],
            ),
            const SizedBox(height: 18),
            Text('Standings',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface)),
            const SizedBox(height: 8),
            if (winner != null)
              _Place(
                  place: '01',
                  teamName: winner.name,
                  team: winner,
                  highlight: true),
            if (second != null) ...[
              const SizedBox(height: 8),
              _Place(
                  place: '02',
                  teamName: second.name,
                  team: second,
                  highlight: false),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Share.share(event.shareResult()),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export result'),
              ),
            ),
            if (winner != null) ...[
              const SizedBox(height: 18),
              Text('Road to the title',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
              const SizedBox(height: 8),
              for (final match in event.realMatches)
                if (match.winnerId == winner.id)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RoadRow(
                        event: event, match: match, winnerId: winner.id),
                  ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Share.share(event.shareSchedule()),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share schedule'),
              ),
            ),
            if (!previewFinish && winner != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<TournamentProvider>().rematch();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const BracketScreen()),
                      (route) => route.isFirst,
                    );
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Rematch'),
                ),
              ),
            ],
            if (!previewFinish) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  final restart = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('New tournament?'),
                      content: const Text(
                          'This deletes the schedule saved on this device and starts over.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Stay')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Start over')),
                      ],
                    ),
                  );
                  if (restart != true || !context.mounted) return;
                  final provider = context.read<TournamentProvider>();
                  final finished = provider.event;
                  if (finished != null) await provider.remember(finished);
                  if (!context.mounted) return;
                  await context.read<TournamentProvider>().clear();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Start another'),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_iphone,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Saved on this device',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Finalist extends StatelessWidget {
  final String name;
  final dynamic team;

  const _Finalist({required this.name, required this.team});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamBadge(team: team, size: 46),
        const SizedBox(height: 6),
        Text(name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.ftrTheme.border),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RoadRow extends StatelessWidget {
  final Tournament event;
  final BracketMatch match;
  final String winnerId;

  const _RoadRow({
    required this.event,
    required this.match,
    required this.winnerId,
  });

  @override
  Widget build(BuildContext context) {
    final winnerIsHome = match.aId == winnerId;
    final opponentId = winnerIsHome ? match.bId : match.aId;
    final opponent = event.teamOf(opponentId)?.name ?? 'Bye';
    final won = winnerIsHome ? match.scoreA : match.scoreB;
    final lost = winnerIsHome ? match.scoreB : match.scoreA;
    final score = match.isBye || won == null ? 'bye' : '$won-$lost';
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ftr.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ftr.border),
      ),
      child: Row(
        children: [
          Text(event.roundName(match.round),
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Beat $opponent  $score',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  final String place;
  final String teamName;
  final dynamic team;
  final bool highlight;

  const _Place(
      {required this.place,
      required this.teamName,
      required this.team,
      required this.highlight});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? Color.alphaBlend(
                AppColors.warning.withValues(alpha: isDark ? 0.36 : 0.55),
                scheme.surface,
              )
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ftrTheme.border),
      ),
      child: Row(
        children: [
          Text(place, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          TeamBadge(team: team, size: 36),
          const SizedBox(width: 10),
          Text(teamName, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
