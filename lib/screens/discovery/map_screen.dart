import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.title});
  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/branding/voltogo_icon.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.electric_car),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/branding/voltogo.png',
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Map Screen Placeholder'),
          ],
        ),
      ),
    );
  }
}
