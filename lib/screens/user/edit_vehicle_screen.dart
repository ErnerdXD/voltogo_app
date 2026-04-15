import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:voltogo_app/providers/vehicle_provider.dart';

class EditVehicleScreen extends ConsumerStatefulWidget {
  final VehicleModel vehicle;

  const EditVehicleScreen({super.key, required this.vehicle});

  @override
  ConsumerState<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends ConsumerState<EditVehicleScreen> {
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _plateController;
  late final TextEditingController _capacityController;
  late String _selectedPlugType;

  static const _plugTypes = ['Type 2', 'CCS2', 'CHAdeMO', 'Tesla'];
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.vehicle.brand ?? '');
    _modelController = TextEditingController(text: widget.vehicle.model ?? '');
    _plateController = TextEditingController(text: widget.vehicle.plateNumber ?? '');
    _capacityController = TextEditingController(
      text: widget.vehicle.batteryCapacityKwh?.toString() ?? '',
    );
    _selectedPlugType = widget.vehicle.plugType ?? 'Type 2';
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(vehicleProvider.notifier).updateVehicle(
        widget.vehicle.id,
        {
          'brand': _brandController.text.trim(),
          'model': _modelController.text.trim(),
          'plate_number': _plateController.text.trim(),
          'plug_type': _selectedPlugType,
          'battery_capacity_kwh': int.tryParse(_capacityController.text.trim()),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating vehicle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Vehicle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand (e.g. Tesla, BYD)',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Brand is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model (e.g. Model 3, Atto 3)',
                  prefixIcon: Icon(Icons.info),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Model is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(
                  labelText: 'Plate Number',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Plate number is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Battery Capacity (kWh)',
                  prefixIcon: Icon(Icons.battery_charging_full),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              const Text('Plug Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
               DropdownButtonFormField<String>(
                 initialValue: _selectedPlugType,
                 items: _plugTypes
                     .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                     .toList(),
                 onChanged: (v) => setState(() => _selectedPlugType = v!),
                 decoration: const InputDecoration(
                   border: OutlineInputBorder(),
                   prefixIcon: Icon(Icons.power),
                 ),
               ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


