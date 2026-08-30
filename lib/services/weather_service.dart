import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  const WeatherSnapshot({this.temp = 29, this.icon = '☼', this.label = 'Clear skies · Good to be out'});
  final int temp;
  final String icon;
  final String label;
}

class WeatherService {
  Future<WeatherSnapshot> load({required double lat, required double lng}) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code&timezone=auto',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const WeatherSnapshot();
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>? ?? {};
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final pair = code == 0
        ? ('☼', 'Clear skies · Good to be out')
        : code < 70
            ? ('☁', 'A softer day · Good for a café')
            : ('☂', 'Rain nearby · Try an indoor spot');
    return WeatherSnapshot(
      temp: ((current['temperature_2m'] as num?) ?? 29).round(),
      icon: pair.$1,
      label: pair.$2,
    );
  }
}
