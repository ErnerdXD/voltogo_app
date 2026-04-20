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
  bool _showPastReservations = false;
  Timer? _timer;
  final Set<String> _isDeletingIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reservationProvider.notifier).fetchReservations();
      setState(() {});
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

  // ── Cancel dialog ────────────────────────────────────────────────────────────
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

  // ── QR dialog ────────────────────────────────────────────────────────────────
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
                    const Text(
                      'Scan to Track Charging',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Point another phone at this code',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
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
                    const Text(
                      'Tap anywhere to close',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Details bottom sheet ─────────────────────────────────────────────────────
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

  // ── Create reservation form ──────────────────────────────────────────────────
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
            if (m == 60) return TimeOfDay(hour: (t.hour + 1) % 24, minute: 0);
            return TimeOfDay(hour: t.hour, minute: m);
          }

          final vehicles = vehiclesAsync.valueOrNull ?? [];
          VehicleModel? selectedVehicle;
          if (vehicles.isNotEmpty) {
            try {
              selectedVehicle = vehicles.firstWhere(
                      (v) => v.id == (selectedVehicleIdLocal));
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

                  // Station card
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

                  // Vehicle dropdown
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

                  // Current battery info
                  if (selectedVehicle != null) ...[
                    Row(children: [
                      const Icon(Icons.battery_charging_full,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Current battery: ~$currentBattery%  ·  '
                            'Capacity: ${batteryCapacity}kWh',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Target battery input
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

                    // Fee summary
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
                            '~${kwhToCharge.toStringAsFixed(1)} kWh  ·  '
                                'Est. RM ${calculatedFee.toStringAsFixed(2)}',
                            style:
                            const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

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

                  // Time pickers
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

                  // Submit
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
                                  content: Text(
                                      'Please select a vehicle.')));
                          return;
                        }
                        if (endTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please pick an end time.')));
                          return;
                        }
                        setModalState(() => isSaving = true);
                        final nav = Navigator.of(context);
                        final messenger =
                        ScaffoldMessenger.of(context);
                        try {
                          final reservation = await ref
                              .read(reservationProvider.notifier)
                              .createReservation(
                            slotId: slotId,
                            vehicleId: vehicleId,
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
                          if (reservation != null) {
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

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationProvider);
    final stationsAsync = ref.watch(stationsProvider);

    final now = DateTime.now();

    bool isTimerExpired(r) =>
        r.status == 'to pay' &&
            r.createdAt != null &&
            now.isAfter(r.createdAt!.toLocal().add(const Duration(minutes: 10)));

    final activeRes = state.reservations
        .where((r) =>
    (r.status == 'active' ||
        r.status == 'paid' ||
        r.status == 'to pay') &&
        !isTimerExpired(r))
        .toList();
    final pastRes = state.reservations
        .where((r) =>
    r.status == 'cancelled' ||
        r.status == 'completed' ||
        isTimerExpired(r))
        .toList();

    ref.listen<Map<String, String>?>(pendingBookingStationProvider,
            (prev, next) {
          if (next != null) {
            if (activeRes.length >= 4) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Maximum 4 active reservations allowed.')));
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
          const SizedBox(height: 16),
          if (activeRes.isEmpty)
            const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No active reservations.')),
            )
          else
            ...activeRes.map((res) {
              final isToPay = res.status == 'to pay';
              final isPaid =
                  res.status == 'paid' || res.status == 'active';
              final expiry = (res.createdAt ?? res.startTime)
                  ?.toLocal()
                  .add(const Duration(minutes: 10));

              // Lookup station + slot
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

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
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
                                  ? Colors.orange
                                  .withValues(alpha: 0.1)
                                  : Colors.green
                                  .withValues(alpha: 0.1),
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

                      // Station
                      if (station != null)
                        Text(station.name ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15))
                      else
                        const Text('Station not found',
                            style: TextStyle(color: Colors.red)),

                      // Slot info
                      if (slot != null)
                        Text(
                          '${slot.slotCode ?? ''} · ${slot.connectorType ?? ''}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),

                      // Time
                      if (res.startTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${res.startTime!.day}/${res.startTime!.month}/${res.startTime!.year}  '
                              '${res.startTime!.hour.toString().padLeft(2, '0')}:${res.startTime!.minute.toString().padLeft(2, '0')} – '
                              '${res.endTime?.hour.toString().padLeft(2, '0')}:${res.endTime?.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],

                      // Address
                      if (station?.address != null)
                        Text(station!.address!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),

                      // Battery
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

                      // Expiry countdown
                      if (expiry != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.timer,
                              size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            expiry.isAfter(DateTime.now())
                                ? 'Time left: '
                                '${expiry.difference(DateTime.now()).inMinutes.remainder(60).toString().padLeft(2, '0')}:'
                                '${(expiry.difference(DateTime.now()).inSeconds % 60).toString().padLeft(2, '0')}'
                                : 'Expired',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isPaid) ...[
                            OutlinedButton.icon(
                              icon: const Icon(Icons.qr_code,
                                  size: 18),
                              label: const Text('QR Code'),
                              onPressed: () =>
                                  _showQRDialog(context, res),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  _showDetailsSheet(context, res),
                              child: const Text('View Details'),
                            ),
                          ],
                          if (isToPay) ...[
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PaymentScreen(
                                          reservation: res,
                                          amount: 1000))),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white),
                              child: const Text('Pay Now'),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.cancel,
                                  color: Colors.red),
                              onPressed: () =>
                                  _showCancelDialog(context, res.id),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          // Past reservations
          if (pastRes.isNotEmpty) ...[
            const Divider(height: 32),
            Center(
              child: TextButton.icon(
                icon: Icon(_showPastReservations
                    ? Icons.expand_less
                    : Icons.history),
                label: Text(_showPastReservations
                    ? 'Hide History'
                    : 'View Previous Reservations'),
                onPressed: () => setState(() =>
                _showPastReservations = !_showPastReservations),
              ),
            ),
            if (_showPastReservations)
              ...pastRes.map((res) {
                final isExpiredTimer = res.status == 'to pay' &&
                    res.createdAt != null &&
                    now.isAfter(res.createdAt!
                        .toLocal()
                        .add(const Duration(minutes: 10)));
                final displayStatus = isExpiredTimer
                    ? 'Expired (unpaid)'
                    : res.status ?? '';
                return Card(
                  color: Colors.grey[50],
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                        'Booking #${res.id.substring(0, 8)}',
                        style:
                        const TextStyle(color: Colors.grey)),
                    subtitle: Text('Status: $displayStatus',
                        style: const TextStyle(
                            color: Colors.redAccent)),
                  ),
                );
              }),
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

// ── Reservation Details Dialog ────────────────────────────────────────────────
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
                      style:
                      TextStyle(color: Colors.grey, fontSize: 12)),
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
                    Text(
                        'RM${slot!.pricePerKwh!.toStringAsFixed(2)} per kWh'),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (reservation.currentBattery != null) ...[
                  Row(children: [
                    const Icon(Icons.battery_charging_full,
                        size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                        'Start battery: ${reservation.currentBattery}%'),
                  ]),
                  const SizedBox(height: 8),
                ],
                const Divider(),

                // --- Booking Price, Car Plate, Car Name ---
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
                      context.go(
                          '/map?highlightStationId=${station?.id}');
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
