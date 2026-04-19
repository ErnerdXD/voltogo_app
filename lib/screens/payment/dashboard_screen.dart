import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
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
                      final List<ChargingSessionModel> sessions = generateRandomSessionsForVehicle(vehicle.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Energy Usage (kWh)', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          EnergyChart(sessions: sessions),
                          const SizedBox(height: 4),
                          Text(
                            'This chart shows your historical energy consumption (kWh) for each charging session.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          Text('CO₂ Savings (kg)', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          EnergyChart(sessions: sessions, showCO2: true),
                          const SizedBox(height: 4),
                          Text(
                            'This chart shows the estimated CO₂ emissions you saved by charging your EV instead of using a petrol car.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 32),
                          // Charging History Section
                          Text('Charging History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...sessions.map((s) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.ev_station, color: Colors.blue),
                              title: Text(s.checkedInAt != null ? '${s.checkedInAt!.month}/${s.checkedInAt!.day}/${s.checkedInAt!.year}' : '-'),
                              subtitle: Text('Energy: ${s.energyConsumedKwh?.toStringAsFixed(2) ?? '-'} kWh\nCO₂ Savings: ${s.co2SavedKg?.toStringAsFixed(2) ?? '-'} kg'),
                            ),
                          )),
                          const SizedBox(height: 32),
                          // Suggestions & Recommendations Section
                          Text('Suggestions & Recommendations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Card(
                            color: Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('For Your Car:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('• Keep your battery between 20-80% for optimal longevity.'),
                                  const Text('• Regularly check tire pressure for better efficiency.'),
                                  const SizedBox(height: 12),
                                  Text('For Charging:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('• Charge during off-peak hours for lower rates and greener energy.'),
                                  const Text('• Plan longer trips with charging stops in advance.'),
                                ],
                              ),
                            ),
                          ),
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

  // Helper to generate random sessions for a vehicle
  List<ChargingSessionModel> generateRandomSessionsForVehicle(String vehicleId) {
    final rand = Random(vehicleId.hashCode);
    final now = DateTime.now();
    final int sessionCount = 3 + rand.nextInt(4); // 3-6 sessions
    return List.generate(sessionCount, (i) {
      final daysAgo = 1 + rand.nextInt(10) + i * 2;
      final date = now.subtract(Duration(days: daysAgo));
      final kwh = 8.0 + rand.nextDouble() * 10.0; // 8-18 kWh
      final co2 = kwh * (0.6 + rand.nextDouble() * 0.4); // 0.6-1.0 kg/kWh
      return ChargingSessionModel(
        id: '${vehicleId}_$i',
        reservationId: 'r${i + 1}',
        checkedInAt: date,
        energyConsumedKwh: double.parse(kwh.toStringAsFixed(2)),
        co2SavedKg: double.parse(co2.toStringAsFixed(2)),
      );
    });
  }
}
