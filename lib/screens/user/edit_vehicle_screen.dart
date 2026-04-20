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
  late final TextEditingController _plateController;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() { super.initState(); _plateController = TextEditingController(text: widget.vehicle.plateNumber ?? ''); }
  @override
  void dispose() { _plateController.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(vehicleProvider.notifier).updateVehicle(widget.vehicle.id, {'plate_number': _plateController.text.trim().toUpperCase()});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration updated successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)); context.pop(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating vehicle: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Vehicle', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: isDark ? 0 : 2,
                shadowColor: Colors.black12,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.directions_car, color: isDark ? Colors.blue[400] : Colors.blue[700])),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${widget.vehicle.brand ?? 'Unknown'} ${widget.vehicle.model ?? ''}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Row(children: [Icon(Icons.ev_station, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20), const SizedBox(width: 8), Text('${widget.vehicle.plugType ?? 'Unknown'}', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))])),
                          Expanded(child: Row(children: [Icon(Icons.battery_charging_full, color: isDark ? Colors.green[400] : Colors.green[600], size: 20), const SizedBox(width: 8), Text('${widget.vehicle.batteryCapacityKwh ?? '?'} kWh', style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('To change the hardware specifications, you must delete this vehicle and add a new one.', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: isDark ? 0 : 2,
                shadowColor: Colors.black12,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(labelText: 'License Plate Number', prefixIcon: const Icon(Icons.badge_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => v?.isEmpty ?? true ? 'Plate number is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}