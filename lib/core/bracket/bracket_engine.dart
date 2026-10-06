import 'dart:convert';
import 'dart:math';

enum Sport { badminton, football, basketball, pickleball }

extension SportLabel on Sport {
  String get label => switch (this) {
        Sport.badminton => 'Badminton',
        Sport.football => 'Soccer',
        Sport.basketball => 'Basketball',
        Sport.pickleball => 'Pickleball',
      };
}

class Team {
  final String id;
  final String name;
  final int color;

  const Team({required this.id, required this.name, required this.color});

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        color: (json['color'] as num).toInt(),
      );
}

enum MatchPhase { bye, waiting, ready, done }

class BracketMatch {
  final String id;
  final int round;
  final int index;
  String? aId;
  String? bId;
  int? scoreA;
  int? scoreB;
  String? winnerId;
  final bool isBye;

  BracketMatch({
    required this.id,
    required this.round,
    required this.index,
    this.aId,
    this.bId,
    this.scoreA,
    this.scoreB,
    this.winnerId,
    this.isBye = false,
  });

  MatchPhase get phase {
    if (isBye) return MatchPhase.bye;
    if (winnerId != null) return MatchPhase.done;
    if (aId != null && bId != null) return MatchPhase.ready;
    return MatchPhase.waiting;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'round': round,
        'index': index,
        'aId': aId,
        'bId': bId,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'winnerId': winnerId,
        'isBye': isBye,
      };

  factory BracketMatch.fromJson(Map<String, dynamic> json) => BracketMatch(
        id: json['id'] as String,
        round: (json['round'] as num).toInt(),
        index: (json['index'] as num).toInt(),
        aId: json['aId'] as String?,
        bId: json['bId'] as String?,
        scoreA: (json['scoreA'] as num?)?.toInt(),
        scoreB: (json['scoreB'] as num?)?.toInt(),
        winnerId: json['winnerId'] as String?,
        isBye: json['isBye'] == true,
      );
}

class Tournament {
  final String id;
  final String name;
  final Sport sport;
  final int startMinutes;
  final List<Team> teams;
  final List<List<BracketMatch>> rounds;

  const Tournament({
    required this.id,
    required this.name,
    required this.sport,
    required this.startMinutes,
    required this.teams,
    required this.rounds,
  });

  Team? teamOf(String? id) {
    if (id == null) return null;
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  BracketMatch? matchById(String id) {
    for (final round in rounds) {
      for (final match in round) {
        if (match.id == id) return match;
      }
    }
    return null;
  }

  int get byeCount => rounds.first.where((match) => match.isBye).length;

  List<BracketMatch> get realMatches => [
        for (final round in rounds)
          for (final match in round)
            if (!match.isBye) match,
      ];

  int get playedCount =>
      realMatches.where((match) => match.winnerId != null).length;

  BracketMatch get finalMatch => rounds.last.first;

  Team? get champion => teamOf(finalMatch.winnerId);

  Team? get runnerUp {
    final winner = finalMatch.winnerId;
    if (winner == null) return null;
    final loserId = finalMatch.aId == winner ? finalMatch.bId : finalMatch.aId;
    return teamOf(loserId);
  }

  int winsOf(String teamId) =>
      realMatches.where((match) => match.winnerId == teamId).length;

  List<Team> byesInto(int round) {
    if (round <= 0) return const [];
    return [
      for (final match in rounds[round - 1])
        if (match.isBye) teamOf(match.winnerId),
    ].whereType<Team>().toList();
  }

  String slotLabel(BracketMatch match) {
    if (match.isBye) return '';
    final inRound = rounds[match.round].where((item) => !item.isBye).toList();
    final index = inRound.indexWhere((item) => item.id == match.id);
    if (index < 0) return '';
    final court = (index % 2) + 1;
    final minutes = startMinutes + index * 30;
    final hour = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return 'Court $court · $hh:$mm';
  }

  String roundName(int round) {
    final fromEnd = rounds.length - 1 - round;
    return switch (fromEnd) {
      0 => 'Final',
      1 => 'Semifinals',
      2 => 'Quarterfinals',
      3 => 'Round of 16',
      4 => 'Round of 32',
      _ => 'Round ${round + 1}',
    };
  }

  String shareSchedule() {
    final buffer = StringBuffer()
      ..writeln(name)
      ..writeln('${teams.length} teams · ${sport.label} · Single elimination')
      ..writeln();
    for (var r = 0; r < rounds.length; r++) {
      buffer.writeln(roundName(r).toUpperCase());
      for (final match in rounds[r]) {
        final a = teamOf(match.aId)?.name ?? 'Waiting';
        final b = teamOf(match.bId)?.name ?? 'Waiting';
        if (match.isBye) {
          buffer.writeln('• $a has a bye, straight to ${roundName(r + 1)}');
          continue;
        }
        final score =
            match.winnerId == null ? '' : '  ${match.scoreA}-${match.scoreB}';
        buffer.writeln('• $a vs $b$score  (${slotLabel(match)})');
      }
      final byes = byesInto(r);
      for (final team in byes) {
        buffer.writeln('• ${team.name} goes straight into this round');
      }
      buffer.writeln();
    }
    final winner = champion;
    if (winner != null) buffer.writeln('Champion: ${winner.name}');
    return buffer.toString().trim();
  }

  String shareResult() {
    final winner = champion;
    if (winner == null) return shareSchedule();
    final second = runnerUp;
    final buffer = StringBuffer()
      ..writeln(name)
      ..writeln('Champion: ${winner.name}')
      ..writeln('${winsOf(winner.id)} wins');
    if (second != null) {
      final home = teamOf(finalMatch.aId)?.name ?? '—';
      final away = teamOf(finalMatch.bId)?.name ?? '—';
      buffer.writeln(
          'Final: $home ${finalMatch.scoreA}-${finalMatch.scoreB} $away');
    }
    buffer
      ..writeln('${teams.length} teams · $playedCount matches · $byeCount byes')
      ..writeln()
      ..writeln(shareSchedule());
    return buffer.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sport': sport.name,
        'startMinutes': startMinutes,
        'teams': teams.map((team) => team.toJson()).toList(),
        'rounds': rounds
            .map((round) => round.map((match) => match.toJson()).toList())
            .toList(),
      };

  String encode() => jsonEncode(toJson());

  factory Tournament.decode(String raw) =>
      Tournament.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        id: json['id'] as String? ?? 'saved',
        name: json['name'] as String,
        sport: Sport.values.byName(json['sport'] as String),
        startMinutes: (json['startMinutes'] as num).toInt(),
        teams: (json['teams'] as List)
            .map((e) => Team.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rounds: (json['rounds'] as List)
            .map((round) => (round as List)
                .map((e) =>
                    BracketMatch.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList())
            .toList(),
      );
}

String _tournamentId() {
  final clock = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = Random().nextInt(0x7fffffff).toRadixString(16);
  return '$clock$salt';
}

class BracketEngine {
  BracketEngine._();

  static int nextPow2(int n) {
    var size = 1;
    while (size < n) {
      size <<= 1;
    }
    return size;
  }

  static Tournament build({
    required String name,
    required Sport sport,
    required List<Team> teams,
    required int startMinutes,
  }) {
    final count = teams.length;
    final size = nextPow2(count);
    final pairCount = size ~/ 2;
    final byeSlots = _byeSlots(size - count, pairCount);
    var cursor = 0;
    final first = <BracketMatch>[];
    for (var index = 0; index < pairCount; index++) {
      final bye = byeSlots.contains(index);
      final home = teams[cursor++];
      final away = bye ? null : teams[cursor++];
      first.add(BracketMatch(
        id: 'r0m$index',
        round: 0,
        index: index,
        aId: home.id,
        bId: away?.id,
        isBye: bye,
        winnerId: bye ? home.id : null,
      ));
    }
    final rounds = <List<BracketMatch>>[first];
    var matches = pairCount;
    var round = 0;
    while (matches > 1) {
      round += 1;
      matches ~/= 2;
      rounds.add([
        for (var index = 0; index < matches; index++)
          BracketMatch(id: 'r${round}m$index', round: round, index: index),
      ]);
    }
    final event = Tournament(
      id: _tournamentId(),
      name: name.trim(),
      sport: sport,
      startMinutes: startMinutes,
      teams: List<Team>.of(teams),
      rounds: rounds,
    );
    for (final match in first) {
      if (match.isBye) _placeWinner(event, match);
    }
    return event;
  }

  /// Returns an error message, or null when the result is stored.
  static String? record(
      Tournament event, String matchId, int scoreA, int scoreB) {
    final match = event.matchById(matchId);
    if (match == null || match.isBye) {
      return 'This match does not need a result.';
    }
    if (match.aId == null || match.bId == null) {
      return 'Both teams are not in yet.';
    }
    if (scoreA < 0 || scoreB < 0) return 'That score is not valid.';
    if (scoreA == scoreB) {
      return 'Single elimination has no draws. Enter a score with a winner.';
    }
    final winner = scoreA > scoreB ? match.aId : match.bId;
    if (match.winnerId != null &&
        match.winnerId != winner &&
        _nextLocked(event, match)) {
      return 'The next round already has a result. The winner cannot be changed.';
    }
    match.scoreA = scoreA;
    match.scoreB = scoreB;
    match.winnerId = winner;
    _placeWinner(event, match);
    return null;
  }

  static void _placeWinner(Tournament event, BracketMatch match) {
    if (match.winnerId == null) return;
    if (match.round + 1 >= event.rounds.length) return;
    final next = event.rounds[match.round + 1][match.index ~/ 2];
    if (match.index.isEven) {
      next.aId = match.winnerId;
    } else {
      next.bId = match.winnerId;
    }
  }

  static bool _nextLocked(Tournament event, BracketMatch match) {
    if (match.round + 1 >= event.rounds.length) return false;
    final next = event.rounds[match.round + 1][match.index ~/ 2];
    return next.winnerId != null && !next.isBye;
  }

  static Set<int> _byeSlots(int byes, int pairs) {
    final slots = <int>{};
    if (byes <= 0 || pairs <= 0) return slots;
    for (var bye = 0; bye < byes; bye++) {
      var index = pairs - 1 - (bye * pairs ~/ byes);
      while (!slots.add(index)) {
        index = (index - 1 + pairs) % pairs;
      }
    }
    return slots;
  }
}
