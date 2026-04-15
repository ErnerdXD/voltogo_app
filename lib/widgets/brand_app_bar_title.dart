import 'package:flutter/material.dart';

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
        const SizedBox(width: 12),
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
        const SizedBox(width: 8),
        Image.asset(
          'assets/branding/voltogo.png',
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(
            title ?? 'VoltoGo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}
