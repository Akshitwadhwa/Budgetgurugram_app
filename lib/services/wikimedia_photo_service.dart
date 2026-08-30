import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';

class PlacePhoto {
  const PlacePhoto({
    required this.thumbnailUrl,
    required this.descriptionUrl,
    required this.attribution,
  });

  final String thumbnailUrl;
  final String descriptionUrl;
  final String attribution;

  Map<String, String> toJson() => {
    'thumbnailUrl': thumbnailUrl,
    'descriptionUrl': descriptionUrl,
    'attribution': attribution,
  };

  factory PlacePhoto.fromJson(Map<String, dynamic> json) => PlacePhoto(
    thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
    descriptionUrl: json['descriptionUrl']?.toString() ?? '',
    attribution:
        json['attribution']?.toString() ?? 'Photo via Wikimedia Commons',
  );
}

/// A no-key, best-effort image source for actual public place photos.
///
/// Wikimedia Commons does not have photos for most small businesses, so callers
/// must preserve their visual fallback when this service returns null.
class WikimediaPhotoService {
  static const _cachePrefix = 'gc-commons-photo-';

  Future<PlacePhoto?> findPhoto(Place place) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cachePrefix${place.id}';
    final cached = prefs.getString(key);
    if (cached != null) {
      try {
        final photo = PlacePhoto.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        if (photo.thumbnailUrl.isNotEmpty && photo.descriptionUrl.isNotEmpty) {
          return photo;
        }
      } catch (_) {
        await prefs.remove(key);
      }
    }

    final photo = await _search(place);
    if (photo != null) {
      await prefs.setString(key, jsonEncode(photo.toJson()));
    }
    return photo;
  }

  Future<PlacePhoto?> _search(Place place) async {
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '"${place.name}" Gurugram',
        'gsrnamespace': '6',
        'gsrlimit': '5',
        'prop': 'imageinfo',
        'iiprop': 'url|extmetadata',
        'iiurlwidth': '1200',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = (payload['query'] as Map<String, dynamic>?)?['pages'];
      if (pages is! List || pages.isEmpty) {
        return null;
      }
      final candidates = pages
          .whereType<Map>()
          .map((page) => Map<String, dynamic>.from(page))
          .toList();
      final page = candidates
          .where(
            (page) =>
                _matchesPlaceName(page['title']?.toString() ?? '', place.name),
          )
          .firstOrNull;
      if (page == null) {
        return null;
      }
      final imageInfo = page['imageinfo'];
      if (imageInfo is! List || imageInfo.isEmpty || imageInfo.first is! Map) {
        return null;
      }
      final info = Map<String, dynamic>.from(imageInfo.first as Map);
      final thumbnailUrl = (info['thumburl'] ?? info['url'])?.toString();
      final descriptionUrl = info['descriptionurl']?.toString();
      if (thumbnailUrl == null ||
          thumbnailUrl.isEmpty ||
          descriptionUrl == null ||
          descriptionUrl.isEmpty) {
        return null;
      }

      final metadata = info['extmetadata'] as Map?;
      final artist = _plainText(
        (metadata?['Artist'] as Map?)?['value']?.toString(),
      );
      final license = _plainText(
        (metadata?['LicenseShortName'] as Map?)?['value']?.toString(),
      );
      final credit = artist.isEmpty ? 'Wikimedia Commons' : artist;
      final suffix = license.isEmpty
          ? 'via Wikimedia Commons'
          : '$license via Wikimedia Commons';
      return PlacePhoto(
        thumbnailUrl: thumbnailUrl,
        descriptionUrl: descriptionUrl,
        attribution: 'Photo: $credit · $suffix',
      );
    } catch (_) {
      return null;
    }
  }

  String _plainText(String? value) {
    if (value == null) {
      return '';
    }
    return value
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  bool _matchesPlaceName(String fileTitle, String placeName) {
    final cleanName = placeName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ' ',
    );
    final cleanTitle = fileTitle.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ' ',
    );
    final tokens = cleanName
        .split(' ')
        .where((token) => token.length >= 4)
        .toList();
    if (tokens.isEmpty) {
      return false;
    }
    return tokens.every(cleanTitle.contains);
  }
}
