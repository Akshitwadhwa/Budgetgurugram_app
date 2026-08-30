import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? const Color(0xFFFBF9F2) : AppColors.forest;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: color), shape: BoxShape.circle),
          child: Text('C', style: GoogleFonts.instrumentSerif(fontSize: 20, fontStyle: FontStyle.italic, color: color)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gurugram', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            Text('COMMONS', style: GoogleFonts.dmSans(fontSize: 8, letterSpacing: 2.2, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ],
    );
  }
}
