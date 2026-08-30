import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_item.dart';
import '../theme/app_colors.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.distanceLabel});

  final EventItem event;
  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(event.source.toUpperCase(), style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const Spacer(),
              Text(DateFormat('E, d MMM, h:mm a').format(event.start.toLocal()), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.forest)),
            ],
          ),
          if (event.fitPercent != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE7EFE1), borderRadius: BorderRadius.circular(20)),
              child: Text('${event.fitPercent}% match', style: const TextStyle(color: Color(0xFF5F744F), fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 10),
          Text(event.title, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.forest, height: 1.15)),
          const SizedBox(height: 8),
          Text('⌖ ${event.location} · $distanceLabel', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(event.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(event.price, style: const TextStyle(color: Color(0xFF6C8B5C), fontWeight: FontWeight.w700, fontSize: 12)),
              const Spacer(),
              if (event.url.isNotEmpty)
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(event.url), mode: LaunchMode.externalApplication),
                  child: Text('View on ${event.source} ↗'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
