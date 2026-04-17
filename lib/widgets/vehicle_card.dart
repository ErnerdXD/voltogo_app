import 'package:flutter/material.dart';
import 'package:voltogo_app/models/vehicle_model.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.vehicle,
    this.onDelete,
    super.key,
  });

  final VehicleModel vehicle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.electric_car),
        ),
        title: Text('${vehicle.brand ?? ''} ${vehicle.model ?? ''}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate: ${vehicle.plateNumber ?? 'N/A'}'),
            Text('Plug: ${vehicle.plugType ?? 'N/A'}'),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
