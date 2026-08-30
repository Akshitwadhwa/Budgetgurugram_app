class UserProfile {
  const UserProfile({
    this.motives = const ['explore'],
    this.role = '',
    this.displayName = '',
    this.locationMode = 'area',
    this.neighbourhood = 'Cyber City',
    this.lat = 28.4945,
    this.lng = 77.0894,
    this.saved = const {},
  });

  final List<String> motives;
  final String role;
  final String displayName;
  final String locationMode;
  final String neighbourhood;
  final double lat;
  final double lng;
  final Set<String> saved;

  UserProfile copyWith({
    List<String>? motives,
    String? role,
    String? displayName,
    String? locationMode,
    String? neighbourhood,
    double? lat,
    double? lng,
    Set<String>? saved,
  }) {
    return UserProfile(
      motives: motives ?? this.motives,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      locationMode: locationMode ?? this.locationMode,
      neighbourhood: neighbourhood ?? this.neighbourhood,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      saved: saved ?? this.saved,
    );
  }

  Map<String, dynamic> toJson() => {
        'motives': motives,
        'role': role,
        'displayName': displayName,
        'locationMode': locationMode,
        'neighbourhood': neighbourhood,
        'lat': lat,
        'lng': lng,
        'saved': saved.toList(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      motives: (json['motives'] as List?)?.map((e) => e.toString()).toList() ?? const ['explore'],
      role: json['role']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      locationMode: json['locationMode']?.toString() ?? 'area',
      neighbourhood: json['neighbourhood']?.toString() ?? 'Cyber City',
      lat: (json['lat'] as num?)?.toDouble() ?? 28.4945,
      lng: (json['lng'] as num?)?.toDouble() ?? 77.0894,
      saved: ((json['saved'] as List?) ?? const []).map((e) => e.toString()).toSet(),
    );
  }
}

class Motive {
  const Motive(this.id, this.icon, this.label, this.detail);
  final String id;
  final String icon;
  final String label;
  final String detail;
}

const motives = [
  Motive('food', '◒', 'Eat & drink', 'Good food, clearly priced'),
  Motive('work', '⌘', 'Work somewhere', 'Cafés, desks, quiet corners'),
  Motive('events', '✦', 'Find events', 'Culture, meetups, things to do'),
  Motive('public', '⌁', 'Take a break', 'Parks, walks, public spaces'),
  Motive('services', '＋', 'Get things done', 'Useful places and services'),
  Motive('explore', '↗', 'Explore the city', 'Follow your curiosity'),
];

const roles = [
  'Tech professional',
  'Startup founder',
  'Startup employee',
  'Freelancer / remote',
  'Student',
  'Resident',
  'Visitor',
];

const neighbourhoods = [
  'Cyber City',
  'Sector 29',
  'MG Road',
  'Old Gurgaon',
  'Golf Course Road',
  'Udyog Vihar',
];

const neighbourhoodNotes = {
  'Cyber City': 'Workdays, coffee & after-hours',
  'Sector 29': 'Parks, food & easy evenings',
  'MG Road': 'Metro-connected city stops',
  'Old Gurgaon': 'Everyday places with character',
  'Golf Course Road': 'Premium work & coffee',
  'Udyog Vihar': 'Flexible workday bases',
};
