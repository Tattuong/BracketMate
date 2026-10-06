import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/bracket/bracket_engine.dart';
import '../core/services/storage_service.dart';

class PastChampion {
  final String tournamentId;
  final String tournamentName;
  final String sport;
  final String champion;
  final int color;
  final String? runnerUp;
  final int teams;
  final int wins;
  final int atMillis;

  const PastChampion({
    required this.tournamentId,
    required this.tournamentName,
    required this.sport,
    required this.champion,
    required this.color,
    required this.runnerUp,
    required this.teams,
    required this.wins,
    required this.atMillis,
  });

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'tournamentName': tournamentName,
        'sport': sport,
        'champion': champion,
        'color': color,
        'runnerUp': runnerUp,
        'teams': teams,
        'wins': wins,
        'atMillis': atMillis,
      };

  factory PastChampion.fromJson(Map<String, dynamic> json) => PastChampion(
        tournamentId: json['tournamentId'] as String,
        tournamentName: json['tournamentName'] as String,
        sport: json['sport'] as String,
        champion: json['champion'] as String,
        color: (json['color'] as num?)?.toInt() ?? 0,
        runnerUp: json['runnerUp'] as String?,
        teams: (json['teams'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        atMillis: (json['atMillis'] as num?)?.toInt() ?? 0,
      );
}

class TournamentProvider extends ChangeNotifier {
  static const _key = 'bm_tournament';
  static const _historyKey = 'bm_history';

  Tournament? event;
  List<PastChampion> history = [];

  Future<void> init() async {
    final raw = await StorageService.instance.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        event = Tournament.decode(raw);
      } catch (error) {
        debugPrint('drop saved tournament: $error');
        await StorageService.instance.remove(_key);
      }
    }
    final saved = await StorageService.instance.getString(_historyKey);
    if (saved == null || saved.isEmpty) return;
    try {
      history = (jsonDecode(saved) as List)
          .map((item) =>
              PastChampion.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (error) {
      debugPrint('drop champion history: $error');
    }
  }

  Future<void> create({
    required String name,
    required Sport sport,
    required List<Team> teams,
    required int startMinutes,
  }) async {
    event = BracketEngine.build(
      name: name,
      sport: sport,
      teams: teams,
      startMinutes: startMinutes,
    );
    notifyListeners();
    await _save();
  }

  String? record(String matchId, int scoreA, int scoreB) {
    final current = event;
    if (current == null) return 'No tournament yet.';
    final error = BracketEngine.record(current, matchId, scoreA, scoreB);
    if (error != null) return error;
    notifyListeners();
    _save();
    if (current.champion != null) remember(current);
    return null;
  }

  /// Keeps the latest champion for this tournament. Safe to call again.
  Future<void> remember(Tournament source) async {
    final winner = source.champion;
    if (winner == null) return;
    history.removeWhere((item) => item.tournamentId == source.id);
    history.insert(
      0,
      PastChampion(
        tournamentId: source.id,
        tournamentName: source.name,
        sport: source.sport.label,
        champion: winner.name,
        color: winner.color,
        runnerUp: source.runnerUp?.name,
        teams: source.teams.length,
        wins: source.winsOf(winner.id),
        atMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (history.length > 24) {
      history = history.sublist(0, 24);
    }
    await StorageService.instance.saveString(
      _historyKey,
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Same clubs, a new shuffled draw. The finished champion stays in the hall.
  Future<void> rematch() async {
    final current = event;
    if (current == null || current.champion == null) return;
    await remember(current);
    final teams = List<Team>.of(current.teams)..shuffle(Random());
    await create(
      name: current.name,
      sport: current.sport,
      teams: teams,
      startMinutes: current.startMinutes,
    );
  }

  Future<void> adopt(Tournament tournament) async {
    event = tournament;
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    event = null;
    await StorageService.instance.remove(_key);
    notifyListeners();
  }

  Future<void> _save() async {
    final current = event;
    if (current == null) {
      await StorageService.instance.remove(_key);
      return;
    }
    await StorageService.instance.saveString(_key, current.encode());
  }
}
