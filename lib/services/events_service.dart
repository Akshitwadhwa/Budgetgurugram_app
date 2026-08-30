import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/event_item.dart';
import 'api_config.dart';

class EventsService {
  Future<List<EventItem>> load({String role = ''}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.eventsPath}').replace(
        queryParameters: {
          'ts': DateTime.now().millisecondsSinceEpoch.toString(),
          if (role.isNotEmpty) 'role': role,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final events = _parse(payload['events']);
        if (events.isNotEmpty) return events;
      }
    } catch (_) {}
    return loadFallback();
  }

  Future<List<EventItem>> loadFallback() async {
    final raw = await rootBundle.loadString('assets/data/events.json');
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    return _parse(payload['events']);
  }

  List<EventItem> _parse(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => EventItem.fromJson(Map<String, dynamic>.from(item)))
        .where((event) => event.isUpcoming)
        .toList();
  }
}
