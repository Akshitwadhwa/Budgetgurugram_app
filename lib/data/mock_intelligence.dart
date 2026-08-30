import '../models/event_intelligence.dart';
import '../models/event_item.dart';

/// Stand-in intelligence until the backend ships.
///
/// Two rules kept this honest:
///
/// * **Deterministic.** Derived from a stable hash of the title, not
///   `Random()`, so a demo shows the same thing twice and screenshots match.
/// * **Every band represented.** Roughly a third of events land in each of
///   likely / possibly / unclear, because a demo that only ever shows the
///   confident state hides the design decisions that matter most.
///
/// Swap this for `ApiClient.eventDetail()` — the widget layer takes
/// [EventVerdict] and never learns where it came from.
abstract final class MockIntelligence {
  /// Stable across runs and platforms, unlike `String.hashCode`.
  static int _hash(String s) {
    var h = 7;
    for (final unit in s.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }

  static EventVerdict? verdictFor(EventItem event) {
    final h = _hash(event.title);

    // One event in nine has no verdict at all — the "not analysed yet" state
    // has to be visible in the demo, because it will be common in week one.
    if (h % 9 == 0) return null;

    final bucket = h % 3;
    final hay = '${event.title} ${event.description}'.toLowerCase();

    final looksHandsOn = RegExp(r'workshop|build|hack|hands|lab|bootcamp')
        .hasMatch(hay);
    final looksSocial = RegExp(r'mixer|social|meetup|networking|brunch|run')
        .hasMatch(hay);

    return switch (bucket) {
      0 => _strong(event, looksHandsOn),
      1 => _mixed(event, looksSocial),
      _ => _thin(event),
    };
  }

  // ── Strong signal: the flagship case ───────────────────────────────────
  //
  // The listing says "meetup", the history says workshop. This is the exact
  // scenario the product was specified around.
  static EventVerdict _strong(EventItem event, bool handsOn) {
    return EventVerdict(
      trueFormat: handsOn ? EventFormat.workshop : EventFormat.talk,
      confidence: 0.86,
      listedAs: 'Meetup',
      level: 'Intermediate',
      handsOn: handsOn,
      expect: handsOn
          ? 'Despite the listing, the last three editions ran as build '
              'sessions — a short intro, then roughly two hours of hands-on '
              'work. Bring a laptop, and expect to leave with something '
              'running.'
          : 'Two speakers, around 25 minutes each, followed by open Q&A. '
              'Seating is limited and the room fills before the start time.',
      whoShouldCome: handsOn
          ? const ['Engineers who want to build, not just listen', 'Anyone comfortable with a terminal']
          : const ['People scoping the space', 'Anyone who prefers to listen first'],
      prepNeeded: handsOn ? 'Laptop, and an account set up before you arrive.' : null,
      watchOuts: const ['Starts 20–30 minutes late, consistently.'],
      evidence: [
        Evidence(
          claim: 'The last three editions were run as hands-on sessions.',
          sourceUrl: event.url.isEmpty ? 'https://lu.ma' : event.url,
          sourceTitle: 'Past editions of this series',
          quote: 'Bring your laptop — we will be building together for '
              'most of the session.',
        ),
        const Evidence(
          claim: 'The organiser describes their events as workshops.',
          sourceUrl: 'https://lu.ma/discover',
          sourceTitle: 'Organiser profile',
          quote: 'We run practical, build-along sessions for people who '
              'learn by doing.',
        ),
        const Evidence(
          claim: 'Attendees report a late start.',
          sourceUrl: 'https://www.meetup.com',
          sourceTitle: 'Attendee comments, previous edition',
          quote: 'Good session but it kicked off nearly half an hour after '
              'the listed time.',
        ),
      ],
    );
  }

  // ── Mixed signal ───────────────────────────────────────────────────────
  static EventVerdict _mixed(EventItem event, bool social) {
    return EventVerdict(
      trueFormat: social ? EventFormat.networking : EventFormat.panel,
      confidence: 0.61,
      listedAs: social ? 'Workshop' : 'Meetup',
      level: 'Mixed',
      handsOn: false,
      expect: social
          ? 'Billed as a workshop, but the format looks closer to structured '
              'networking — a short opening, then open conversation. Sources '
              'disagree on whether there is a session at all.'
          : 'Likely a moderated discussion rather than a talk. One source '
              'mentions a panel; the listing does not.',
      whoShouldCome: const ['People who want to meet others in the space'],
      watchOuts: const [
        'Sources disagree on the format — treat this reading as provisional.',
      ],
      evidence: [
        Evidence(
          claim: 'The listing and the organiser’s site describe different formats.',
          sourceUrl: event.url.isEmpty ? 'https://lu.ma' : event.url,
          sourceTitle: 'Event listing',
          quote: 'Join us for an evening of conversation and ideas.',
        ),
        const Evidence(
          claim: 'A previous edition was run as open networking.',
          sourceUrl: 'https://www.meetup.com',
          sourceTitle: 'Previous edition',
          quote: 'Mostly mingling — there was no formal session this time.',
        ),
      ],
    );
  }

  // ── Thin signal: the honest shrug ──────────────────────────────────────
  static EventVerdict _thin(EventItem event) {
    return EventVerdict(
      trueFormat: EventFormat.unclear,
      confidence: 0.31,
      listedAs: null,
      expect: 'We could only find the listing itself. There is no history for '
          'this organiser yet and nothing else on the web about it.',
      watchOuts: const ['First edition we have seen from this organiser.'],
      evidence: [
        Evidence(
          claim: 'Only the original listing was found.',
          sourceUrl: event.url.isEmpty ? 'https://lu.ma' : event.url,
          sourceTitle: 'Event listing',
          quote: null,
        ),
      ],
    );
  }

  static EventSeries? seriesFor(EventItem event) {
    final h = _hash(event.title);
    if (h % 3 == 2) return null; // thin-signal events have no history

    final editions = 3 + (h % 8);
    final base = DateTime.now();
    return EventSeries(
      id: 'series-${h % 9999}',
      canonicalTitle: event.title,
      organizerName: event.source,
      editionsCount: editions,
      cadence: h.isEven ? 'monthly' : 'every few weeks',
      typicalAttendance: 20 + (h % 60),
      pastEditions: List.generate(
        editions.clamp(1, 4),
        (i) => PastEdition(
          id: 'past-$i',
          title: event.title,
          startedAt: base.subtract(Duration(days: 30 * (i + 1))),
          url: event.url.isEmpty ? null : event.url,
          observedFormat: i.isEven ? 'Workshop' : 'Talk',
          attendance: 18 + ((h + i * 7) % 55),
        ),
      ),
    );
  }

  /// Cheap stand-in for vector similarity: same source, nearest in time.
  static List<EventItem> similarTo(EventItem event, List<EventItem> pool) {
    final others = pool.where((e) => e.id != event.id).toList()
      ..sort((a, b) {
        final sameA = a.source == event.source ? 0 : 1;
        final sameB = b.source == event.source ? 0 : 1;
        if (sameA != sameB) return sameA.compareTo(sameB);
        return a.start.compareTo(b.start);
      });
    return others.take(4).toList();
  }

  /// Canned answers for the Ask sheet.
  ///
  /// The refusal path is wired first and deliberately: an unmatched question
  /// returns [QaMessage.refused], never an invented answer.
  static QaMessage answer(String question, EventItem event, EventVerdict? v) {
    final q = question.toLowerCase();

    if (v == null) {
      return QaMessage(
        question: question,
        refused: true,
        answer: 'We have not analysed this event yet, so there is nothing '
            'here I can answer from. The organiser’s listing is the only '
            'source we have.',
      );
    }

    if (RegExp(r'beginner|new|first time|experience').hasMatch(q)) {
      return QaMessage(
        question: question,
        answer: v.level == 'Intermediate'
            ? 'Probably not ideal as a first event. Past editions assumed '
                'people were already comfortable with the tools, and the '
                'session moves quickly.'
            : 'Likely fine for a first event — past editions have drawn a '
                'mixed room.',
        citations: v.evidence.take(2).toList(),
      );
    }

    if (RegExp(r'bring|laptop|prepare|need').hasMatch(q)) {
      return QaMessage(
        question: question,
        answer: v.prepNeeded ??
            'Nothing specific mentioned in any source we found. If it is a '
                'hands-on session a laptop is a safe bet.',
        citations: v.evidence.take(1).toList(),
      );
    }

    if (RegExp(r'workshop|format|talk|really|actually').hasMatch(q)) {
      return QaMessage(
        question: question,
        answer: '${v.headline}. ${v.expect}',
        citations: v.evidence,
      );
    }

    // Everything else refuses. Refusing is the correct default.
    return QaMessage(
      question: question,
      refused: true,
      answer: 'I do not have anything sourced on that. I can only answer from '
          'this event’s listing, its past editions, and what the organiser '
          'has published.',
    );
  }
}
