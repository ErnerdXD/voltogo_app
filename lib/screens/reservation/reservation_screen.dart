import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reservation_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/station_provider.dart';

final pendingBookingStationProvider = StateProvider<String?>((ref) => null);

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  String? selectedSlotId;
  String? selectedVehicleId;

  void _showCreateReservationForm(BuildContext context, {String? preselectedStationName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final vehiclesAsync = ref.watch(vehicleProvider);
        final stationsAsync = ref.watch(stationsProvider);
        List<Map<String, String>> availableSlots = [];
        Map<String, dynamic>? selectedSlotDetails;
        if (stationsAsync is AsyncData) {
          final stations = stationsAsync.value;
          if (stations != null) {
            for (final station in stations) {
              if (station.slots != null) {
                for (final slot in station.slots!) {
                  if (slot.status == 'available') {
                    final slotMap = {
                      'id': slot.id,
                      'label': '${station.name ?? ''} - ${slot.slotCode ?? slot.id}',
                      'price_per_kwh': slot.pricePerKwh?.toString() ?? '',
                      'connector_type': slot.connectorType ?? '',
                      'station_name': station.name ?? '',
                    };
                    availableSlots.add(slotMap);
                  }
                }
              }
            }
          }
        }
        String? modalSelectedVehicleId = selectedVehicleId;
        String? modalSelectedSlotId = selectedSlotId;
        // 3. Try to auto-select a slot that belongs to the tapped station
        if (modalSelectedSlotId == null && preselectedStationName != null) {
          final matchingSlots = availableSlots.where(
                  (s) => s['station_name'] == preselectedStationName
          );
          if (matchingSlots.isNotEmpty) {
            modalSelectedSlotId = matchingSlots.first['id'];
          }
        }
        DateTime? selectedDate;
        TimeOfDay? selectedStartTime;
        TimeOfDay? selectedEndTime;
        String? selectedPaymentMethod;
        final formKey = GlobalKey<FormState>();
        double? slotPricePerKwh;
        String? slotConnectorType;
        String? slotStationName;
        // Helper to update slot details
        void updateSlotDetails(String? slotId) {
          final slot = availableSlots.firstWhere(
            (s) => s['id'] == slotId,
            orElse: () => {},
          );
          slotPricePerKwh = double.tryParse(slot['price_per_kwh'] ?? '');
          slotConnectorType = slot['connector_type'];
          slotStationName = slot['station_name'];
        }
        if (modalSelectedSlotId != null) {
          updateSlotDetails(modalSelectedSlotId);
        }
        // Helper to pick date
        Future<void> pickDate() async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: ctx,
            initialDate: selectedDate ?? now,
            firstDate: now,
            lastDate: now.add(const Duration(days: 30)),
          );
          if (picked != null) {
            selectedDate = picked;
          }
        }
        // Helper to pick start time
        Future<void> pickStartTime() async {
          final picked = await showTimePicker(
            context: ctx,
            initialTime: selectedStartTime ?? TimeOfDay.now(),
          );
          if (picked != null) {
            selectedStartTime = picked;
          }
        }
        // Helper to pick end time
        Future<void> pickEndTime() async {
          final picked = await showTimePicker(
            context: ctx,
            initialTime: selectedEndTime ?? (selectedStartTime ?? TimeOfDay.now()),
          );
          if (picked != null) {
            selectedEndTime = picked;
          }
        }
        // Helper to calculate estimated price (simple: price per hour)
        double? getEstimatedPrice() {
          if (slotPricePerKwh == null || selectedStartTime == null || selectedEndTime == null) return null;
          final startMinutes = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
          final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
          final durationMinutes = endMinutes - startMinutes;
          if (durationMinutes <= 0) return null;
          // For demo: assume 7kWh per hour charging rate
          double kwh = (durationMinutes / 60.0) * 7.0;
          return slotPricePerKwh! * kwh;
        }
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Create Reservation',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      // Vehicle dropdown
                      vehiclesAsync.when(
                        data: (vehicles) => DropdownButtonFormField<String>(
                          value: modalSelectedVehicleId,
                          hint: const Text('Select Vehicle'),
                          items: vehicles.map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text('${v.brand ?? ''} ${v.model ?? ''} (${v.plateNumber ?? ''})'),
                          )).toList(),
                          onChanged: (val) => setModalState(() => modalSelectedVehicleId = val),
                          validator: (val) => val == null ? 'Please select a vehicle' : null,
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Failed to load vehicles: $e'),
                      ),
                      const SizedBox(height: 16),
                      // Slot dropdown
                      DropdownButtonFormField<String>(
                        value: modalSelectedSlotId,
                        hint: const Text('Select Slot'),
                        items: availableSlots.map((slot) => DropdownMenuItem(
                          value: slot['id'],
                          child: Text(slot['label'] ?? slot['id']!),
                        )).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            modalSelectedSlotId = val;
                            updateSlotDetails(val);
                          });
                        },
                        validator: (val) => val == null ? 'Please select a slot' : null,
                      ),
                      if (modalSelectedSlotId != null && slotPricePerKwh != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.ev_station, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Text('Station: $slotStationName'),
                              const SizedBox(width: 16),
                              Text('Type: $slotConnectorType'),
                              const SizedBox(width: 16),
                              Text('RM ${slotPricePerKwh!.toStringAsFixed(2)}/kWh'),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          await pickDate();
                          setModalState(() {});
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            controller: TextEditingController(
                              text: selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                                  : '',
                            ),
                            validator: (_) => selectedDate == null ? 'Please select a date' : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Start time picker
                      GestureDetector(
                        onTap: () async {
                          await pickStartTime();
                          setModalState(() {});
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Start Time',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            controller: TextEditingController(
                              text: selectedStartTime != null
                                  ? selectedStartTime!.format(context)
                                  : '',
                            ),
                            validator: (_) => selectedStartTime == null ? 'Please select a start time' : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // End time picker
                      GestureDetector(
                        onTap: () async {
                          await pickEndTime();
                          setModalState(() {});
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'End Time',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            controller: TextEditingController(
                              text: selectedEndTime != null
                                  ? selectedEndTime!.format(context)
                                  : '',
                            ),
                            validator: (_) {
                              if (selectedEndTime == null) return 'Please select an end time';
                              if (selectedStartTime != null && selectedEndTime != null) {
                                final startMinutes = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
                                final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
                                if (endMinutes <= startMinutes) {
                                  return 'End time must be after start time';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Estimated price
                      if (getEstimatedPrice() != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_money, color: Colors.amber),
                              const SizedBox(width: 8),
                              Text('Estimated: RM ${getEstimatedPrice()!.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      // Payment method
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'card', child: Text('Credit/Debit Card')),
                          DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                        ],
                        onChanged: (val) => setModalState(() => selectedPaymentMethod = val),
                        validator: (val) => val == null ? 'Please select a payment method' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? false) {
                              // Compose start and end DateTime
                              final startDateTime = DateTime(
                                selectedDate!.year,
                                selectedDate!.month,
                                selectedDate!.day,
                                selectedStartTime!.hour,
                                selectedStartTime!.minute,
                              );
                              final endDateTime = DateTime(
                                selectedDate!.year,
                                selectedDate!.month,
                                selectedDate!.day,
                                selectedEndTime!.hour,
                                selectedEndTime!.minute,
                              );
                              await ref.read(reservationProvider.notifier).createReservation(
                                slotId: modalSelectedSlotId!,
                                vehicleId: modalSelectedVehicleId!,
                                startTime: startDateTime,
                                endTime: endDateTime,
                              );
                              final error = ref.read(reservationProvider).error;
                              if (error == null) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reservation created!')),
                                );
                                setState(() {
                                  selectedSlotId = null;
                                  selectedVehicleId = null;
                                });
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Failed: $error')),
                                );
                              }
                            }
                          },
                          child: const Text('Pay & Reserve', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Fetch reservations on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reservationProvider.notifier).fetchReservations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationProvider);
    final vehiclesAsync = ref.watch(vehicleProvider);
    final stationsAsync = ref.watch(stationsProvider);

    // ADD THIS LISTENER: It listens for a signal from the Map tab
    ref.listen<String?>(pendingBookingStationProvider, (previous, next) {
      if (next != null) {
        // Wait for the tab switch animation to finish, then show the form
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCreateReservationForm(context, preselectedStationName: next);
          // Clear the signal so it doesn't keep popping up every time you rebuild
          ref.read(pendingBookingStationProvider.notifier).state = null;
        });
      }
    });
    // Extract available slots from stations
    List<Map<String, String>> availableSlots = [];
    if (stationsAsync is AsyncData) {
      final stations = stationsAsync.value;
      if (stations != null) {
        for (final station in stations) {
          if (station.slots != null) {
            for (final slot in station.slots!) {
              if (slot.status == 'available') {
                availableSlots.add({
                  'id': slot.id,
                  'label': '${station.name ?? ''} - ${slot.slotCode ?? slot.id}',
                });
              }
            }
          }
        }
      }
    }
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (state.error != null)
            Center(child: Text('Error: \\${state.error}')),
          if (!state.isLoading && state.reservations.isEmpty)
            const Center(child: Text('No reservations found.')),
          if (!state.isLoading && state.reservations.isNotEmpty)
            ...state.reservations.map((reservation) => Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('Reservation ID: \\${reservation.id}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reservation.startTime != null && reservation.endTime != null)
                      Text('Time: \\${reservation.startTime} - \\${reservation.endTime}'),
                    if (reservation.status != null)
                      Text('Status: \\${reservation.status}'),
                  ],
                ),
                trailing: reservation.status == 'active'
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: state.isLoading
                            ? null
                            : () => ref.read(reservationProvider.notifier).cancelReservation(reservation.id),
                      )
                    : null,
              ),
            )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateReservationForm(context),
        child: const Icon(Icons.add),
        tooltip: 'Create Reservation',
      ),
    );
  }
}
