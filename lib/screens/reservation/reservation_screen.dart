import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../providers/reservation_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/station_provider.dart';
import '../payment/payment_screen.dart';
import '../../models/reservation_model.dart';
import '../../widgets/qr_display.dart';
import 'package:voltogo_app/models/slot_model.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:go_router/go_router.dart';
import 'package:voltogo_app/services/supabase_service.dart';
import 'package:voltogo_app/models/payment_model.dart';

final pendingBookingStationProvider = StateProvider<Map<String, String>?>((ref) => null);

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  String? selectedVehicleId;
  bool _showPastReservations = false;
  Timer? _timer;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reservationProvider.notifier).fetchReservations();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
        _checkAndCleanupExpiries();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final Set<String> _isDeletingIds = {};

  void _checkAndCleanupExpiries() {
    final now = DateTime.now();
    for (final res in ref.read(reservationProvider).reservations) {
      if (res.status == 'to pay' &&
          res.createdAt != null &&
          !_isDeletingIds.contains(res.id)) {
        if (now.isAfter(
            res.createdAt!.toLocal().add(const Duration(minutes: 10)))) {
          _deletePermanently(res.id);
        }
      }
    }
  }

  Future<void> _deletePermanently(String id) async {
    if (_isDeletingIds.contains(id)) return;
    _isDeletingIds.add(id);
    try {
      await Supabase.instance.client.from('reservations').delete().eq('id', id);
      await ref.read(reservationProvider.notifier).fetchReservations();
    } catch (e) {
      debugPrint('Error deleting expired reservation: $e');
    } finally {
      _isDeletingIds.remove(id);
    }
  }

  String _getRemainingTime(ReservationModel res) {
    if (res.createdAt == null) return '10:00';
    final diff = res.createdAt!
        .toLocal()
        .add(const Duration(minutes: 10))
        .difference(DateTime.now());
    if (diff.isNegative) return '00:00';
    return '${diff.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _showCancelDialog(
      BuildContext context, String reservationId) async {
    String? selectedReason;
    bool isProcessing = false;
    final reasons = [
      'Changed my mind',
      'Found a better station',
      'Vehicle issue',
      'Wrong booking details',
      'Other'
    ];
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel Reservation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select reason for cancellation:'),
                const SizedBox(height: 12),
                ...reasons.map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedReason = reason),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? Colors.blue : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(reason),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed:
                isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Go Back')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: (isProcessing || selectedReason == null)
                  ? null
                  : () async {
                setDialogState(() => isProcessing = true);
                // Capture messenger before async gap
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(context);
                try {
                  await Supabase.instance.client
                      .from('reservations')
                      .update({
                    'status': 'cancelled',
                    'cancellation_reason': selectedReason,
                  }).eq('id', reservationId);
                  await ref
                      .read(reservationProvider.notifier)
                      .fetchReservations();
                  nav.pop();
                  messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Reservation cancelled.')));
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                } finally {
                  setDialogState(() => isProcessing = false);
                }
              },
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReservationDetailsDialog(
      BuildContext context, ReservationModel reservation) {
    showDialog(
      context: context,
      builder: (context) => ReservationDetailsDialog(reservation: reservation),
    );
  }

  void _showCreateReservationForm(
      BuildContext context, {
        required String slotId,         // real Supabase UUID
        required String stationName,
        String stationAddress = '',
        String connectorType = '',
        String connectorPrice = '',
        String connectorStatus = '',
        String slotCode = '',
      }) {
    final activeCount = ref
        .read(reservationProvider)
        .reservations
        .where((r) => r.status != 'cancelled')
        .length;
    if (activeCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum 4 active reservations allowed.')));
      return;
    }

    // Modal state variables (persist across rebuilds)
    final now = DateTime.now();
    DateTime selectedDate = now;
    int initialMinutes = (now.minute / 30).round() * 30;
    DateTime snappedNow = DateTime(now.year, now.month, now.day, now.hour, initialMinutes);
    if (snappedNow.isBefore(now)) {
      snappedNow = snappedNow.add(const Duration(minutes: 30));
    }
    TimeOfDay startTime = TimeOfDay.fromDateTime(snappedNow);
    TimeOfDay? endTime;
    bool isSaving = false;
    String? selectedVehicleIdLocal;
    double kwh = 1.0;
    String? compatibilityWarning;
    double calculatedFee = 0.0;
    int targetBattery = 100;
    int currentBattery = 50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer(builder: (context, ref, _) {
        final vehiclesAsync = ref.watch(vehicleProvider);
        return StatefulBuilder(builder: (context, setModalState) {
          TimeOfDay snapTime(TimeOfDay t) {
            int m = (t.minute / 30).round() * 30;
            if (m == 60) return TimeOfDay(hour: (t.hour + 1) % 24, minute: 0);
            return TimeOfDay(hour: t.hour, minute: m);
          }

          // Find selected vehicle and slot connector type
          final vehicles = vehiclesAsync.valueOrNull ?? [];
          VehicleModel? selectedVehicle;
          if (vehicles.isNotEmpty) {
            selectedVehicle = vehicles.firstWhere(
              (v) => v.id == (selectedVehicleIdLocal ?? selectedVehicleId),
              orElse: () => vehicles.first,
            );
          } else {
            selectedVehicle = null;
          }
          // Remove compatibility check: all vehicles are allowed
          compatibilityWarning = null;
          // Price per kWh
          double pricePerKwh = double.tryParse(connectorPrice) ?? 0.0;
          // Simulate current battery (random 1-30, fixed per modal open)
          int batteryCapacity = selectedVehicle?.batteryCapacityKwh ?? 30;
          int currentBatterySimulated = 1 + (selectedVehicle?.id.hashCode ?? DateTime.now().millisecondsSinceEpoch) % 30;
          // targetBattery is now a modal variable
          double kwhToCharge = ((targetBattery - currentBattery) * batteryCapacity / 100).clamp(0, batteryCapacity).toDouble();
          calculatedFee = pricePerKwh * kwhToCharge;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Create Reservation',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Station + slot info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.ev_station,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(stationName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ]),
                        if (stationAddress.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.grey, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(stationAddress,
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                        if (connectorType.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (slotCode.isNotEmpty)
                                _InfoChip(
                                    label: slotCode,
                                    icon: Icons.tag),
                              _InfoChip(
                                  label: connectorType,
                                  icon: Icons.cable),
                              if (connectorPrice.isNotEmpty)
                                _InfoChip(
                                    label: 'RM$connectorPrice / kWh',
                                    icon: Icons.bolt),
                              if (connectorStatus.isNotEmpty)
                                _InfoChip(
                                  label: connectorStatus,
                                  icon: Icons.circle,
                                  iconColor:
                                  connectorStatus == 'available'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Vehicle dropdown
                  vehiclesAsync.when(
                    data: (v) => DropdownButtonFormField<String>(
                      value: selectedVehicleIdLocal ?? selectedVehicleId,
                      items: v
                          .map((v) => DropdownMenuItem(
                          value: v.id,
                          child:
                          Text('${v.brand} ${v.model}')))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedVehicleIdLocal = val),
                      decoration: const InputDecoration(
                          labelText: 'Select Vehicle',
                          border: OutlineInputBorder()),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) =>
                    const Text('Error loading vehicles'),
                  ),
                  const SizedBox(height: 16),
                  // Show price per kWh for selected vehicle
                  if (selectedVehicle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Based on your car model (${selectedVehicle.brand ?? ''} ${selectedVehicle.model ?? ''}), your price per kWh is: RM${pricePerKwh.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  // Show current battery
                  if (selectedVehicle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Current battery: $currentBattery%',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  // Input: charge until
                  if (selectedVehicle != null)
                    TextFormField(
                      initialValue: targetBattery.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Charge until (%)',
                        border: OutlineInputBorder(),
                        helperText: 'Enter target battery level (min: current, max: 100)',
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        setModalState(() {
                          targetBattery = (parsed != null && parsed > currentBattery && parsed <= 100) ? parsed : currentBattery;
                          kwhToCharge = ((targetBattery - currentBattery) * batteryCapacity / 100).clamp(0, batteryCapacity).toDouble();
                          calculatedFee = pricePerKwh * kwhToCharge;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  // Fee summary
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Total Fee: RM ${calculatedFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // Suggest suitable charging hours message
                  if (selectedVehicle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                      child: Builder(
                        builder: (context) {
                          double chargingRate = 7.0;
                          if (connectorType.toLowerCase().contains('dc')) {
                            chargingRate = 50.0;
                          }
                          double hoursNeeded = 0;
                          if (chargingRate > 0) {
                            hoursNeeded = kwhToCharge / chargingRate;
                          }
                          double cappedHours = hoursNeeded.clamp(0, 4.0);
                          int hours = cappedHours.floor();
                          int minutes = ((cappedHours - hours) * 60).round();
                          String timeStr;
                          if (cappedHours < 0.5) {
                            timeStr = '< 30 minutes';
                          } else if (hours == 0) {
                            timeStr = '$minutes minutes';
                          } else {
                            timeStr = '$hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes minutes' : ''}'.trim();
                          }
                          String msg =
                              'Your vehicle has a ${batteryCapacity.toStringAsFixed(1)} kWh battery. Current: $currentBattery%. Target: $targetBattery%.\n'
                              'To reach your target, you need to charge ${kwhToCharge.toStringAsFixed(1)} kWh, which will take about $timeStr at ${chargingRate.toStringAsFixed(0)} kW.';
                          if (hoursNeeded > 4.0) {
                            msg += '\nNote: Max booking is 4 hours. You may not reach your target in one session.';
                          }
                          return Text(
                            msg,
                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                          );
                        },
                      ),
                    ),

                  // Date picker
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(
                                now.year, now.month, now.day),
                            lastDate:
                            now.add(const Duration(days: 1)),
                          );
                          if (d != null) {
                            setModalState(() => selectedDate = d);
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // Time pickers
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text('Start: ${startTime.format(context)}'),
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (t != null) {
                            final snapped = snapTime(t);
                            setModalState(() {
                              startTime = snapped;
                              // If endTime is null or now before/equal to start, auto-set to start+30min
                              if (endTime == null ||
                                  (endTime!.hour * 60 + endTime!.minute) <= (snapped.hour * 60 + snapped.minute)) {
                                final nextEnd = TimeOfDay(
                                  hour: (snapped.hour + ((snapped.minute + 30) ~/ 60)) % 24,
                                  minute: (snapped.minute + 30) % 60,
                                );
                                endTime = nextEnd;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_filled),
                        label: Text(endTime == null
                            ? 'Pick End'
                            : 'End: ${endTime!.format(context)}'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final t = await showTimePicker(
                            context: context,
                            initialTime: endTime ?? TimeOfDay(
                              hour: (startTime.hour + ((startTime.minute + 30) ~/ 60)) % 24,
                              minute: (startTime.minute + 30) % 60,
                            ),
                          );
                          if (t != null) {
                            final snapped = snapTime(t);
                            final startMinutes = startTime.hour * 60 + startTime.minute;
                            final endMinutes = snapped.hour * 60 + snapped.minute;
                            final diff = endMinutes - startMinutes;
                            if (diff < 30) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Minimum booking duration is 30 minutes.')),
                              );
                              return;
                            }
                            if (diff > 240) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Maximum booking duration is 4 hours.')),
                              );
                              return;
                            }
                            setModalState(() => endTime = snapped);
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Current battery slider
                  const Text('Current Battery Percentage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Slider(
                    value: currentBattery.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '$currentBattery%',
                    onChanged: (val) {
                      setModalState(() {
                        currentBattery = val.round();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white),
                      onPressed: isSaving || (compatibilityWarning != null)
                          ? null
                          : () async {
                        final vehicleIdToUse = selectedVehicleIdLocal ?? selectedVehicleId;
                        if (vehicleIdToUse == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a vehicle.')));
                          return;
                        }
                        if (endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please pick an end time.')));
                          return;
                        }
                        setModalState(() => isSaving = true);
                        // Capture context-dependent objects before async gap
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(reservationProvider.notifier).createReservation(
                            slotId: slotId,
                            vehicleId: vehicleIdToUse,
                            startTime: DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                startTime.hour,
                                startTime.minute),
                            endTime: DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                endTime!.hour,
                                endTime!.minute),
                            currentBattery: currentBattery,
                          );
                          // Get the latest reservation from provider state
                          final reservations = ref.read(reservationProvider).reservations;
                          if (reservations.isNotEmpty) {
                            final reservation = reservations.last;
                            nav.pop();
                            nav.push(
                              MaterialPageRoute(
                                builder: (context) => PaymentScreen(
                                  reservation: reservation,
                                  amount: (calculatedFee * 100).toInt(),
                                ),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Reservation failed. Please try again.')),
                            );
                          }
                        } catch (e) {
                          messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : const Text('Pay & Reserve'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }),
    );
  }

  void _showQRDialog(BuildContext context, String reservationId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Code'),
        content: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: QRDisplay(data: reservationId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationProvider);
    final activeRes = state.reservations.where((r) => r.status == 'active' || r.status == 'paid' || r.status == 'to pay').toList();
    final pastRes = state.reservations
        .where(
            (r) => r.status == 'cancelled' || r.status == 'completed')
        .toList();

    ref.listen(pendingBookingStationProvider, (prev, next) {
          if (next != null) {
            if (activeRes.length >= 4) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                  Text('Maximum 4 active reservations allowed.')));
            } else {
              _showCreateReservationForm(
                context,
                slotId: next['slotId']!,
                stationName: next['stationName']!,
                stationAddress: next['stationAddress'] ?? '',
                connectorType: next['connectorType'] ?? '',
                connectorPrice: next['connectorPrice'] ?? '',
                connectorStatus: next['connectorStatus'] ?? '',
                slotCode: next['slotCode'] ?? '',
              );
            }
            ref.read(pendingBookingStationProvider.notifier).state = null;
          }
        });

    return Scaffold(
      appBar: AppBar(title: const Text('My Reservations'), centerTitle: true),
      body: state.isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeRes.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No active reservations.')))
          else ...activeRes.map((res) {
            final isToPay = res.status == 'to pay';
            final isPaid = res.status == 'paid' || res.status == 'active';
            // Simulate price for now (replace with real value if available)
            final double price = 25.00 + (res.id.hashCode % 100) / 10.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Booking #${res.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(
                              isPaid ? 'PAID' : 'TO PAY',
                              style: TextStyle(
                                color: isPaid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'RM ${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isPaid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (res.startTime != null) ...[
                      Text('Date: ${res.startTime!.day}/${res.startTime!.month}/${res.startTime!.year}'),
                      Text('Time: ${res.startTime!.hour}:${res.startTime!.minute.toString().padLeft(2, '0')} - ${res.endTime?.hour}:${res.endTime?.minute.toString().padLeft(2, '0')}'),
                    ],
                    if (isToPay) ...[
                      const SizedBox(height: 8),
                      Text('Expires in: \\${_getRemainingTime(res)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isPaid)
                          ElevatedButton(
                            onPressed: () => _showQRDialog(context, res.id),
                            child: const Text('View Details'),
                          ),
                        if (isToPay) ...[
                          ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen(reservation: res, amount: 1000))),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text('Pay Now'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _showCancelDialog(context, res.id),
                          ),
                        ]
                      ],
                    )
                  ],
                ),
              ),
            );
          }),
          if (pastRes.isNotEmpty) ...[
            const Divider(height: 32),
            Center(
              child: TextButton.icon(
                icon: Icon(_showPastReservations ? Icons.expand_less : Icons.history),
                label: Text(_showPastReservations ? 'Hide History' : 'View Previous Reservations'),
                onPressed: () => setState(() => _showPastReservations = !_showPastReservations),
              ),
            ),
            if (_showPastReservations)
              ...pastRes.map((res) => Card(
                    color: Colors.grey[50],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Booking #${res.id.substring(0, 8)}', style: const TextStyle(color: Colors.grey)),
                      subtitle: Text('Status: ${res.status}', style: const TextStyle(color: Colors.redAccent)),
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  const _InfoChip(
      {required this.label, required this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label,
              style:
              TextStyle(fontSize: 12, color: Colors.grey[800])),
        ],
      ),
    );
  }
}

// ── Reservation Details Dialog ────────────────────────────────────────────────
class ReservationDetailsDialog extends ConsumerWidget {
  final ReservationModel reservation;
  const ReservationDetailsDialog(
      {super.key, required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(stationsProvider).when(
      data: (stations) {
        SlotModel? slot;
        StationModel? station;
        outer:
        for (final s in stations) {
          for (final sl in s.slots ?? []) {
            if (sl.id == reservation.slotId) {
              slot = sl;
              station = s;
              break outer;
            }
          }
        }

        if (station == null) {
          return AlertDialog(
            title: const Text('Reservation Details'),
            content:
            const Text('Station not found.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          );
        }

        return AlertDialog(
          title: const Text('Reservation Details'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 340, // Prevent overflow on small screens
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      width: 180, // Limit QR code width
                      child: QRDisplay(data: reservation.id),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (station.name != null) ...[
                    Row(children: [
                      const Icon(Icons.ev_station,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(station.name!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (station.address != null) ...[
                    Row(children: [
                      const Icon(Icons.location_on,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(station.address!)),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (slot != null) ...[
                    Row(children: [
                      const Icon(Icons.cable,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${slot.slotCode ?? ''} · ${slot.connectorType ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (slot?.pricePerKwh != null) ...[
                    Row(children: [
                      const Icon(Icons.bolt,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                          'RM${slot!.pricePerKwh!.toStringAsFixed(2)} per kWh'),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Show on Map'),
                      onPressed: () {
                        Navigator.pop(context);
                        context.go(
                            '/map?highlightStationId=${station?.id}');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        );
      },
      loading: () =>
      const Center(child: CircularProgressIndicator()),
      error: (e, _) => AlertDialog(
        title: const Text('Error'),
        content: Text('$e'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }
}

