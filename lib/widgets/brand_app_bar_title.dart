import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable app-bar branding (icon + optional page title).
class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({
    super.key,
    this.title,
  });

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 8), // Add left padding
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: ClipOval(
              child: Image.asset(
                'assets/branding/voltogo_icon.png',
                fit: BoxFit.cover,
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.electric_car, size: 24),
              ),
            ),
          ),
        ),
        if (title != null && title!.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            title!,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.black,
            ),
          ),
        ],
      ],
    );
  }
}
