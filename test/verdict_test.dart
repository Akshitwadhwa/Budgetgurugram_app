import 'package:budget_gurugram/models/event_intelligence.dart';
import 'package:budget_gurugram/theme/app_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests guard the trust model, not the pixels.
///
/// The product's central risk is a confident wrong answer, so the rules that
/// bind *language* to *confidence* are treated as invariants: if someone later
/// changes a threshold or a headline string, this file should fail.
void main() {
  Evidence anySource() => const Evidence(
        claim: 'c',
        sourceUrl: 'https://lu.ma/x',
        sourceTitle: 't',
      );

  EventVerdict verdictAt(double confidence) => EventVerdict(
        trueFormat: EventFormat.workshop,
        confidence: confidence,
        expect: '',
        evidence: [anySource()],
      );

  group('confidence bands', () {
    test('boundaries land in the right band', () {
      expect(ConfidenceBand.fromScore(0.75), ConfidenceBand.likely);
      expect(ConfidenceBand.fromScore(0.74), ConfidenceBand.possibly);
      expect(ConfidenceBand.fromScore(0.50), ConfidenceBand.possibly);
      expect(ConfidenceBand.fromScore(0.49), ConfidenceBand.unclear);
    });

    test('1.0 and 0.0 do not fall through', () {
      expect(ConfidenceBand.fromScore(1), ConfidenceBand.likely);
      expect(ConfidenceBand.fromScore(0), ConfidenceBand.unclear);
    });
  });

  group('headline language is bound to confidence', () {
    test('high confidence still hedges — never a bare assertion', () {
      final headline = verdictAt(0.92).headline;
      expect(headline, contains('Likely'));
      expect(headline, isNot(contains('Definitely')));
    });

    test('mid confidence is visibly tentative', () {
      expect(verdictAt(0.6).headline, contains('Possibly'));
    });

    test('low confidence never names a format as fact', () {
      final v = verdictAt(0.2);
      expect(v.headline, 'Format unclear');
      expect(v.headline.toLowerCase(), isNot(contains('workshop')));
    });

    test('low confidence subline tells the user what to do instead', () {
      expect(verdictAt(0.2).subline, contains('asking the organiser'));
    });
  });

  group('evidence invariant', () {
    test('a verdict cannot be constructed without evidence', () {
      expect(
        () => EventVerdict(
          trueFormat: EventFormat.talk,
          confidence: 0.9,
          expect: '',
          evidence: const [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('listing contradiction', () {
    test('flags the case the product exists for', () {
      final v = EventVerdict(
        trueFormat: EventFormat.workshop,
        confidence: 0.86,
        listedAs: 'Meetup',
        expect: '',
        evidence: [anySource()],
      );
      expect(v.contradictsListing, isTrue);
    });

    test('does not flag agreement', () {
      final v = EventVerdict(
        trueFormat: EventFormat.workshop,
        confidence: 0.86,
        listedAs: 'Workshop',
        expect: '',
        evidence: [anySource()],
      );
      expect(v.contradictsListing, isFalse);
    });

    test('never claims a contradiction when the format is unclear', () {
      final v = EventVerdict(
        trueFormat: EventFormat.unclear,
        confidence: 0.3,
        listedAs: 'Meetup',
        expect: '',
        evidence: [anySource()],
      );
      expect(v.contradictsListing, isFalse);
    });
  });

  group('evidence source attribution', () {
    test('host strips www for the mono attribution line', () {
      const e = Evidence(
        claim: 'c',
        sourceUrl: 'https://www.meetup.com/some-group/events/123',
        sourceTitle: 't',
      );
      expect(e.host, 'meetup.com');
    });

    test('a malformed url degrades instead of throwing', () {
      const e = Evidence(claim: 'c', sourceUrl: '', sourceTitle: 't');
      expect(() => e.host, returnsNormally);
    });
  });
}
