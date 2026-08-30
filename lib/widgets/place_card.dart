import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/place.dart';
import '../theme/app_colors.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.distanceKm,
    required this.saved,
    required this.onOpen,
    required this.onSave,
  });

  final Place place;
  final double distanceKm;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(place.accent.replaceFirst('#', '0xFF')));
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 92,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.instrumentSerif(color: Colors.white, fontSize: 22, height: 1),
                    ),
                  ),
                  IconButton(
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${place.area} · ${distanceKm.toStringAsFixed(1)} km', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(place.price, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.forest)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: place.tags.take(3).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(20)),
                      child: Text(tag, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
