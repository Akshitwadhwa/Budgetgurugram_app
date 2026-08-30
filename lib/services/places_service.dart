import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place.dart';
import 'api_config.dart';

class PlacesService {
  Future<List<Place>> nearby({required double lat, required double lng}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.nearbyPath}').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(3),
        'lng': lng.toStringAsFixed(3),
        'radius': '5000',
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Nearby places failed');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final places = payload['places'];
    if (places is! List) throw Exception('Invalid nearby payload');
    return places
        .whereType<Map>()
        .map((item) => Place.fromJson(Map<String, dynamic>.from(item)))
        .where((place) => place.hasCoords)
        .toList();
  }
}
