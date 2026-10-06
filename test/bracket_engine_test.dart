import 'package:bracketmate/core/bracket/bracket_engine.dart';
import 'package:bracketmate/core/bracket/demo_seed.dart';
import 'package:bracketmate/screens/setup_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Team team(int index) => Team(id: 't$index', name: 'Team $index', color: index);

Tournament build(int count) => BracketEngine.build(
      name: 'Sunday',
      sport: Sport.badminton,
      teams: [for (var i = 0; i < count; i++) team(i)],
      startMinutes: 9 * 60,
    );

void main() {
  test('two teams is a single final and no bye', () {
    final event = build(2);
    expect(event.rounds, hasLength(1));
    expect(event.byeCount, 0);
    expect(event.realMatches, hasLength(1));
    expect(event.rounds.first.first.phase, MatchPhase.ready);
  });

  test('seven teams get one bye and six real matches', () {
    final event = build(7);
    expect(event.byeCount, 1);
    expect(event.realMatches, hasLength(6));
    expect(event.rounds, hasLength(3));
    expect(event.rounds.first.where((match) => match.phase == MatchPhase.bye),
        hasLength(1));
    final bye = event.rounds.first.firstWhere((match) => match.isBye);
    final advanced = event.rounds[1].expand((match) => [match.aId, match.bId]);
    expect(advanced, contains(bye.winnerId));
    expect(event.shareSchedule(), contains('bye'));
  });

  test('byes are never paired with each other', () {
    for (var count = 2; count <= 32; count++) {
      final event = build(count);
      expect(event.realMatches, hasLength(count - 1), reason: 'teams=$count');
      expect(event.byeCount, BracketEngine.nextPow2(count) - count);
      for (final match in event.rounds.first) {
        expect(match.aId == null && match.bId == null, isFalse,
            reason: 'teams=$count');
        if (match.isBye) {
          expect(match.winnerId, isNotNull);
          expect(match.bId, isNull);
        }
      }
    }
  });

  test('a result advances the winner and a tie is rejected', () {
    final event = build(4);
    final first = event.rounds.first.first;
    expect(BracketEngine.record(event, first.id, 1, 1), isNotNull);
    expect(first.winnerId, isNull);
    expect(BracketEngine.record(event, first.id, 2, 0), isNull);
    final next = event.rounds[1].first;
    expect(next.aId, first.aId);
    expect(next.phase, MatchPhase.waiting);
  });

  test('playing every match leaves one champion', () {
    final event = build(7);
    var guard = 0;
    while (event.champion == null && guard < 20) {
      guard += 1;
      final ready = event.realMatches
          .where((match) => match.phase == MatchPhase.ready)
          .toList();
      expect(ready, isNotEmpty);
      for (final match in ready) {
        expect(BracketEngine.record(event, match.id, 2, 1), isNull);
      }
    }
    expect(event.champion, isNotNull);
    expect(event.playedCount, 6);
    expect(event.runnerUp, isNotNull);
    expect(event.winsOf(event.champion!.id), greaterThan(0));
  });

  test('a finished downstream match blocks changing the winner', () {
    final event = build(4);
    final opening = event.rounds.first;
    BracketEngine.record(event, opening[0].id, 2, 0);
    BracketEngine.record(event, opening[1].id, 2, 0);
    final finalMatch = event.rounds.last.first;
    expect(finalMatch.phase, MatchPhase.ready);
    BracketEngine.record(event, finalMatch.id, 2, 1);
    expect(BracketEngine.record(event, opening[0].id, 0, 2), isNotNull);
    expect(opening[0].winnerId, opening[0].aId);
  });

  test('the sunday demo matches the photo bracket', () {
    final event = DemoSeed.semis();
    expect(event.playedCount, 3);
    expect(event.realMatches, hasLength(6));
    expect(event.byeCount, 1);
    final semis = event.rounds[1];
    expect(event.teamOf(semis[0].aId)?.name, 'Falcons');
    expect(event.teamOf(semis[0].bId)?.name, 'Nova');
    expect(event.teamOf(semis[1].aId)?.name, 'Phoenix');
    expect(event.teamOf(semis[1].bId)?.name, 'Tigers');
    expect(event.slotLabel(semis[0]), 'Court 1 · 09:30');
    expect(event.slotLabel(semis[1]), 'Court 2 · 10:00');
    final done = DemoSeed.finish(event);
    expect(event.champion, isNull);
    expect(done.champion?.name, 'Falcons');
    expect(done.runnerUp?.name, 'Phoenix');
    expect(done.finalMatch.scoreA, 2);
    expect(done.finalMatch.scoreB, 1);
    expect(done.winsOf(done.champion!.id), 3);
  });

  test('a shared final keeps each score with the team that scored it', () {
    final event = build(2);
    final match = event.finalMatch;
    expect(BracketEngine.record(event, match.id, 1, 2), isNull);
    expect(event.champion?.id, match.bId);
    expect(event.shareResult(), contains('Team 0 1-2 Team 1'));
  });

  test('create reopens only an unchanged draw', () {
    final saved = build(2);
    expect(
      reopenSavedBracket(
        saved: saved,
        name: 'Sunday',
        sport: Sport.badminton,
        startMinutes: 9 * 60,
        teamNames: ['Team 0', 'Team 1'],
      ),
      isTrue,
    );
    expect(
      reopenSavedBracket(
        saved: saved,
        name: 'Sunday',
        sport: Sport.football,
        startMinutes: 9 * 60,
        teamNames: ['Team 0', 'Team 1'],
      ),
      isFalse,
    );
    expect(
      reopenSavedBracket(
        saved: saved,
        name: 'Sunday',
        sport: Sport.badminton,
        startMinutes: 9 * 60,
        teamNames: ['Team 1', 'Team 0'],
      ),
      isFalse,
    );
    final photo = DemoSeed.semis();
    expect(
      reopenSavedBracket(
        saved: photo,
        name: DemoSeed.name,
        sport: Sport.badminton,
        startMinutes: 9 * 60 + 30,
        teamNames: DemoSeed.formTeams.map((team) => team.name).toList(),
      ),
      isTrue,
    );
    expect(
      reopenSavedBracket(
        saved: photo,
        name: DemoSeed.name,
        sport: Sport.basketball,
        startMinutes: 9 * 60 + 30,
        teamNames: DemoSeed.formTeams.map((team) => team.name).toList(),
      ),
      isFalse,
    );
  });

  test('the saved bracket round-trips', () {
    final event = build(5);
    final again = Tournament.decode(event.encode());
    expect(again.teams, hasLength(5));
    expect(again.byeCount, event.byeCount);
    expect(again.rounds.length, event.rounds.length);
    expect(again.rounds[1].first.aId, event.rounds[1].first.aId);
  });
}
