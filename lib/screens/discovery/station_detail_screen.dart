import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/services/open_charge_map_service.dart';
import 'package:voltogo_app/screens/reservation/reservation_screen.dart';

class StationDetailSheet extends ConsumerWidget {
  final ChargingStation station;

  const StationDetailSheet({super.key, required this.station});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
        // 1. Add SafeArea to prevent UI clipping on modern phone screens
        child: SafeArea(
          // 2. Add SingleChildScrollView to allow vertical scrolling in landscape
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

          // Station Name
          Text(
            station.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Address
          if (station.address != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    station.address!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Details Row (Available Points)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Points', style: TextStyle(color: Colors.grey)),
                  Text(
                    station.availablePoints?.toString() ?? 'Unknown',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Connectors
          if (station.connectorTypes != null && station.connectorTypes!.isNotEmpty) ...[
            const Text('Connectors', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: station.connectorTypes!.map((type) => Chip(
                label: Text(type, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                side: BorderSide.none,
              )).toList(),
            ),
          ],
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    //  map screen to trigger the fly-to action
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Locate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // 1. Close the bottom sheet on the map
                    Navigator.pop(context);

                    // 2. Send the signal to Riverpod!
                    ref.read(pendingBookingStationProvider.notifier).state = station.name;

                    // 3. Switch tabs using GoRouter (change '/reservation' if your path is named differently in app_router.dart)
                    context.go('/reservation');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Book Now'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // Bottom padding
        ],
      ),

            )
        )
    );
  }
}