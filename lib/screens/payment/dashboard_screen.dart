import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/reservation_provider.dart';

import '../../models/reservation_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleProvider);
    final reservationState = ref.watch(reservationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicle added.'));
          }
          final vehicle = vehicles.first;
          final batteryCapacity = vehicle.batteryCapacityKwh ?? 30;
          // Find latest reservation for this vehicle
          final latestRes = reservationState.reservations
              .where((r) => r.vehicleId == vehicle.id && r.currentBattery != null)
              .toList()
              .fold<ReservationModel?>(null, (prev, r) => prev == null || (r.startTime != null && (prev.startTime == null || r.startTime!.isAfter(prev.startTime!))) ? r : prev);
          final currentBattery = latestRes?.currentBattery ?? (1 + (vehicle.id.hashCode % 100));
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Vehicle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car, size: 44, color: Colors.blueGrey[700]),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${vehicle.brand ?? ''} ${vehicle.model ?? ''}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Plate: ${vehicle.plateNumber ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              Text('Plug: ${vehicle.plugType ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              Text('Battery: $batteryCapacity kWh', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Battery bar
                Text('Current Battery', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.battery_charging_full, color: Colors.green[600], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[300],
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: currentBattery / 100.0,
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.greenAccent,
                                    if (currentBattery > 60) Colors.green else if (currentBattery > 30) Colors.orange else Colors.red,
                                  ],
                                  stops: [0.0, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                '$currentBattery%',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Add more stats here as needed
                Text('Energy & CO2 Stats', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Placeholder for stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Coming soon...', style: TextStyle(color: Colors.blueGrey)),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
