import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../providers/reservation_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../providers/station_provider.dart';
import '../payment/payment_screen.dart';
import '../../models/reservation_model.dart';
import 'package:voltogo_app/models/slot_model.dart';
import 'package:voltogo_app/models/station_model.dart';
import 'package:voltogo_app/models/vehicle_model.dart';
import 'package:voltogo_app/models/payment_model.dart';
import 'package:voltogo_app/services/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr;

final pendingBookingStationProvider = StateProvider<Map<String, String>?>((ref) => null);

final paymentsProvider = FutureProvider<List<PaymentModel>>((ref) async {
  return SupabaseService().getPaymentsForUser();
});

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  Timer? _timer;
  final Set<String> _isDeletingIds = {};
  int _selectedTabIndex = 0;
  final List<String> _tabLabels = [
    'All', 'To Pay', 'Paid', 'Cancelled', 'Refund'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reservationProvider.notifier).fetchReservations();
      _checkAndCleanupExpiries();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkAndCleanupExpiries() {
    final now = DateTime.now();
    for (final res in ref.read(reservationProvider).reservations) {
      if (res.status == 'to pay' &&
          res.createdAt != null &&
          !_isDeletingIds.contains(res.id)) {
        if (now.isAfter(
            res.createdAt!.toLocal().add(const Duration(minutes: 10)))) {
          _softExpire(res.id);
        }
      }
    }
  }

  Future<void> _softExpire(String id) async {
    if (_isDeletingIds.contains(id)) return;
    _isDeletingIds.add(id);
    try {
      await Supabase.instance.client
          .from('reservations')
          .update({'status': 'expired'})
          .eq('id', id);
      await ref.read(reservationProvider.notifier).fetchReservations();
    } catch (e) {
      debugPrint('Error expiring reservation: $e');
    } finally {
      _isDeletingIds.remove(id);
    }
  }

  List<ReservationModel> _filteredReservations(List<ReservationModel> reservations) {
    switch (_selectedTabIndex) {
      case 1:
        return reservations.where((r) => r.status == 'to pay').toList();
      case 2:
        return reservations.where((r) => r.status == 'paid' || r.status == 'active').toList();
      case 3:
        return reservations.where((r) => r.status == 'cancelled').toList();
      case 4:
        return reservations.where((r) => r.status == 'refund').toList();
      default:
        return reservations;
    }
  }

  // ── Cancel dialog ─────────────────────────────────────────────────────────
  Future<void> _showCancelDialog(BuildContext context, String reservationId) {
    String? selectedReason;
    bool isProcessing = false;
    final reasons = [
      'Changed my mind',
      'Found a better station',
      'Vehicle issue',
      'Wrong booking details',
      'Other',
    ];
    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Cancel Reservation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select reason for cancellation:'),
                const SizedBox(height: 12),
                ...reasons.map((reason) {
                  final sel = selectedReason == reason;
                  return InkWell(
                    onTap: () => setS(() => selectedReason = reason),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(
                          sel ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: sel ? Colors.blue : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(reason),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: (isProcessing || selectedReason == null)
                  ? null
                  : () async {
                setS(() => isProcessing = true);
                final messenger = ScaffoldMessenger.of(ctx);
                final nav = Navigator.of(ctx);
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
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Reservation cancelled.')));
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                } finally {
                  setS(() => isProcessing = false);
                }
              },
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRefundDialog(BuildContext context, String reservationId) async {
    String? refundReason;
    bool isProcessing = false;
    final reasons = [
      'Change of plans',
      'Incorrect booking',
      'Found a better price',
      'Other',
    ];
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Request Refund'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select reason for refund:'),
                const SizedBox(height: 12),
                ...reasons.map((reason) {
                  final sel = refundReason == reason;
                  return InkWell(
                    onTap: () => setS(() => refundReason = reason),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(
                          sel ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: sel ? Colors.blue : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(reason),
                      ]),
                    ),
                  );
                }),
                if (refundReason == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter reason',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setS(() => refundReason = val),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: (isProcessing || refundReason == null || refundReason!.isEmpty)
                  ? null
                  : () async {
                setS(() => isProcessing = true);
                final messenger = ScaffoldMessenger.of(ctx);
                final nav = Navigator.of(ctx);
                            try {
                              await Supabase.instance.client
                                  .from('reservations')
                                  .update({
                                'status': 'refund',
                              }).eq('id', reservationId);
                              await ref
                                  .read(reservationProvider.notifier)
                                  .fetchReservations();
                              nav.pop();
                              messenger.showSnackBar(SnackBar(
                                  content: Text('Refund requested. Reason: '
                                      '${refundReason ?? "No reason provided"}')));
                            } catch (e) {
                              messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            } finally {
                              setS(() => isProcessing = false);
                            }
              },
              child: const Text('Confirm Refund'),
            ),
          ],
        ),
      ),
    );
  }

  // ── QR dialog ─────────────────────────────────────────────────────────────
  void _showQRDialog(BuildContext context, ReservationModel res) {
    final qrUrl =
        'https://ernerdxd.github.io/voltogo_app/web/charge.html?res_id=${res.id}';
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        pageBuilder: (ctx, animation, _) => FadeTransition(
          opacity: animation,
          child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Scan to Track Charging',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Point another phone at this code',
                        style: TextStyle(color: Colors.white60, fontSize: 14)),
                    const SizedBox(height: 40),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: qr.QrImageView(
                          data: qrUrl,
                          version: qr.QrVersions.auto,
                          size: MediaQuery.of(ctx).size.width * 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('Tap anywhere to close',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Details bottom sheet ──────────────────────────────────────────────────
  void _showDetailsSheet(BuildContext context, ReservationModel res) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => ReservationDetailsSheet(reservation: res),
    );
  }

  // ── Create reservation form ───────────────────────────────────────────────
  void _showCreateReservationForm(
      BuildContext context, {
        required String slotId,
        required String stationName,
        String stationAddress = '',
        String connectorType = '',
        String connectorPrice = '',
        String connectorStatus = '',
        String slotCode = '',
      }) {
    final now = DateTime.now();
    DateTime selectedDate = now;
    int initialMinutes = (now.minute / 30).round() * 30;
    DateTime snappedNow =
    DateTime(now.year, now.month, now.day, now.hour, initialMinutes);
    if (snappedNow.isBefore(now)) {
      snappedNow = snappedNow.add(const Duration(minutes: 30));
    }
    TimeOfDay startTime = TimeOfDay.fromDateTime(snappedNow);
    TimeOfDay? endTime;
    bool isSaving = false;
    String? selectedVehicleIdLocal;
    int targetBattery = 100;

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
            if (m == 60) {
              return TimeOfDay(hour: (t.hour + 1) % 24, minute: 0);
            }
            return TimeOfDay(hour: t.hour, minute: m);
          }

          final vehicles = vehiclesAsync.valueOrNull ?? [];
          VehicleModel? selectedVehicle;
          if (vehicles.isNotEmpty) {
            try {
              selectedVehicle =
                  vehicles.firstWhere((v) => v.id == selectedVehicleIdLocal);
            } catch (_) {
              selectedVehicle = vehicles.first;
            }
          }

          final batteryCapacity = selectedVehicle?.batteryCapacityKwh ?? 40;
          final currentBattery =
              1 + ((selectedVehicle?.id.hashCode ?? 0).abs() % 30);
          final pricePerKwh = double.tryParse(connectorPrice) ?? 0.0;
          final kwhToCharge =
          ((targetBattery - currentBattery) * batteryCapacity / 100)
              .clamp(0.0, batteryCapacity.toDouble());
          final calculatedFee = pricePerKwh * kwhToCharge;

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
                    child: Text('Create Reservation',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
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
                                      fontSize: 15))),
                        ]),
                        if (stationAddress.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.grey, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(stationAddress,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13))),
                            ],
                          ),
                        ],
                        if (connectorType.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            if (slotCode.isNotEmpty)
                              _InfoChip(label: slotCode, icon: Icons.tag),
                            _InfoChip(label: connectorType, icon: Icons.cable),
                            if (connectorPrice.isNotEmpty)
                              _InfoChip(
                                  label: 'RM$connectorPrice / kWh',
                                  icon: Icons.bolt),
                            if (connectorStatus.isNotEmpty)
                              _InfoChip(
                                label: connectorStatus,
                                icon: Icons.circle,
                                iconColor: connectorStatus == 'available'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  vehiclesAsync.when(
                    data: (v) => DropdownButtonFormField<String>(
                      initialValue: selectedVehicleIdLocal ??
                          (v.isNotEmpty ? v.first.id : null),
                      items: v
                          .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.brand} ${v.model}')))
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedVehicleIdLocal = val),
                      decoration: const InputDecoration(
                          labelText: 'Select Vehicle',
                          border: OutlineInputBorder()),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => const Text('Error loading vehicles'),
                  ),
                  const SizedBox(height: 12),
                  if (selectedVehicle != null) ...[
                    Row(children: [
                      const Icon(Icons.battery_charging_full,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Current battery: ~$currentBattery%  ·  Capacity: ${batteryCapacity}kWh',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: targetBattery.toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Charge until (%)',
                        border: const OutlineInputBorder(),
                        helperText:
                        'Current: $currentBattery% → target (max 100%)',
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        setModalState(() {
                          targetBattery = (parsed != null &&
                              parsed > currentBattery &&
                              parsed <= 100)
                              ? parsed
                              : currentBattery + 1;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.receipt_long,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '~${kwhToCharge.toStringAsFixed(1)} kWh  ·  Est. RM ${calculatedFee.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                            firstDate:
                            DateTime(now.year, now.month, now.day),
                            lastDate: now.add(const Duration(days: 1)),
                          );
                          if (d != null) {
                            setModalState(() => selectedDate = d);
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text('Start: ${startTime.format(context)}'),
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: startTime);
                          if (t != null) {
                            final snapped = snapTime(t);
                            setModalState(() {
                              startTime = snapped;
                              if (endTime == null ||
                                  (endTime!.hour * 60 + endTime!.minute) <=
                                      (snapped.hour * 60 + snapped.minute)) {
                                endTime = TimeOfDay(
                                  hour: (snapped.hour +
                                      (snapped.minute + 30) ~/ 60) %
                                      24,
                                  minute: (snapped.minute + 30) % 60,
                                );
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
                            initialTime: endTime ??
                                TimeOfDay(
                                  hour: (startTime.hour +
                                      (startTime.minute + 30) ~/ 60) %
                                      24,
                                  minute: (startTime.minute + 30) % 60,
                                ),
                          );
                          if (t != null) {
                            final snapped = snapTime(t);
                            final diff =
                                (snapped.hour * 60 + snapped.minute) -
                                    (startTime.hour * 60 + startTime.minute);
                            if (diff < 30) {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Minimum booking duration is 30 minutes.')));
                              return;
                            }
                            if (diff > 240) {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Maximum booking duration is 4 hours.')));
                              return;
                            }
                            setModalState(() => endTime = snapped);
                          }
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white),
                       onPressed: isSaving
                           ? null
                           : () async {
                         final vehicleId = selectedVehicleIdLocal ??
                             (vehicles.isNotEmpty
                                 ? vehicles.first.id
                                 : null);
                         if (vehicleId == null) {
                           ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(
                                   content:
                                   Text('Please select a vehicle.')));
                           return;
                         }
                         if (endTime == null) {
                           ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(
                                   content: Text(
                                       'Please pick an end time.')));
                           return;
                         }
                         // Ensure endTime is in the future
                         final nowDT = DateTime.now();
                         final startDT = DateTime(
                             selectedDate.year,
                             selectedDate.month,
                             selectedDate.day,
                             startTime.hour,
                             startTime.minute);
                         final endDT = DateTime(
                             selectedDate.year,
                             selectedDate.month,
                             selectedDate.day,
                             endTime!.hour,
                             endTime!.minute);
                         if (!endDT.isAfter(nowDT)) {
                           ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text(
                                   'End time must be in the future. Please pick a valid end time.')));
                           return;
                         }
                         debugPrint('DEBUG: Creating reservation with startTime: '
                             '[33m[1m[4m[7m'
                             '[0m' + startDT.toIso8601String() + ', endTime: ' + endDT.toIso8601String() + ', now: ' + nowDT.toIso8601String());
                         setModalState(() => isSaving = true);
                         final nav = Navigator.of(context);
                         final messenger = ScaffoldMessenger.of(context);
                         try {
                            final reservation = await ref
                                .read(reservationProvider.notifier)
                                .createReservation(
                              slotId: slotId,
                              vehicleId: vehicleId,
                              startTime: startDT,
                              endTime: endDT,
                              currentBattery: currentBattery,
                              targetBattery: targetBattery,
                            );
                            if (reservation != null) {
                              // Refresh stationsProvider so slot/station availability updates in UI
                              ref.refresh(stationsProvider);
                              nav.pop();
                              await nav.push(MaterialPageRoute(
                                builder: (_) => PaymentScreen(
                                  reservation: reservation,
                                  amount: (calculatedFee * 100)
                                      .toInt()
                                      .clamp(100, 999999),
                                ),
                              ));
                            } else {
                              messenger.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Reservation failed. Please try again.')));
                            }
                         } catch (e) {
                           messenger.showSnackBar(
                               SnackBar(content: Text('Error: $e')));
                         } finally {
                           setModalState(() => isSaving = false);
                         }
                       },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Pay & Reserve'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      }), // End of Consumer
    ); // End of showModalBottomSheet
  } // End of _showCreateReservationForm

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationProvider);
    final stationsAsync = ref.watch(stationsProvider);
    final now = DateTime.now();
    final filteredRes = _filteredReservations(state.reservations)
        .where((res) {
          if (res.status == 'to pay' && res.createdAt != null) {
            final expiry = res.createdAt!.toLocal().add(const Duration(minutes: 10));
            return now.isBefore(expiry);
          }
          return true;
        })
        .toList();
    ref.listen<Map<String, String>?>(pendingBookingStationProvider,
            (prev, next) {
          if (next != null) {
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
            ref.read(pendingBookingStationProvider.notifier).state = null;
          }
        });

    return Scaffold(
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              'My reservation',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: _tabLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) => ChoiceChip(
                  label: Text(_tabLabels[idx]),
                  selected: _selectedTabIndex == idx,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedTabIndex = idx);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredRes.isEmpty)
            const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No reservations found.')),
            )
          else
            ...filteredRes.map((res) {
               final isToPay = res.status == 'to pay';
               final isPaid = res.status == 'paid' || res.status == 'active';
               // Determine if QR code should be shown
               bool showQrCode = false;
               if (isPaid) {
                 final endedStatuses = {'cancelled', 'refund', 'completed', 'expired'};
                 final status = res.status?.toLowerCase() ?? '';
                 final isEnded = endedStatuses.contains(status) ||
                   (res.endTime != null && (res.endTime!.isUtc ? res.endTime!.toLocal() : res.endTime!).isBefore(DateTime.now()));
                 showQrCode = !isEnded;
               }
              StationModel? station;
              SlotModel? slot;
              final stations = stationsAsync.maybeWhen(
                  data: (s) => s, orElse: () => []);
              outer:
              for (final s in stations) {
                for (final sl in s.slots ?? []) {
                  if (sl.id == res.slotId) {
                    slot = sl;
                    station = s;
                    break outer;
                  }
                }
              }

              String countdownText = '';
              Color countdownColor = Colors.orange;
              if (isToPay && res.createdAt != null) {
                  final expiry = res.createdAt!.isUtc
                      ? res.createdAt!.toLocal().add(const Duration(minutes: 10))
                      : res.createdAt!.add(const Duration(minutes: 10));
                  final diff = expiry.difference(DateTime.now());
                  if (diff.isNegative) {
                    countdownText = 'Expired';
                    countdownColor = Colors.red;
                  } else {
                    final minutes = diff.inMinutes;
                    final seconds = diff.inSeconds.remainder(60);
                    countdownText = 'Time left to pay: '
                        '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
                    countdownColor = minutes < 1 ? Colors.red : Colors.orange;
                  }
                } else if (res.endTime != null) {
                                                  // Debug output for diagnosis
                                                  debugPrint('DEBUG: res.endTime: \\${res.endTime}');
                                                  debugPrint('DEBUG: res.endTime!.isUtc: \\${res.endTime!.isUtc}');
                                                  debugPrint('DEBUG: res.endTime!.toIso8601String(): \\${res.endTime!.toIso8601String()}');
                                                  debugPrint('DEBUG: DateTime.now(): \\${DateTime.now()}');
                                                  debugPrint('DEBUG: DateTime.now().toIso8601String(): \\${DateTime.now().toIso8601String()}');
                  final endTime = res.endTime;
                  final localEndTime = endTime!.isUtc ? endTime.toLocal() : endTime;
                  final diff = localEndTime.difference(DateTime.now());
                  if (diff.isNegative) {
                    countdownText = 'Session ended';
                    countdownColor = Colors.red;
                  } else {
                    final hours = diff.inHours;
                    final minutes = diff.inMinutes.remainder(60);
                    final seconds = diff.inSeconds.remainder(60);
                    if (hours > 0) {
                      countdownText =
                          'Time left: ${hours}h ${minutes.toString().padLeft(2, '0')}m';
                    } else {
                      countdownText =
                          'Time left: ${minutes}m ${seconds.toString().padLeft(2, '0')}s';
                    }
                    countdownColor = diff.inMinutes < 15 ? Colors.red : Colors.orange;
                  }
                }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Booking #${res.id.substring(0, 8)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isToPay
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isPaid ? 'Paid' : res.status ?? '',
                              style: TextStyle(
                                color: isToPay
                                    ? Colors.orange
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (station != null)
                        Text(station.name ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15))
                      else
                        const Text('Station not found',
                            style: TextStyle(color: Colors.red)),
                      if (slot != null)
                        Text(
                          '${slot.slotCode ?? ''} · ${slot.connectorType ?? ''}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      if (res.startTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${res.startTime!.day}/${res.startTime!.month}/${res.startTime!.year}  '
                              '${res.startTime!.hour.toString().padLeft(2, '0')}:${res.startTime!.minute.toString().padLeft(2, '0')} – '
                              '${res.endTime?.hour.toString().padLeft(2, '0')}:${res.endTime?.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                      if (station?.address != null)
                        Text(station!.address!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      if (res.currentBattery != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.battery_charging_full,
                              size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                              'Start battery: ${res.currentBattery}%',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue)),
                        ]),
                      ],
                         if (res.endTime != null && res.status != 'cancelled' && res.status != 'refund') ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.timer,
                                size: 14, color: countdownColor),
                            const SizedBox(width: 4),
                            Text(
                              countdownText,
                              style: TextStyle(
                                color: countdownColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ]),
                        ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isPaid) ...[
                            if (showQrCode)
                              ...[
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.qr_code, size: 18),
                                  label: const Text('QR Code'),
                                  onPressed: () => _showQRDialog(context, res),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ElevatedButton(
                              onPressed: () => _showDetailsSheet(context, res),
                              child: const Text('View Details'),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'refund') {
                                  await _showRefundDialog(context, res.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String>(
                                  value: 'refund',
                                  child: Text('Refund'),
                                ),
                              ],
                            ),
                          ],
                          if (isToPay) ...[
                            Builder(
                              builder: (context) {
                                double calculatedFee = 10.0;
                                if (slot != null &&
                                    station != null &&
                                    res.currentBattery != null) {
                                  final vehicles =
                                  ref.read(vehicleProvider).maybeWhen(
                                    data: (v) => v,
                                    orElse: () => [],
                                  );
                                  VehicleModel? vehicle;
                                  if (vehicles.isNotEmpty) {
                                    try {
                                      vehicle = vehicles.firstWhere(
                                            (v) => v.id == res.vehicleId,
                                        orElse: () => vehicles.first,
                                      );
                                    } catch (_) {
                                      vehicle = vehicles.first;
                                    }
                                  }
                                  final batteryCapacity =
                                      vehicle?.batteryCapacityKwh ?? 40;
                                  final currentBattery =
                                      res.currentBattery ?? 1;
                                  const targetBattery = 100;
                                  final pricePerKwh =
                                      slot.pricePerKwh ?? 0.0;
                                  final kwhToCharge = ((targetBattery -
                                      currentBattery) *
                                      batteryCapacity /
                                      100)
                                      .clamp(0.0,
                                      batteryCapacity.toDouble());
                                  calculatedFee =
                                      pricePerKwh * kwhToCharge;
                                  if (calculatedFee.isNaN ||
                                      calculatedFee.isInfinite ||
                                      calculatedFee < 0.1) {
                                    calculatedFee = 10.0;
                                  }
                                }
                                return Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PaymentScreen(
                                            reservation: res,
                                            amount: (calculatedFee * 100)
                                                .round(),
                                          ),
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(
                                          'Pay Now (RM${calculatedFee.toStringAsFixed(2)})'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.red),
                                      onPressed: () => _showCancelDialog(
                                          context, res.id),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
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
  const _InfoChip({required this.label, required this.icon, this.iconColor});

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
              style: TextStyle(fontSize: 12, color: Colors.grey[800])),
        ],
      ),
    );
  }
}

// ── Reservation Details Sheet ─────────────────────────────────────────────────
class ReservationDetailsSheet extends ConsumerWidget {
  final ReservationModel reservation;
  const ReservationDetailsSheet({super.key, required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ref.watch(stationsProvider).when(
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text('Station not found.'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final qrUrl =
              'https://ejeseyuqdubakwqnzjbz.supabase.co/functions/v1/charge?res_id=${reservation.id}';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: qr.QrImageView(
                      data: qrUrl,
                      version: qr.QrVersions.auto,
                      size: 120,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('Scan QR to track charging',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(height: 16),
                if (station.name != null) ...[
                  Row(children: [
                    const Icon(Icons.ev_station, size: 20, color: Colors.grey),
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
                    const Icon(Icons.cable, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                            '${slot.slotCode ?? ''} · ${slot.connectorType ?? ''}')),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (slot?.pricePerKwh != null) ...[
                  Row(children: [
                    const Icon(Icons.bolt, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('RM${slot!.pricePerKwh!.toStringAsFixed(2)} per kWh'),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (reservation.currentBattery != null) ...[
                  Row(children: [
                    const Icon(Icons.battery_charging_full,
                        size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Start battery: ${reservation.currentBattery}%'),
                  ]),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                FutureBuilder<List<VehicleModel>>(
                  future: SupabaseService().getVehicles(),
                  builder: (context, snapshot) {
                    final vehicles = snapshot.data ?? [];
                    final vehicle = vehicles.firstWhere(
                          (v) => v.id == reservation.vehicleId,
                      orElse: () => VehicleModel(id: '', userId: ''),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vehicle.id.isNotEmpty) ...[
                          Row(children: [
                            const Icon(Icons.directions_car,
                                size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                                '${vehicle.brand ?? '-'} ${vehicle.model ?? '-'}'),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.confirmation_number,
                                size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Plate: ${vehicle.plateNumber ?? '-'}'),
                          ]),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<PaymentModel>>(
                  future: SupabaseService().getPaymentsForUser(),
                  builder: (context, snapshot) {
                    final payments = snapshot.data ?? [];
                    final payment = payments.firstWhere(
                          (p) => p.reservationId == reservation.id,
                      orElse: () =>
                          PaymentModel(id: '', reservationId: ''),
                    );
                    return Row(children: [
                      const Icon(Icons.attach_money,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                          'Booking Price: RM${payment.amount?.toStringAsFixed(2) ?? '-'}'),
                    ]);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('Show on Map'),
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/map?highlightStationId=${station?.id}');
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Error loading details'),
              Text('$e'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
