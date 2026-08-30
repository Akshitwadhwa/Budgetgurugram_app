import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

import '../data/curated_places.dart';
import '../models/event_item.dart';
import '../models/place.dart';
import '../models/profile.dart';
import '../services/events_service.dart';
import '../services/places_service.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    EventsService? eventsService,
    PlacesService? placesService,
    WeatherService? weatherService,
    StorageService? storageService,
  })  : _eventsService = eventsService ?? EventsService(),
        _placesService = placesService ?? PlacesService(),
        _weatherService = weatherService ?? WeatherService(),
        _storage = storageService ?? StorageService();

  final EventsService _eventsService;
  final PlacesService _placesService;
  final WeatherService _weatherService;
  final StorageService _storage;

  UserProfile profile = const UserProfile();
  bool onboarded = false;
  bool loading = true;
  String query = '';
  String category = 'all';
  String mapCategory = 'all';
  String areaFilter = 'all';
  String eventFilter = 'best';
  String price = 'all';
  bool savedOnly = false;
  bool showGuidePins = false;
  List<Place> nearbyPlaces = const [];
  List<EventItem> events = const [];
  WeatherSnapshot weather = const WeatherSnapshot();
  String nearbyStatus = 'idle';
  String? toast;

  List<Place> get curated => curatedPlaces;

  Future<void> bootstrap() async {
    onboarded = await _storage.hasOnboarded();
    profile = await _storage.loadProfile() ?? const UserProfile();
    loading = false;
    notifyListeners();
    if (onboarded) await refreshAll();
  }

  Future<void> finishOnboarding(UserProfile next) async {
    profile = next;
    onboarded = true;
    category = next.motives.firstWhere((id) => id != 'explore', orElse: () => 'all');
    if (category == 'explore') category = 'all';
    await _storage.saveProfile(profile);
    notifyListeners();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadEvents(),
      loadNearby(),
      loadWeather(),
    ]);
  }

  Future<void> loadEvents() async {
    events = await _eventsService.load(role: profile.role);
    notifyListeners();
  }

  Future<void> loadNearby() async {
    nearbyStatus = 'loading';
    notifyListeners();
    try {
      nearbyPlaces = await _placesService.nearby(lat: profile.lat, lng: profile.lng);
      nearbyStatus = nearbyPlaces.isEmpty ? 'empty' : 'loaded';
      if (nearbyPlaces.isEmpty) showGuidePins = true;
    } catch (_) {
      nearbyPlaces = const [];
      nearbyStatus = 'unavailable';
      showGuidePins = true;
      toast = 'Live map data is unavailable. Showing guide pins.';
    }
    notifyListeners();
  }

  Future<void> loadWeather() async {
    weather = await _weatherService.load(lat: profile.lat, lng: profile.lng);
    notifyListeners();
  }

  Future<void> useCurrentLocation() async {
    final location = Location();
    if (!await location.serviceEnabled() && !await location.requestService()) {
      toast = 'Location services are off. Using Cyber City.';
      notifyListeners();
      return;
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    if (permission == PermissionStatus.denied || permission == PermissionStatus.deniedForever) {
      toast = 'Location permission denied. Using Cyber City.';
      notifyListeners();
      return;
    }
    final LocationData position;
    try {
      position = await location.getLocation();
    } catch (_) {
      toast = 'Could not get your location. Using Cyber City.';
      notifyListeners();
      return;
    }
    profile = profile.copyWith(
      locationMode: 'current',
      lat: position.latitude,
      lng: position.longitude,
      neighbourhood: _nearestArea(position.latitude, position.longitude),
    );
    await _storage.saveProfile(profile);
    notifyListeners();
    await refreshAll();
  }

  Future<void> setArea(String area) async {
    areaFilter = area;
    profile = profile.copyWith(neighbourhood: area, locationMode: 'area');
    await _storage.saveProfile(profile);
    notifyListeners();
  }

  Future<void> toggleSaved(String id) async {
    final next = {...profile.saved};
    if (!next.add(id)) next.remove(id);
    profile = profile.copyWith(saved: next);
    await _storage.saveProfile(profile);
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setCategory(String value) {
    category = value;
    mapCategory = {'food', 'work', 'coffee', 'gym'}.contains(value) ? value : 'all';
    savedOnly = false;
    notifyListeners();
  }

  void setMapCategory(String value) {
    mapCategory = value;
    category = value;
    notifyListeners();
  }

  void setEventFilter(String value) {
    eventFilter = value;
    notifyListeners();
  }

  void setPrice(String value) {
    price = value;
    notifyListeners();
  }

  void toggleGuidePins() {
    showGuidePins = !showGuidePins;
    notifyListeners();
  }

  void clearToast() {
    toast = null;
  }

  double distanceKm(Place place) {
    if (!place.hasCoords) return place.distance;
    return _haversine(profile.lat, profile.lng, place.lat!, place.lng!);
  }

  double eventDistanceKm(EventItem event) {
    if (!event.hasRealCoords) return 6;
    return _haversine(profile.lat, profile.lng, event.lat!, event.lng!);
  }

  List<Place> get visiblePlaces {
    return curated.where((place) {
      final hay = '${place.name} ${place.area} ${place.categoryLabel} ${place.tags.join(' ')}'.toLowerCase();
      final queryMatch = query.isEmpty || hay.contains(query.toLowerCase()) || (query.contains('free') && place.priceValue == 0);
      final categoryMatch = _matchesCategory(place);
      final priceMatch = price == 'all' ||
          (price == 'free' && place.priceValue == 0) ||
          (price == 'under300' && (place.priceValue ?? 9999) <= 300) ||
          (price == 'under700' && (place.priceValue ?? 9999) <= 700);
      final areaMatch = areaFilter == 'all' || place.area == areaFilter;
      final savedMatch = !savedOnly || profile.saved.contains(place.id);
      return queryMatch && categoryMatch && priceMatch && areaMatch && savedMatch;
    }).toList()
      ..sort((a, b) => distanceKm(a).compareTo(distanceKm(b)));
  }

  List<Place> get mapPlaces {
    final live = nearbyPlaces.where(_matchesMapCategory).toList();
    final guide = curated.where(_matchesMapCategory).toList();
    if (nearbyStatus == 'loaded' && live.isNotEmpty) {
      return (showGuidePins ? [...live, ...guide] : live).take(80).toList();
    }
    return guide.take(80).toList();
  }

  List<EventItem> get visibleEvents {
    final scored = events.where(_eventMatchesFilter).map((event) {
      final score = _eventScore(event);
      return event.copyWith(fitPercent: _fitPercent(score));
    }).toList();
    scored.sort((a, b) {
      if (eventFilter == 'best') {
        return (b.fitPercent ?? 0).compareTo(a.fitPercent ?? 0);
      }
      return a.start.compareTo(b.start);
    });
    return scored;
  }

  List<({String kind, Object item, int score})> get recommendations {
    final items = <({String kind, Object item, int score})>[];
    for (final place in curated) {
      items.add((kind: 'place', item: place, score: _placeScore(place)));
    }
    for (final event in events.where((e) => e.isUpcoming)) {
      items.add((kind: 'event', item: event, score: _eventScore(event)));
    }
    items.sort((a, b) => b.score.compareTo(a.score));
    return items.take(4).toList();
  }

  bool _matchesCategory(Place place) {
    if (category == 'all') return true;
    if (category == 'coffee') {
      return place.category == 'food' && RegExp(r'coffee|café|cafe', caseSensitive: false).hasMatch(place.name);
    }
    return place.category == category;
  }

  bool _matchesMapCategory(Place place) {
    final hay = '${place.name} ${place.kind} ${place.category} ${place.tags.join(' ')}'.toLowerCase();
    final useful = place.category == 'food' || place.category == 'work' || place.category == 'gym';
    if (!useful && place.category != 'public') return false;
    if (mapCategory == 'all') return useful || place.category == 'public';
    if (mapCategory == 'coffee') return place.category == 'food' && RegExp(r'coffee|cafe|café').hasMatch(hay);
    if (mapCategory == 'gym') return place.category == 'gym' || RegExp(r'gym|fitness|yoga').hasMatch(hay);
    return place.category == mapCategory;
  }

  bool _eventMatchesFilter(EventItem event) {
    if (!event.isUpcoming) return false;
    final now = DateTime.now();
    if (eventFilter == 'today') {
      return event.start.year == now.year && event.start.month == now.month && event.start.day == now.day;
    }
    if (eventFilter == 'week') return event.start.isBefore(now.add(const Duration(days: 7)));
    if (eventFilter == 'free') return RegExp(r'free|₹0', caseSensitive: false).hasMatch(event.price);
    return true;
  }

  int _placeScore(Place place) {
    var score = 18;
    if (profile.motives.contains(place.category)) score += 38;
    if (place.area == profile.neighbourhood) score += 12;
    score += max(0, (16 - distanceKm(place) * 2).round());
    return score;
  }

  int _eventScore(EventItem event) {
    final hay = '${event.title} ${event.description} ${event.city} ${event.location}'.toLowerCase();
    var score = 16;
    if (profile.motives.contains('events')) score += 48;
    if (RegExp(r'tech|startup|founder').hasMatch(profile.role.toLowerCase()) &&
        RegExp(r'ai|hack|startup|founder|developer|tech').hasMatch(hay)) {
      score += 28;
    }
    if (RegExp(r'fitness|yoga|run|pickle|gym|wellness').hasMatch(hay)) score += 18;
    if (event.start.difference(DateTime.now()).inDays <= 1) score += 18;
    if (event.hasRealCoords) score += 10;
    score += max(0, (12 - eventDistanceKm(event)).round());
    return score;
  }

  int _fitPercent(int score) => min(99, max(42, ((score / 90) * 100).round()));

  String _nearestArea(double lat, double lng) {
    if (lat > 28.52) return 'Old Gurgaon';
    if (lng < 77.06) return 'Golf Course Road';
    if (lng > 77.11) return 'Udyog Vihar';
    if (lat < 28.46) return 'Sector 29';
    if (lng > 77.095) return 'MG Road';
    return 'Cyber City';
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double value) => value * pi / 180;
}
