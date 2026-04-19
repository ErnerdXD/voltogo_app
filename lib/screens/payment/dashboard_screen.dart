import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation_model.dart';
import '../../models/charging_session_model.dart';
import '../../widgets/energy_chart.dart';

final selectedVehicleIndexProvider = StateProvider<int>((ref) => 0);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleProvider);
    final reservationState = ref.watch(reservationProvider);
    final selectedIndex = ref.watch(selectedVehicleIndexProvider);
    return Scaffold(
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicle added.'));
          }
          // Vehicle selector UI
          Widget vehicleSelector = const SizedBox.shrink();
          if (vehicles.length > 1) {
            vehicleSelector = Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: DropdownButton<int>(
                value: selectedIndex < vehicles.length ? selectedIndex : 0,
                items: List.generate(vehicles.length, (i) {
                  final v = vehicles[i];
                  return DropdownMenuItem<int>(
                    value: i,
                    child: Text('${v.brand ?? ''} ${v.model ?? ''}'),
                  );
                }),
                onChanged: (idx) {
                  if (idx != null) {
                    ref.read(selectedVehicleIndexProvider.notifier).state = idx;
                  }
                },
              ),
            );
          }
          final vehicle = vehicles[selectedIndex < vehicles.length ? selectedIndex : 0];
          final batteryCapacity = vehicle.batteryCapacityKwh ?? 30;
          // Find latest reservation for this vehicle
          final latestRes = reservationState.reservations
              .where((r) => r.vehicleId == vehicle.id && r.currentBattery != null)
              .toList()
              .fold<ReservationModel?>(null, (prev, r) => prev == null || (r.startTime != null && (prev.startTime == null || r.startTime!.isAfter(prev.startTime!))) ? r : prev);
          final int minBattery = batteryCapacity.clamp(1, 100);
          final int currentBattery = latestRes?.currentBattery ?? ((vehicle.id.hashCode % 30) + 1);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 26),
                  Text('Current Vehicle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  vehicleSelector,
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
                  // Energy & CO2 Stats
                  Text('Energy & CO2 Stats', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  // Mock or real charging session data for the selected vehicle
                  Builder(
                    builder: (context) {
                      // TODO: Replace with real data fetching logic
                      final List<ChargingSessionModel> sessions = [
                        ChargingSessionModel(
                          id: '1',
                          reservationId: 'r1',
                          checkedInAt: DateTime.now().subtract(const Duration(days: 5)),
                          energyConsumedKwh: 12.5,
                          co2SavedKg: 8.2,
                        ),
                        ChargingSessionModel(
                          id: '2',
                          reservationId: 'r2',
                          checkedInAt: DateTime.now().subtract(const Duration(days: 3)),
                          energyConsumedKwh: 10.0,
                          co2SavedKg: 6.7,
                        ),
                        ChargingSessionModel(
                          id: '3',
                          reservationId: 'r3',
                          checkedInAt: DateTime.now().subtract(const Duration(days: 1)),
                          energyConsumedKwh: 15.2,
                          co2SavedKg: 9.1,
                        ),
                      ];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Energy Usage (kWh)', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          EnergyChart(sessions: sessions),
                          const SizedBox(height: 24),
                          Text('CO₂ Savings (kg)', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          EnergyChart(sessions: sessions, showCO2: true),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
