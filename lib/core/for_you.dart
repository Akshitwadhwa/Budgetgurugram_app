import '../models/event_intelligence.dart';
import '../models/event_item.dart';
import '../models/profile.dart';

/// One honest sentence for why this person might go. Returns null when there
/// is no real signal — never a generic "you might enjoy this".
String? forYouLine({
  required UserProfile profile,
  required EventItem event,
  EventVerdict? verdict,
}) {
  final role = profile.role.trim();
  final motives = profile.motives;
  final area = profile.neighbourhood.trim();
  final hay =
      '${event.title} ${event.description} ${verdict?.trueFormat.label ?? ''} ${verdict?.expect ?? ''}'
          .toLowerCase();

  final roleBit = _roleBit(role, hay, verdict);
  final wantsEvents = motives.contains('events');
  final near = _nearHome(area, event);
  final soon = _isSoon(event.start);

  if (roleBit == null && !wantsEvents && !near && !soon) return null;

  final parts = <String>[];
  if (roleBit != null) {
    parts.add(roleBit);
  } else if (wantsEvents) {
    parts.add('On your events list');
  }
  if (near) parts.add('near $area');
  if (soon) parts.add(_soonPhrase(event.start));

  if (parts.isEmpty) return null;
  final head = parts.first;
  final rest = parts.skip(1).join(', ');
  if (rest.isEmpty) return '$head.';
  return '$head, $rest.';
}

String? _roleBit(String role, String hay, EventVerdict? verdict) {
  if (role.isEmpty) return null;
  final r = role.toLowerCase();
  final format = verdict?.trueFormat;
  final handsOn = verdict?.handsOn == true || format == EventFormat.workshop;

  if (RegExp(r'founder|startup').hasMatch(r) &&
      RegExp(r'startup|founder|pitch|demo|hack|builder').hasMatch(hay)) {
    return handsOn
        ? 'Fits a $role: a build session, not just a talk'
        : 'Fits a $role looking at the local scene';
  }
  if (RegExp(r'tech|developer|engineer|product').hasMatch(r) &&
      RegExp(r'ai|hack|dev|tech|workshop|code|product').hasMatch(hay)) {
    return handsOn
        ? 'Fits a $role who wants to build'
        : 'Fits a $role following this topic';
  }
  if (RegExp(r'student').hasMatch(r) &&
      (verdict?.level == 'beginner' ||
          RegExp(r'beginner|intro|student|learn').hasMatch(hay))) {
    return 'Beginner-friendly enough for a student night';
  }
  if (RegExp(r'fitness|yoga|run|wellness|pickle').hasMatch(hay) &&
      (RegExp(r'resident|visitor|freelancer').hasMatch(r) || r.isNotEmpty)) {
    return 'A pause from the desk, close to home';
  }
  return null;
}

bool _nearHome(String area, EventItem event) {
  if (area.isEmpty || !event.hasRealCoords) return false;
  final token = area.toLowerCase().split(RegExp(r'\s+')).first;
  if (token.length < 3) return false;
  return event.location.toLowerCase().contains(token) ||
      event.city.toLowerCase().contains(token);
}

bool _isSoon(DateTime start) {
  final now = DateTime.now();
  final delta = start.difference(now);
  return !delta.isNegative && delta.inHours <= 36;
}

String _soonPhrase(DateTime start) {
  final local = start.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return sameDay ? 'and it is today' : 'and it is soon';
}
