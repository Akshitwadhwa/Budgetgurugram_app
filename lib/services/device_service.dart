import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Anonymous per-install identity.
///
/// No login, no account, no email. The backend rate-limits Q&A per device
/// because each question costs real money, but the user never sees any of this
/// — there is no sign-up wall in front of a city guide.
///
/// A reset (reinstall, cleared data) simply issues a new id. That is an
/// accepted limit: this is abuse friction, not authentication.
class DeviceService {
  static const _key = 'gc-device-id';

  String? _cached;

  Future<String> deviceId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = _uuidV4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }

  /// UUID v4 from `Random.secure()` — avoids taking a package dependency for
  /// sixteen bytes of randomness.
  static String _uuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
