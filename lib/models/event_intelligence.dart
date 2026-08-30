import '../theme/app_palette.dart';

/// One sourced claim. The atom of the trust model.
///
/// There is no constructor path that produces an [Evidence] without a
/// [sourceUrl]; an unsourced claim is not representable in this app.
class Evidence {
  const Evidence({
    required this.claim,
    required this.sourceUrl,
    required this.sourceTitle,
    this.quote,
  });

  final String claim;
  final String sourceUrl;
  final String sourceTitle;

  /// Verbatim text from the source. Rendered as a serif quotation so it is
  /// visibly someone else's words.
  final String? quote;

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        claim: json['claim']?.toString() ?? '',
        sourceUrl: json['sourceUrl']?.toString() ?? '',
        sourceTitle: json['sourceTitle']?.toString() ?? 'Source',
        quote: json['quote']?.toString(),
      );

  /// Bare domain, for the mono attribution line.
  String get host {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null) return 'source';
    return uri.host.replaceFirst(RegExp(r'^www\.'), '');
  }
}

enum EventFormat {
  workshop('Workshop', 'hands-on, bring a laptop'),
  talk('Talk', 'someone presents, you listen'),
  panel('Panel', 'a moderated discussion'),
  networking('Networking', 'mostly conversation'),
  hackathon('Hackathon', 'you build, for hours'),
  demoDay('Demo day', 'teams present work'),
  social('Social', 'informal, no agenda'),
  conference('Conference', 'multi-track, full day'),
  unclear('Unclear', 'not enough signal');

  const EventFormat(this.label, this.hint);
  final String label;

  /// A plain-language gloss. Format names are jargon to half the audience;
  /// this is what actually stops someone showing up to the wrong thing.
  final String hint;

  static EventFormat parse(String? raw) => switch (raw) {
        'workshop' => workshop,
        'talk' => talk,
        'panel' => panel,
        'networking' => networking,
        'hackathon' => hackathon,
        'demo_day' => demoDay,
        'social' => social,
        'conference' => conference,
        _ => unclear,
      };
}

/// The verdict: what this event *actually* is, and how sure we are.
class EventVerdict {
  const EventVerdict({
    required this.trueFormat,
    required this.confidence,
    required this.expect,
    required this.evidence,
    this.listedAs,
    this.level,
    this.handsOn,
    this.whoShouldCome = const [],
    this.prepNeeded,
    this.watchOuts = const [],
  }) : assert(evidence.length > 0, 'A verdict cannot exist without evidence.');

  final EventFormat trueFormat;
  final double confidence;

  /// What the listing calls itself. The whole product is the gap between this
  /// and [trueFormat], so it is a first-class field, not a footnote.
  final String? listedAs;

  final String expect;
  final String? level;
  final bool? handsOn;
  final List<String> whoShouldCome;
  final String? prepNeeded;
  final List<String> watchOuts;
  final List<Evidence> evidence;

  ConfidenceBand get band => ConfidenceBand.fromScore(confidence);

  /// True when the listing's own framing disagrees with our reading — the
  /// "Claude Meetup Delhi is really a workshop" case this product exists for.
  bool get contradictsListing {
    final listed = listedAs?.toLowerCase().trim();
    if (listed == null || listed.isEmpty) return false;
    if (trueFormat == EventFormat.unclear) return false;
    return listed != trueFormat.label.toLowerCase();
  }

  /// Headline copy. Language is bound to confidence here, in one place, so no
  /// screen can accidentally render an unhedged claim.
  String get headline => switch (band) {
        ConfidenceBand.likely => 'Likely a ${trueFormat.label.toLowerCase()}',
        ConfidenceBand.possibly =>
          'Possibly a ${trueFormat.label.toLowerCase()}',
        ConfidenceBand.unclear => 'Format unclear',
      };

  /// Sub-line. In the unclear band this is deliberately an instruction to the
  /// user rather than a statement about the event.
  String get subline => switch (band) {
        ConfidenceBand.unclear => 'Worth asking the organiser before you go',
        _ => trueFormat.hint,
      };

  /// Maps `/v1/events/{id}`'s `verdict` object.
  ///
  /// The backend's `VerdictOut` does not yet carry `listedAs`, so the
  /// "listed as X → actually Y" contrast degrades to a plain verdict until it
  /// does. [contradictsListing] returns false for a null listing, so nothing
  /// misrenders in the meantime.
  factory EventVerdict.fromApi(Map<String, dynamic> json) =>
      EventVerdict.fromJson(json);

  factory EventVerdict.fromJson(Map<String, dynamic> json) {
    final rawEvidence = (json['evidence'] as List?) ?? const [];
    return EventVerdict(
      trueFormat: EventFormat.parse(json['trueFormat']?.toString()),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      listedAs: json['listedAs']?.toString(),
      expect: json['expect']?.toString() ?? '',
      level: json['level']?.toString(),
      handsOn: json['handsOn'] as bool?,
      whoShouldCome:
          ((json['whoShouldCome'] as List?) ?? const []).map((e) => e.toString()).toList(),
      prepNeeded: json['prepNeeded']?.toString(),
      watchOuts:
          ((json['watchOuts'] as List?) ?? const []).map((e) => e.toString()).toList(),
      evidence: rawEvidence
          .whereType<Map>()
          .map((e) => Evidence.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// A recurring event identity and its observed history.
class EventSeries {
  const EventSeries({
    required this.id,
    required this.canonicalTitle,
    required this.editionsCount,
    this.cadence,
    this.organizerName,
    this.typicalAttendance,
    this.pastEditions = const [],
  });

  final String id;
  final String canonicalTitle;
  final int editionsCount;
  final String? cadence;
  final String? organizerName;
  final int? typicalAttendance;
  final List<PastEdition> pastEditions;

  bool get hasHistory => pastEditions.isNotEmpty;

  /// "Run 9 times · usually monthly" — the sentence that only we can write,
  /// because only we kept the history.
  String get historyLine {
    final times = editionsCount == 1 ? 'Run once' : 'Run $editionsCount times';
    return cadence == null ? times : '$times · usually $cadence';
  }
}

class PastEdition {
  const PastEdition({
    required this.id,
    required this.title,
    required this.startedAt,
    this.url,
    this.observedFormat,
    this.attendance,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final String? url;
  final String? observedFormat;
  final int? attendance;
}

/// One turn in the Ask thread.
class QaMessage {
  const QaMessage({
    required this.question,
    this.answer,
    this.citations = const [],
    this.refused = false,
    this.pending = false,
  });

  final String question;
  final String? answer;
  final List<Evidence> citations;

  /// True when retrieval found nothing. Rendered as a deliberate answer, never
  /// as an error — refusing is correct behaviour here.
  final bool refused;
  final bool pending;
}
