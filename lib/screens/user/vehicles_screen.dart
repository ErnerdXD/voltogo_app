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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
      ),
      body: vehiclesAsync.when(
        data: (vehicles) => vehicles.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No vehicles added yet.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/profile/vehicles/add'),
                child: const Text('Add Your First EV'),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];

            // WRAP THE CARD IN INKWELL FOR NAVIGATION
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Navigate to edit screen and pass the vehicle object as 'extra'
                  context.push('/profile/vehicles/edit', extra: vehicle);
                },
                child: VehicleCard(
                  vehicle: vehicle,
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Vehicle'),
                        content: const Text('Are you sure you want to remove this vehicle?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(vehicleProvider.notifier).deleteVehicle(vehicle.id);
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
          ? FloatingActionButton(
        onPressed: () => context.push('/profile/vehicles/add'),
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}