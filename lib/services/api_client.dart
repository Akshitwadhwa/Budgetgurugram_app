import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/event_intelligence.dart';
import '../models/event_item.dart';
import 'api_config.dart';
import 'device_service.dart';

/// Raised when the backend is reachable but unhappy. Network failures throw the
/// underlying `SocketException`/`TimeoutException` instead, so callers can tell
/// "server said no" apart from "no server" — they need different UI.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Everything `/v1/events/{id}` returns, in one object.
class EventDetail {
  const EventDetail({
    required this.event,
    this.verdict,
    this.series,
    this.pastEditions = const [],
    this.similar = const [],
  });

  final EventItem event;
  final EventVerdict? verdict;
  final EventSeries? series;
  final List<PastEdition> pastEditions;
  final List<SimilarEvent> similar;
}

class SimilarEvent {
  const SimilarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.score,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final double score;
}

/// The single HTTP chokepoint.
///
/// Every request goes through here so the device header, timeouts, and error
/// translation exist in exactly one place. No widget ever calls `http` itself.
class ApiClient {
  ApiClient({DeviceService? devices, http.Client? client})
      : _devices = devices ?? DeviceService(),
        _http = client ?? http.Client();

  final DeviceService _devices;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

  Future<Map<String, String>> _headers() async => {
        'X-Device-Id': await _devices.deviceId(),
        'Content-Type': 'application/json',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      String message = 'Request failed';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {
        // Non-JSON error body; the status code is the useful part.
      }
      throw ApiException(response.statusCode, message);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<EventItem>> events({String filter = 'all', int limit = 100}) async {
    final response = await _http
        .get(
          _uri(ApiConfig.eventsPath, {
            'limit': '$limit',
            if (filter != 'all' && filter != 'best') 'filter': filter,
          }),
          headers: await _headers(),
        )
        .timeout(_timeout);

    final payload = _decode(response);
    final list = payload['events'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => EventItem.fromApi(Map<String, dynamic>.from(e)))
        .where((e) => e.isUpcoming)
        .toList();
  }

  Future<EventDetail> eventDetail(String id) async {
    final response = await _http
        .get(_uri(ApiConfig.eventDetailPath(id)), headers: await _headers())
        .timeout(_timeout);
    final payload = _decode(response);

    final rawEvent = Map<String, dynamic>.from(payload['event'] as Map);
    final rawVerdict = payload['verdict'];
    final rawSeries = payload['series'];

    final editions = ((payload['pastEditions'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => PastEdition(
              id: e['id']?.toString() ?? '',
              title: e['title']?.toString() ?? '',
              startedAt:
                  DateTime.tryParse(e['startsAt']?.toString() ?? '') ?? DateTime.now(),
              url: e['url']?.toString(),
            ))
        .toList();

    EventSeries? series;
    if (rawSeries is Map) {
      series = EventSeries(
        id: rawSeries['id']?.toString() ?? '',
        canonicalTitle: rawSeries['canonicalTitle']?.toString() ?? '',
        editionsCount: (rawSeries['editionsCount'] as num?)?.toInt() ?? 0,
        cadence: rawSeries['cadence']?.toString(),
        pastEditions: editions,
      );
    }

    return EventDetail(
      event: EventItem.fromApi(rawEvent),
      verdict: rawVerdict is Map
          ? EventVerdict.fromApi(Map<String, dynamic>.from(rawVerdict))
          : null,
      series: series,
      pastEditions: editions,
      similar: ((payload['similar'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => SimilarEvent(
                id: e['id']?.toString() ?? '',
                title: e['title']?.toString() ?? '',
                startsAt: DateTime.tryParse(e['startsAt']?.toString() ?? '') ??
                    DateTime.now(),
                score: (e['score'] as num?)?.toDouble() ?? 0,
              ))
          .toList(),
    );
  }

  Future<QaMessage> ask(String eventId, String question) async {
    final response = await _http
        .post(
          _uri(ApiConfig.askPath(eventId)),
          headers: await _headers(),
          body: jsonEncode({'question': question}),
        )
        .timeout(const Duration(seconds: 45));

    final payload = _decode(response);
    return QaMessage(
      question: question,
      answer: payload['answer']?.toString(),
      refused: payload['refused'] == true,
      citations: ((payload['citations'] as List?) ?? const [])
          .whereType<Map>()
          .map((c) => Evidence(
                claim: '',
                sourceUrl: c['sourceUrl']?.toString() ?? '',
                sourceTitle: c['sourceTitle']?.toString() ?? 'Source',
                quote: c['quote']?.toString(),
              ))
          .toList(),
    );
  }

  Future<bool> healthy() async {
    try {
      final response = await _http
          .get(_uri(ApiConfig.healthPath), headers: await _headers())
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
