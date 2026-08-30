class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.area,
    required this.price,
    this.priceValue,
    this.priceType = 'per person',
    this.tags = const [],
    this.distance = 2,
    this.open = 'Confirm before visiting',
    this.verified = 'Recently',
    this.source = 'Editorial sample',
    this.sourceUrl,
    this.description = '',
    this.accent = '#1e3b35',
    this.glyph = '•',
    this.lat,
    this.lng,
    this.isLiveSource = false,
    this.kind,
  });

  final String id;
  final String name;
  final String category;
  final String categoryLabel;
  final String area;
  final String price;
  final double? priceValue;
  final String priceType;
  final List<String> tags;
  final double distance;
  final String open;
  final String verified;
  final String source;
  final String? sourceUrl;
  final String description;
  final String accent;
  final String glyph;
  final double? lat;
  final double? lng;
  final bool isLiveSource;
  final String? kind;

  bool get hasCoords => lat != null && lng != null;

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Place',
      category: json['category']?.toString() ?? 'services',
      categoryLabel: json['categoryLabel']?.toString() ?? 'Local place',
      area: json['area']?.toString() ?? 'Near you',
      price: json['price']?.toString() ?? 'Check source',
      priceValue: (json['priceValue'] as num?)?.toDouble(),
      priceType: json['priceType']?.toString() ?? 'Not listed',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      distance: (json['distance'] as num?)?.toDouble() ?? 2,
      open: json['open']?.toString() ?? 'Confirm before visiting',
      verified: json['verified']?.toString() ?? 'Recently',
      source: json['source']?.toString() ?? 'OpenStreetMap',
      sourceUrl: json['sourceUrl']?.toString(),
      description: json['description']?.toString() ?? '',
      accent: json['accent']?.toString() ?? '#1e3b35',
      glyph: json['glyph']?.toString() ?? '•',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isLiveSource: json['isLiveSource'] == true,
      kind: json['kind']?.toString(),
    );
  }
}
