import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place.dart';
import '../theme/app_colors.dart';

Future<void> showPlaceSheet({
  required BuildContext context,
  required Place place,
  required double distanceKm,
  required bool saved,
  required VoidCallback onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) {
      final color = Color(int.parse(place.accent.replaceFirst('#', '0xFF')));
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.bottomLeft,
              child: Text(place.name, style: GoogleFonts.instrumentSerif(color: Colors.white, fontSize: 32)),
            ),
            const SizedBox(height: 16),
            Text(place.name, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.forest)),
            Text('${place.area} · ${distanceKm.toStringAsFixed(1)} km from you', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            Text(place.description, style: const TextStyle(color: AppColors.muted, height: 1.5)),
            const SizedBox(height: 16),
            Text(place.open, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSave,
                    child: Text(saved ? '♥ Saved' : '♡ Save place'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final q = Uri.encodeComponent('${place.name}, ${place.area}, Gurugram');
                      launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), mode: LaunchMode.externalApplication);
                    },
                    child: const Text('Directions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Confirm hours and price before travelling · ${place.source}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      );
    },
  );
}
