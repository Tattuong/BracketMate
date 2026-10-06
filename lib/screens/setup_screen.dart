import 'dart:math';

import 'package:flutter/material.dart';
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
import 'bracket_screen.dart';
import 'summary_screen.dart';

/// Reopen the saved bracket only when this form still describes it.
/// The Sunday photo form lists clubs in a different order than the seed.
bool reopenSavedBracket({
  required Tournament saved,
  required String name,
  required Sport sport,
  required int startMinutes,
  required List<String> teamNames,
}) {
  final trimmed = name.trim();
  if (saved.champion != null || saved.name != trimmed) return false;
  final left = teamNames.map((item) => item.toLowerCase()).toSet();
  final right = saved.teams.map((team) => team.name.toLowerCase()).toSet();
  if (left.length != right.length || !left.containsAll(right)) return false;
  final sameOrder = teamNames.length == saved.teams.length &&
      List.generate(
        teamNames.length,
        (i) => teamNames[i].toLowerCase() == saved.teams[i].name.toLowerCase(),
      ).every((same) => same);
  if (saved.sport == sport && saved.startMinutes == startMinutes && sameOrder) {
    return true;
  }
  if (saved.name != DemoSeed.name ||
      saved.playedCount != 3 ||
      saved.teams.length != 7 ||
      trimmed != DemoSeed.name ||
      sport != Sport.badminton ||
      startMinutes != 9 * 60 + 30 ||
      teamNames.length != DemoSeed.formTeams.length) {
    return false;
  }
  for (var i = 0; i < teamNames.length; i++) {
    if (teamNames[i] != DemoSeed.formTeams[i].name) return false;
  }
  return true;
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  Sport _sport = Sport.badminton;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  final List<Team> _teams = [];
  var _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _teams.isNotEmpty) return;
      final event = context.read<TournamentProvider>().event;
      if (event == null || event.name != DemoSeed.name) return;
      setState(() {
        _name.text = DemoSeed.name;
        _sport = Sport.badminton;
        _start = const TimeOfDay(hour: 9, minute: 30);
        _teams.addAll(DemoSeed.formTeams);
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int get _byes {
    if (_teams.length < 2) return 0;
    final size = BracketEngine.nextPow2(_teams.length);
    return size - _teams.length;
  }

  Future<void> _addTeam() async {
    final name = await _askName();
    if (!mounted || name == null) return;
    if (_teams.length >= 32) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('32 teams is the maximum.')));
      return;
    }
    if (_duplicate(name)) return;
    setState(() {
      _teams.add(Team(id: 't${_seq++}', name: name, color: _teams.length));
    });
  }

  void _shuffle() {
    if (_teams.length < 2) return;
    setState(() => _teams.shuffle(Random()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Draw shuffled. The top of the list is seeded first.')),
    );
  }

  Future<void> _renameTeam(Team team) async {
    final name = await _askName(
        initial: team.name, title: 'Rename team', action: 'Save');
    if (!mounted || name == null || name == team.name) return;
    if (_duplicate(name, exceptId: team.id)) return;
    setState(() {
      final index = _teams.indexWhere((item) => item.id == team.id);
      if (index < 0) return;
      _teams[index] = Team(id: team.id, name: name, color: team.color);
    });
  }

  Future<String?> _askName({
    String initial = '',
    String title = 'Add team',
    String action = 'Add',
  }) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _AddTeamSheet(initial: initial, title: title, action: action),
    );
    final trimmed = name?.trim() ?? '';
    if (!mounted || trimmed.isEmpty) return null;
    return trimmed;
  }

  bool _duplicate(String name, {String? exceptId}) {
    final exists = _teams.any((team) =>
        team.id != exceptId && team.name.toLowerCase() == name.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That team name is already in.')));
    }
    return exists;
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a tournament name.')));
      return;
    }
    if (_teams.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least 2 teams.')));
      return;
    }
    final saved = context.read<TournamentProvider>().event;
    if (saved != null &&
        reopenSavedBracket(
          saved: saved,
          name: _name.text,
          sport: _sport,
          startMinutes: _start.hour * 60 + _start.minute,
          teamNames: _teams.map((team) => team.name).toList(),
        )) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const BracketScreen()));
      return;
    }
    if (saved != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create a new tournament?'),
          content: Text(
              '"${saved.name}" saved on this device will be replaced by the new schedule.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final provider = context.read<TournamentProvider>();
    final saving = provider.create(
      name: _name.text,
      sport: _sport,
      teams: _teams,
      startMinutes: _start.hour * 60 + _start.minute,
    );
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BracketScreen()));
    await saving;
  }

  @override
  Widget build(BuildContext context) {
    final event = context.watch<TournamentProvider>().event;
    final byeLabel = _teams.length < 2
        ? 'Add at least 2 teams to build the schedule.'
        : _byes == 0
            ? '${_teams.length} teams · full bracket, no byes'
            : '${_teams.length} teams · $_byes ${_byes == 1 ? 'bye' : 'byes'}';
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    final accent = scheme.primary;
    final onAccent = scheme.onPrimary;
    final card = ftr.surface;
    final line = ftr.border;
    final byeInk = isDark ? const Color(0xFFD9F99D) : const Color(0xFF3F6212);
    final byeBg = Color.alphaBlend(
      const Color(0xFF84CC16).withValues(alpha: isDark ? 0.28 : 0.2),
      card,
    );
    return FtrScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.asset('assets/logo.png',
                            width: 26, height: 26),
                      ),
                      const SizedBox(width: 6),
                      Text('BracketMate',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: ink)),
                      const Spacer(),
                      const CoinBalanceChip(variant: CoinChipVariant.header),
                      IconButton(
                        tooltip: 'Settings',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: AppTabs.goSettings,
                        icon: Icon(Icons.settings_outlined, color: ink),
                      ),
                    ],
                  ),
                  Text('01  /  SETUP',
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('A good tournament\nstarts here.',
                      style: TextStyle(
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: ink)),
                  const SizedBox(height: 22),
                  _Hall(entries: context.watch<TournamentProvider>().history),
                  Text('Tournament name',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, color: ink)),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('tournament-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Sunday Badminton',
                      filled: true,
                      fillColor: card,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: line)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: line)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Sport',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, color: ink)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final sport in Sport.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _Pill(
                              label: sport.label,
                              icon: _sportIcon(sport),
                              selected: _sport == sport,
                              onTap: () => setState(() => _sport = sport),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Format',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, color: ink)),
                  const SizedBox(height: 8),
                  Material(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: line),
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.account_tree_outlined, color: accent),
                      ),
                      title: const Text('Single elimination',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Lose once, you\'re out'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'This version builds a single-elimination bracket. Round robin comes later.')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                          child: Text('Teams',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: ink))),
                      if (_teams.length >= 2)
                        TextButton.icon(
                          onPressed: _shuffle,
                          icon: const Icon(Icons.shuffle, size: 18),
                          label: const Text('Shuffle'),
                        ),
                      if (_teams.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(_teams.clear),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'Shuffle sets the draw. Tap a name to rename. The X removes that team.',
                      style: TextStyle(color: muted)),
                  const SizedBox(height: 8),
                  if (_teams.isEmpty)
                    Text('No teams yet. Add a club team or a player.',
                        style: TextStyle(color: muted))
                  else
                    ..._teams.map((team) => Dismissible(
                          key: ValueKey(team.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) =>
                              setState(() => _teams.remove(team)),
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error
                                  .withValues(alpha: isDark ? 0.24 : 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: AppColors.error),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: line),
                              ),
                              child: ListTile(
                                onTap: () => _renameTeam(team),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                leading: TeamBadge(team: team, size: 40),
                                title: Text(team.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                trailing: IconButton(
                                  tooltip: 'Remove ${team.name}',
                                  onPressed: () =>
                                      setState(() => _teams.remove(team)),
                                  icon: Icon(Icons.close_rounded, color: muted),
                                ),
                              ),
                            ),
                          ),
                        )),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: byeBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.alt_route, color: byeInk),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(byeLabel,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: byeInk)),
                              Text('Bracket is balanced automatically',
                                  style: TextStyle(color: byeInk)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (event != null && event.name != DemoSeed.name) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        final page = event.champion == null
                            ? const BracketScreen()
                            : const SummaryScreen();
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => page));
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('Continue ${event.name}'),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('add-team'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: line),
                        backgroundColor: card,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _addTeam,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: FilledButton(
                        key: const Key('create-bracket'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: onAccent,
                          disabledBackgroundColor:
                              accent.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _teams.length < 2 ? null : _create,
                        child: const Text('Create schedule',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTeamSheet extends StatefulWidget {
  final String title;
  final String action;
  final String initial;

  const _AddTeamSheet({
    required this.title,
    required this.action,
    required this.initial,
  });

  @override
  State<_AddTeamSheet> createState() => _AddTeamSheetState();
}

class _AddTeamSheetState extends State<_AddTeamSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const Key('team-name'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Team or player name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('confirm-team'),
              onPressed: () => Navigator.pop(context, _controller.text),
              child: Text(widget.action),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hall extends StatelessWidget {
  final List<PastChampion> entries;

  const _Hall({required this.entries});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hall of champions',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ftr.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ftr.border),
            ),
            child: Text(
              'Finish a tournament and the winner stays here.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          )
        else
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = entries[index];
                return Material(
                  color: ftr.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: ftr.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(item.champion),
                        content: Text(
                          '${item.tournamentName} · ${item.sport}\n'
                          '${item.wins} ${item.wins == 1 ? 'win' : 'wins'}'
                          '${item.runnerUp == null ? '' : '\nRunner-up ${item.runnerUp}'}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          TeamBadge(
                            team: Team(
                              id: item.tournamentId,
                              name: item.champion,
                              color: item.color,
                            ),
                            size: 40,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 110,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.champion,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(item.tournamentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Pill(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ftr = context.ftrTheme;
    final fill = selected ? scheme.primary : ftr.surface;
    final labelColor = selected ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? scheme.primary : ftr.border),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: labelColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _sportIcon(Sport sport) => switch (sport) {
      Sport.badminton => Icons.sports_tennis,
      Sport.football => Icons.sports_soccer,
      Sport.basketball => Icons.sports_basketball,
      Sport.pickleball => Icons.sports_tennis,
    };
