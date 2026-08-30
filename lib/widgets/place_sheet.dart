import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place.dart';
import '../services/wikimedia_photo_service.dart';
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PlaceSheet(
      place: place,
      distanceKm: distanceKm,
      saved: saved,
      onSave: onSave,
    ),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({
    required this.place,
    required this.distanceKm,
    required this.saved,
    required this.onSave,
  });

  final Place place;
  final double distanceKm;
  final bool saved;
  final VoidCallback onSave;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  late final Future<PlacePhoto?> _photo = WikimediaPhotoService().findPhoto(
    widget.place,
  );

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final color = Color(int.parse(place.accent.replaceFirst('#', '0xFF')));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<PlacePhoto?>(
            future: _photo,
            builder: (context, snapshot) => _PhotoBanner(
              place: place,
              color: color,
              photo: snapshot.data,
              loading: snapshot.connectionState == ConnectionState.waiting,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            place.name,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          Text(
            '${place.area} · ${widget.distanceKm.toStringAsFixed(1)} km from you',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Text(
            place.description,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(place.open, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSave,
                  child: Text(widget.saved ? '♥ Saved' : '♡ Save place'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final q = Uri.encodeComponent(
                      '${place.name}, ${place.area}, Gurugram',
                    );
                    launchUrl(
                      Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$q',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Directions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Confirm hours and price before travelling · ${place.source}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PhotoBanner extends StatelessWidget {
  const _PhotoBanner({
    required this.place,
    required this.color,
    required this.photo,
    required this.loading,
  });

  final Place place;
  final Color color;
  final PlacePhoto? photo;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return Container(
        height: 120,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.bottomLeft,
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                place.name,
                style: GoogleFonts.instrumentSerif(
                  color: Colors.white,
                  fontSize: 32,
                ),
              ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo!.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: color),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse(photo!.descriptionUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  photo!.attribution,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
