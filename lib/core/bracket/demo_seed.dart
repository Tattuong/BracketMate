import 'bracket_engine.dart';

class DemoSeed {
  DemoSeed._();

  static const name = 'Sunday Badminton';

  static const formTeams = <Team>[
    Team(id: 'falcons', name: 'Falcons', color: 0),
    Team(id: 'nova', name: 'Nova', color: 1),
    Team(id: 'phoenix', name: 'Phoenix', color: 2),
    Team(id: 'eagles', name: 'Eagles', color: 4),
    Team(id: 'hawks', name: 'Hawks', color: 5),
    Team(id: 'lions', name: 'Lions', color: 6),
    Team(id: 'tigers', name: 'Tigers', color: 3),
  ];

  /// Quarters are done. Semifinals are Falcons–Nova and Phoenix–Tigers.
  static Tournament semis() {
    final event = BracketEngine.build(
      name: name,
      sport: Sport.badminton,
      startMinutes: 9 * 60 + 30,
      teams: const [
        Team(id: 'falcons', name: 'Falcons', color: 0),
        Team(id: 'eagles', name: 'Eagles', color: 4),
        Team(id: 'nova', name: 'Nova', color: 1),
        Team(id: 'hawks', name: 'Hawks', color: 5),
        Team(id: 'phoenix', name: 'Phoenix', color: 2),
        Team(id: 'lions', name: 'Lions', color: 6),
        Team(id: 'tigers', name: 'Tigers', color: 3),
      ],
    );
    final quarters = event.rounds.first.where((match) => !match.isBye).toList();
    BracketEngine.record(event, quarters[0].id, 2, 0);
    BracketEngine.record(event, quarters[1].id, 2, 0);
    BracketEngine.record(event, quarters[2].id, 2, 1);
    return event;
  }

  /// Photo of the finished Sunday Badminton final. Does not touch [source].
  static Tournament finish(Tournament source) {
    final event = Tournament.decode(source.encode());
    final semis = event.rounds[1];
    BracketEngine.record(event, semis[0].id, 2, 0);
    BracketEngine.record(event, semis[1].id, 2, 1);
    BracketEngine.record(event, event.finalMatch.id, 2, 1);
    return event;
  }
}
