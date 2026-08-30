class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.description = '',
    this.location = 'Gurugram',
    this.city = 'Gurugram',
    this.lat,
    this.lng,
    this.price = 'See source',
    this.url = '',
    this.source = 'Luma',
    this.geocoded,
    this.fitPercent,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String description;
  final String location;
  final String city;
  final double? lat;
  final double? lng;
  final String price;
  final String url;
  final String source;
  final String? geocoded;
  final int? fitPercent;

  bool get hasRealCoords {
    if (lat == null || lng == null) return false;
    if (geocoded == 'city-default' || geocoded == 'unlocated') return false;
    if (location.toLowerCase().startsWith('location listed')) return false;
    return lat! >= 28.35 && lat! <= 28.56 && lng! >= 76.92 && lng! <= 77.16;
  }

  bool get isUpcoming {
    final now = DateTime.now();
    if (end != null) return end!.isAfter(now);
    return !start.isBefore(now.subtract(const Duration(hours: 2)));
  }

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id']?.toString() ?? json['url']?.toString() ?? json['title'].toString(),
      title: json['title']?.toString() ?? 'Event',
      start: DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? ''),
      description: (json['aiSummary'] ?? json['description'] ?? '').toString(),
      location: json['location']?.toString() ?? 'Gurugram',
      city: json['city']?.toString() ?? 'Gurugram',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      price: json['price']?.toString() ?? 'See source',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Luma',
      geocoded: json['geocoded']?.toString(),
    );
  }

  EventItem copyWith({int? fitPercent}) => EventItem(
        id: id,
        title: title,
        start: start,
        end: end,
        description: description,
        location: location,
        city: city,
        lat: lat,
        lng: lng,
        price: price,
        url: url,
        source: source,
        geocoded: geocoded,
        fitPercent: fitPercent ?? this.fitPercent,
      );
}
