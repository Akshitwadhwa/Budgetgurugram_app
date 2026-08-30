import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_item.dart';
import '../models/place.dart';
import '../services/map_config.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'map_pin.dart';

/// The map surface.
///
/// Tiles come from Mapbox's minimal styles, switched with the app theme so the
/// basemap is never a bright rectangle in a dark app. Markers are custom-drawn
/// Flutter widgets ([MapPin]) rather than images, which is what makes them
/// themeable, animatable and tappable without any native work.
///
/// Selection state lives here rather than in [AppState] because it is
/// view-local: which pin is open has no meaning once you leave the map.
class CityMap extends StatefulWidget {
  const CityMap({
    super.key,
    required this.center,
    required this.places,
    this.events = const [],
    this.userLocation,
    this.onPlaceTap,
    this.onEventTap,
    this.height = 360,
    this.activeCategory = 'all',
  });

  final LatLng center;
  final List<Place> places;
  final List<EventItem> events;
  final LatLng? userLocation;
  final ValueChanged<Place>? onPlaceTap;
  final ValueChanged<EventItem>? onEventTap;
  final double height;

  /// Pins outside this category are dimmed, not removed.
  final String activeCategory;

  @override
  State<CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<CityMap> {
  final _controller = MapController();
  String? _selectedId;

  static const _icons = {
    'food': Icons.restaurant_rounded,
    'coffee': Icons.local_cafe_rounded,
    'work': Icons.laptop_mac_rounded,
    'gym': Icons.fitness_center_rounded,
    'public': Icons.park_rounded,
    'parks': Icons.park_rounded,
    'events': Icons.auto_awesome_rounded,
  };

  @override
  void didUpdateWidget(CityMap old) {
    super.didUpdateWidget(old);
    // Fly to a new centre when the user changes area, rather than cutting.
    if (old.center != widget.center) {
      _controller.move(widget.center, _controller.camera.zoom);
    }
  }

  String _categoryOf(Place place) {
    if (place.category == 'food' &&
        RegExp(r'coffee|cafe|café', caseSensitive: false).hasMatch(place.name)) {
      return 'coffee';
    }
    return place.category;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final brightness = Theme.of(context).brightness;

    final markers = <Marker>[
      ...widget.places.where((e) => e.hasCoords).map((place) {
        final category = _categoryOf(place);
        return Marker(
          point: LatLng(place.lat!, place.lng!),
          width: MapPin.width,
          height: MapPin.height,
          // Anchors the pin's tail on the coordinate rather than its centre.
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedId = place.id);
              widget.onPlaceTap?.call(place);
            },
            child: MapPin(
              color: p.categoryColor(category),
              icon: _icons[category] ?? Icons.place_rounded,
              selected: _selectedId == place.id,
              dimmed: widget.activeCategory != 'all' &&
                  widget.activeCategory != category,
            ),
          ),
        );
      }),
      ...widget.events.where((e) => e.hasRealCoords).map((event) {
        return Marker(
          point: LatLng(event.lat!, event.lng!),
          width: MapPin.width,
          height: MapPin.height,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedId = event.id);
              widget.onEventTap?.call(event);
            },
            child: MapPin(
              color: p.events,
              icon: Icons.auto_awesome_rounded,
              selected: _selectedId == event.id,
            ),
          ),
        );
      }),
      if (widget.userLocation != null)
        Marker(
          point: widget.userLocation!,
          width: 34,
          height: 34,
          child: const UserLocationPin(),
        ),
    ];

    final map = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: 12.6,
        minZoom: 9,
        maxZoom: 18,
        backgroundColor: p.surfaceSunken,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, _) => setState(() => _selectedId = null),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.urlTemplate(brightness),
          tileDimension: MapConfig.tileSize,
          zoomOffset: MapConfig.zoomOffset.toDouble(),
          userAgentPackageName: 'com.gurugramcommons.budget_gurugram',
        ),
        MarkerLayer(markers: markers),
      ],
    );

    return ClipRRect(
      borderRadius: Radii.rLg,
      child: Stack(
        children: [
          widget.height.isFinite
              ? SizedBox(height: widget.height, child: map)
              : map,
          Positioned(
            left: Space.s8,
            bottom: Space.s8,
            child: const _Attribution(),
          ),
        ],
      ),
    );
  }
}

/// Licence attribution. Required by both Mapbox and OpenStreetMap terms —
/// this is a contractual element, not decoration, so it is never conditional.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(MapConfig.attributionUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s6, vertical: 3),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.86),
          borderRadius: Radii.rSm,
        ),
        child: Text(
          MapConfig.attribution,
          style: AppType.labelS(color: p.inkFaint),
        ),
      ),
    );
  }
}
