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
      children: [
        Image.asset(
          'assets/branding/voltogo_icon.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.electric_car),
        ),
        if (title != null && title!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(title!),
        ],
      ],
    );
  }
}

