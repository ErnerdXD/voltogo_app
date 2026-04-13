import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable app-bar branding (icon + optional page title).
class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 12), // Add left padding
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
      ],
    );
  }
}
