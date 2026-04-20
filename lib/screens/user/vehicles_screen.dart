import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/providers/vehicle_provider.dart';
import 'package:voltogo_app/widgets/vehicle_card.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehicleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text('My Garage', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: vehiclesAsync.when(
        data: (vehicles) => vehicles.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.directions_car, size: 80, color: isDark ? Colors.blue[400] : Colors.blue[300]),
                ),
                const SizedBox(height: 24),
                Text('Your Garage is Empty', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text('Add your electric vehicle to ensure compatibility with charging stations.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/profile/vehicles/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First EV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/profile/vehicles/edit', extra: vehicle),
                child: VehicleCard(
                  vehicle: vehicle,
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Vehicle'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        content: const Text('Are you sure you want to remove this vehicle from your garage?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete')
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await ref.read(vehicleProvider.notifier).deleteVehicle(vehicle.id);
                      } catch (e) {
                        final errorMsg = e.toString().contains('referenced by existing reservations')
                            ? 'This vehicle cannot be deleted because it is referenced by an active reservation.'
                            : 'Failed to delete vehicle: $e';
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(title: const Text('Cannot Delete'), content: Text(errorMsg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: vehiclesAsync.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
        onPressed: () => context.push('/profile/vehicles/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add EV'),
        backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700],
        foregroundColor: Colors.white,
      )
          : null,
    );
  }
}