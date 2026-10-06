import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/bracket/bracket_engine.dart';
import '../core/bracket/demo_seed.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigator.dart';
import '../models/app_theme_preset.dart';
import '../providers/tournament_provider.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/coin_balance_chip.dart';
import '../widgets/team_badge.dart';
import 'summary_screen.dart';

class BracketScreen extends StatefulWidget {
  const BracketScreen({super.key});

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  var _upcoming = true;
  var _round = -1;

  @override
  Widget build(BuildContext context) {
    final event = context.watch<TournamentProvider>().event;
    if (event == null) {
      return const FtrScaffold(body: Center(child: Text('No tournament yet')));
    }
    final round = (_round < 0 ? _readyRound(event) : _round)
        .clamp(0, event.rounds.length - 1);
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matches = event.rounds[round].where((match) {
      if (_upcoming) return match.phase == MatchPhase.ready;
      return !match.isBye;
    }).toList();
    final byes = round == 0
        ? [
            for (final match in event.rounds.first)
              if (match.isBye) event.teamOf(match.winnerId),
          ].whereType<Team>().toList()
        : event.byesInto(round);
    return FtrScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface)),
                ),
                const SizedBox(width: 8),
                const CoinBalanceChip(variant: CoinChipVariant.header),
                IconButton(
                  tooltip: 'Settings',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: AppTabs.goSettings,
                  icon: Icon(Icons.settings_outlined, color: scheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text('${event.teams.length} teams · Single elimination',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      color: scheme.primary,
                      backgroundColor: ftr.border,
                      value: event.realMatches.isEmpty
                          ? 0
                          : event.playedCount / event.realMatches.length,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SummaryScreen(
                        previewFinish: event.champion == null &&
                            event.name == DemoSeed.name),
                  )),
                  child: Text(
                    '${event.playedCount}/${event.realMatches.length} matches complete',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Color.lerp(
                      ftr.surface, scheme.primary, isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  _Seg(
                      label: 'Bracket',
                      selected: !_upcoming,
                      onTap: () => setState(() => _upcoming = false)),
                  _Seg(
                      label: 'Upcoming',
                      selected: _upcoming,
                      onTap: () => setState(() => _upcoming = true)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < event.rounds.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RoundChip(
                        label: event.roundName(index),
                        selected: round == index,
                        onTap: () => setState(() => _round = index),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _upcoming
                      ? 'No matches are ready in this round.'
                      : 'This round only has byes.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (var i = 0; i < matches.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MatchCard(
                    event: event,
                    match: matches[i],
                    emphasize: _upcoming && i == 0,
                    showReady: matches[i].phase == MatchPhase.ready && i == 0,
                    onResult: () => _askScore(context, event, matches[i]),
                  ),
                ),
            for (final team in byes)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ftr.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ftr.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${team.name} has a bye\nAdvances to the ${event.roundName(round == 0 ? 1 : round).toLowerCase()} because this tournament has ${event.teams.length} teams.',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Results update the next round automatically',
                        style: TextStyle(color: scheme.onSurfaceVariant))),
              ],
            ),
            if (event.champion != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SummaryScreen())),
                  child: const Text('View summary'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _readyRound(Tournament event) {
    for (var index = 0; index < event.rounds.length; index++) {
      if (event.rounds[index].any((match) => match.phase == MatchPhase.ready)) {
        return index;
      }
    }
    return event.rounds.length - 1;
  }

  Future<void> _askScore(
      BuildContext context, Tournament event, BracketMatch match) async {
    final saved = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ScoreSheet(
        home: event.teamOf(match.aId)?.name ?? '',
        away: event.teamOf(match.bId)?.name ?? '',
        scoreA: match.scoreA ?? 0,
        scoreB: match.scoreB ?? 0,
      ),
    );
    if (saved == null || !context.mounted) return;
    final scoreA = saved.$1;
    final scoreB = saved.$2;
    final error =
        context.read<TournamentProvider>().record(match.id, scoreA, scoreB);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final updated = context.read<TournamentProvider>().event;
    if (updated?.champion != null && updated!.finalMatch.id == match.id) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SummaryScreen()));
    }
  }
}

class _ScoreSheet extends StatefulWidget {
  final String home;
  final String away;
  final int scoreA;
  final int scoreB;

  const _ScoreSheet({
    required this.home,
    required this.away,
    required this.scoreA,
    required this.scoreB,
  });

  @override
  State<_ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends State<_ScoreSheet> {
  late final TextEditingController _a =
      TextEditingController(text: '${widget.scoreA}');
  late final TextEditingController _b =
      TextEditingController(text: '${widget.scoreB}');

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter result', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _ScoreField(
                      label: widget.home,
                      controller: _a,
                      fieldKey: const Key('score-a'))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                  child: _ScoreField(
                      label: widget.away,
                      controller: _b,
                      fieldKey: const Key('score-b'))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('save-score'),
              onPressed: () => Navigator.pop(
                context,
                (
                  int.tryParse(_a.text.trim()) ?? -1,
                  int.tryParse(_b.text.trim()) ?? -1
                ),
              ),
              child: const Text('Save result'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Key fieldKey;

  const _ScoreField(
      {required this.label, required this.controller, required this.fieldKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Tournament event;
  final BracketMatch match;
  final bool emphasize;
  final bool showReady;
  final VoidCallback onResult;

  const _MatchCard({
    required this.event,
    required this.match,
    required this.emphasize,
    required this.showReady,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final home = event.teamOf(match.aId);
    final away = event.teamOf(match.bId);
    final ready = match.phase == MatchPhase.ready;
    final done = match.phase == MatchPhase.done;
    final readyInk = isDark ? const Color(0xFFD9F99D) : const Color(0xFF3F6212);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: ftr.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ftr.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${event.roundName(match.round).toUpperCase()} ${(match.index + 1).toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
              const Spacer(),
              if (showReady)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        AppColors.success
                            .withValues(alpha: isDark ? 0.34 : 0.22),
                        ftr.surface,
                      ),
                      borderRadius: BorderRadius.circular(99)),
                  child: Text('Ready',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: readyInk)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Side(team: home, alignEnd: false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: done
                    ? Text('${match.scoreA} - ${match.scoreB}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18))
                    : Text('VS',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800)),
              ),
              Expanded(child: _Side(team: away, alignEnd: true)),
            ],
          ),
          const SizedBox(height: 8),
          Text(event.slotLabel(match),
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          if (emphasize && ready) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onResult,
                child: const Text('Enter result'),
              ),
            ),
          ] else if (ready)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                  onPressed: onResult,
                  icon: const Icon(Icons.chevron_right_rounded)),
            )
          else if (done)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: onResult, child: const Text('Edit result')),
            ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Seg(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoundChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : Color.lerp(ftr.surface, scheme.primary, isDark ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final Team? team;
  final bool alignEnd;

  const _Side({required this.team, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final name = team?.name ?? 'Waiting';
    final badge = TeamBadge(team: team, size: 48);
    final label = Flexible(
      child: Text(name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(fontWeight: FontWeight.w800)),
    );
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [label, const SizedBox(width: 8), badge]
          : [badge, const SizedBox(width: 8), label],
    );
  }
}
