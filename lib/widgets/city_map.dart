import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/event_item.dart';
import '../models/place.dart';
import '../theme/app_colors.dart';

class CityMap extends StatelessWidget {
  const CityMap({
    super.key,
    required this.center,
    required this.places,
    this.events = const [],
    this.userLocation,
    this.onPlaceTap,
    this.onEventTap,
    this.height = 360,
  });

  final LatLng center;
  final List<Place> places;
  final List<EventItem> events;
  final LatLng? userLocation;
  final ValueChanged<Place>? onPlaceTap;
  final ValueChanged<EventItem>? onEventTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (userLocation != null)
        Marker(
          point: userLocation!,
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
            ),
          ),
        ),
      ...places.where((place) => place.hasCoords).map((place) {
        return Marker(
          point: LatLng(place.lat!, place.lng!),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => onPlaceTap?.call(place),
            child: _Pin(color: AppColors.category(place.category == 'food' && RegExp(r'coffee|cafe|café', caseSensitive: false).hasMatch(place.name) ? 'coffee' : place.category), label: place.glyph),
          ),
        );
      }),
      ...events.where((event) => event.hasRealCoords).map((event) {
        return Marker(
          point: LatLng(event.lat!, event.lng!),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => onEventTap?.call(event),
            child: const _Pin(color: AppColors.events, label: '✦'),
          ),
        );
      }),
    ];

    final map = FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 12.4),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gurugramcommons.gurugram_commons',
        ),
        MarkerLayer(markers: markers),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: height.isFinite ? SizedBox(height: height, child: map) : map,
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Text(label, style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
