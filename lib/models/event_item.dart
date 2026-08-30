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
    this.verdictBand,
    this.verdictFormat,
    this.hasVerdict = false,
    this.about = '',
    this.guestCount,
    this.guestCountSource,
    this.guestCountAt,
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

  /// Verdict summary carried on the *list* response so a card can show the
  /// reading without a second request per event. Null means no verdict yet.
  final String? verdictBand;

  /// The verdict itself ("workshop", "talk"), so a card can state the reading
  /// rather than only its confidence.
  final String? verdictFormat;
  final bool hasVerdict;

  /// Short sourced briefing. Empty when we only have a title.
  final String about;
  final int? guestCount;
  final String? guestCountSource;
  final DateTime? guestCountAt;

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
      about: (json['about'] ?? json['description'] ?? '').toString(),
      guestCount: (json['guestCount'] as num?)?.toInt() ??
          (json['guest_count'] as num?)?.toInt(),
    );
  }

  /// Maps the `/v1/events` response, which uses different field names from the
  /// legacy Vercel feed and the bundled offline fixture.
  factory EventItem.fromApi(Map<String, dynamic> json) {
    final venue = json['venueName']?.toString();
    final address = json['address']?.toString();
    return EventItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Event',
      start: DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['endsAt']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      location: (venue?.isNotEmpty ?? false)
          ? venue!
          : (address?.isNotEmpty ?? false)
              ? address!
              : 'Gurugram',
      city: json['city']?.toString() ?? 'Gurugram',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      price: json['priceRaw']?.toString() ?? 'See source',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Luma',
      geocoded: json['geocodeQuality']?.toString(),
      verdictBand: json['verdictBand']?.toString(),
      verdictFormat: json['verdictFormat']?.toString(),
      hasVerdict: json['hasVerdict'] == true,
      about: json['about']?.toString() ?? '',
      guestCount: (json['guestCount'] as num?)?.toInt(),
      guestCountSource: json['guestCountSource']?.toString(),
      guestCountAt: DateTime.tryParse(json['guestCountAt']?.toString() ?? ''),
    );
  }

  EventItem copyWith({
    int? fitPercent,
    String? about,
    int? guestCount,
    String? guestCountSource,
    DateTime? guestCountAt,
    String? verdictBand,
    String? verdictFormat,
    bool? hasVerdict,
  }) =>
      EventItem(
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
        verdictBand: verdictBand ?? this.verdictBand,
        verdictFormat: verdictFormat ?? this.verdictFormat,
        hasVerdict: hasVerdict ?? this.hasVerdict,
        about: about ?? this.about,
        guestCount: guestCount ?? this.guestCount,
        guestCountSource: guestCountSource ?? this.guestCountSource,
        guestCountAt: guestCountAt ?? this.guestCountAt,
      );
}
