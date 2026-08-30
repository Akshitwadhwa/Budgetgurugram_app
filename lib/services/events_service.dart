import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_item.dart';
import 'api_client.dart';

/// Event loading, with a three-step degradation chain.
///
/// 1. **Live backend** — full experience, verdicts included.
/// 2. **Last good response**, cached on device — a cold start with no network
///    still shows the events you saw yesterday rather than a stale bundle.
/// 3. **Bundled `assets/data/events.json`** — the floor. The app is never empty.
///
/// [lastLoadWasLive] lets the UI tell the truth about which rung it is on,
/// because "these events might be out of date" is information the user needs.
class EventsService {
  EventsService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const _cacheKey = 'gc-events-cache';

  bool lastLoadWasLive = false;
  DateTime? lastLoadedAt;

  Future<List<EventItem>> load({String role = '', String filter = 'all'}) async {
    try {
      final events = await _api.events(filter: filter);
      lastLoadWasLive = true;
      lastLoadedAt = DateTime.now();
      if (events.isNotEmpty) {
        await _cache(events);
      }
      return events;
    } catch (_) {
      lastLoadWasLive = false;
    }

    final cached = await _readCache();
    if (cached.isNotEmpty) return cached;

    return loadFallback();
  }

  Future<List<EventItem>> loadFallback() async {
    lastLoadWasLive = false;
    final raw = await rootBundle.loadString('assets/data/events.json');
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final value = payload['events'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => EventItem.fromJson(Map<String, dynamic>.from(item)))
        .where((event) => event.isUpcoming)
        .toList();
  }

  Future<void> _cache(List<EventItem> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'cachedAt': DateTime.now().toIso8601String(),
          'events': events.map(_toCacheJson).toList(),
        }),
      );
    } catch (_) {
      // A failed cache write must never break a successful load.
    }
  }

  Future<List<EventItem>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return const [];
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      lastLoadedAt = DateTime.tryParse(payload['cachedAt']?.toString() ?? '');
      final value = payload['events'];
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((e) => EventItem.fromApi(Map<String, dynamic>.from(e)))
          .where((e) => e.isUpcoming)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Cached in the API's own shape so [EventItem.fromApi] reads it back.
  Map<String, dynamic> _toCacheJson(EventItem e) => {
        'id': e.id,
        'title': e.title,
        'startsAt': e.start.toIso8601String(),
        'endsAt': e.end?.toIso8601String(),
        'description': e.description,
        'venueName': e.location,
        'city': e.city,
        'lat': e.lat,
        'lng': e.lng,
        'priceRaw': e.price,
        'url': e.url,
        'source': e.source,
        'geocodeQuality': e.geocoded,
        'verdictBand': e.verdictBand,
        'verdictFormat': e.verdictFormat,
        'hasVerdict': e.hasVerdict,
      };
}
