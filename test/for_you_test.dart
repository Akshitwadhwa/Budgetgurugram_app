import 'package:budget_gurugram/core/for_you.dart';
import 'package:budget_gurugram/models/event_intelligence.dart';
import 'package:budget_gurugram/models/event_item.dart';
import 'package:budget_gurugram/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final event = EventItem(
    id: '1',
    title: 'AI workshop for founders',
    start: DateTime.now().add(const Duration(hours: 5)),
    description: 'Bring a laptop. We will build agents.',
    location: 'Cyber Hub, DLF Phase 3, Gurugram',
    lat: 28.4952,
    lng: 77.0894,
    geocoded: 'exact',
  );

  final verdict = EventVerdict(
    trueFormat: EventFormat.workshop,
    confidence: 0.86,
    expect: 'You will build, not listen.',
    evidence: const [
      Evidence(claim: 'c', sourceUrl: 'https://lu.ma/x', sourceTitle: 't'),
    ],
    handsOn: true,
  );

  test('silent when the profile has no signal', () {
    expect(
      forYouLine(
        profile: const UserProfile(motives: ['explore']),
        event: EventItem(
          id: '2',
          title: 'Untitled gathering',
          start: DateTime.now().add(const Duration(days: 10)),
        ),
      ),
      isNull,
    );
  });

  test('names the role when the event matches', () {
    final line = forYouLine(
      profile: const UserProfile(
        motives: ['events'],
        role: 'Startup founder',
        neighbourhood: 'Cyber City',
      ),
      event: event,
      verdict: verdict,
    );
    expect(line, isNotNull);
    expect(line, contains('Startup founder'));
    expect(line!.toLowerCase(), contains('build'));
  });

  test('does not invent a crowd-related reason', () {
    final line = forYouLine(
      profile: const UserProfile(motives: ['events'], role: 'Visitor'),
      event: EventItem(
        id: '3',
        title: 'Community picnic',
        start: DateTime.now().add(const Duration(days: 4)),
      ),
    );
    expect(line, isNotNull);
    expect(line!.toLowerCase(), isNot(contains('people going')));
  });
}
