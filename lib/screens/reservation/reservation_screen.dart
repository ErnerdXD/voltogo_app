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

final pendingBookingStationProvider = StateProvider<String?>((ref) => null);

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  String? selectedVehicleId;
  bool _showPastReservations = false;
  Timer? _timer;

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
    final state = ref.read(reservationProvider);
    final now = DateTime.now();
    
    for (final res in state.reservations) {
      if (res.status == 'to pay' && res.createdAt != null && !_isDeletingIds.contains(res.id)) {
        final expiryTime = res.createdAt!.toLocal().add(const Duration(minutes: 10));
        if (now.isAfter(expiryTime)) {
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
    if (res.createdAt == null) return "10:00";
    final now = DateTime.now();
    final expiryTime = res.createdAt!.toLocal().add(const Duration(minutes: 10));
    final difference = expiryTime.difference(now);
    if (difference.isNegative) return "00:00";
    final minutes = difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<String> _ensureSlotExists(String stationName) async {
    final client = Supabase.instance.client;
    try {
      final existing = await client
          .from('stations')
          .select('id, slots(id)')
          .ilike('name', '%${stationName.split(' ')[0]}%')
          .limit(1)
          .maybeSingle();
      if (existing != null && (existing['slots'] as List).isNotEmpty) {
        return existing['slots'][0]['id'];
      }
      final anySlot = await client.from('slots').select('id').eq('status', 'available').limit(1).maybeSingle();
      if (anySlot != null) return anySlot['id'];
      return 'e1000000-0000-0000-0000-000000000001';
    } catch (e) {
      return 'e1000000-0000-0000-0000-000000000001'; 
    }
  }

  Future<void> _showCancelDialog(BuildContext context, String reservationId) async {
    String? selectedReason;
    bool isProcessing = false;
    final reasons = ['Changed my mind', 'Found a better station', 'Vehicle issue', 'Wrong booking details', 'Other'];

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
                ...reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (val) => setDialogState(() => selectedReason = val),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(context), child: const Text('Go Back')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: (isProcessing || selectedReason == null) ? null : () async {
                setDialogState(() => isProcessing = true);
                try {
                  await Supabase.instance.client.from('reservations').update({
                    'status': 'cancelled',
                    'cancellation_reason': selectedReason,
                  }).eq('id', reservationId);
                  await ref.read(reservationProvider.notifier).fetchReservations();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation cancelled.')));
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (context.mounted) setDialogState(() => isProcessing = false);
                }
              },
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking QR Code'),
        content: QRDisplay(data: id),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCreateReservationForm(BuildContext context, {required String stationName}) {
    final activeCount = ref.read(reservationProvider).reservations.where((r) => r.status != 'cancelled').length;
    if (activeCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 4 active reservations allowed.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Consumer(builder: (context, ref, child) {
          final vehiclesAsync = ref.watch(vehicleProvider);
          DateTime selectedDate = DateTime.now();
          final now = DateTime.now();
          int initialMinutes = (now.minute / 30).round() * 30;
          DateTime snappedNow = DateTime(now.year, now.month, now.day, now.hour, initialMinutes);
          if (snappedNow.isBefore(now)) snappedNow = snappedNow.add(const Duration(minutes: 30));
          TimeOfDay startTime = TimeOfDay.fromDateTime(snappedNow);
          TimeOfDay? endTime;
          bool isSaving = false;

          return StatefulBuilder(builder: (context, setModalState) {
            TimeOfDay snapTime(TimeOfDay time) {
              int minutes = (time.minute / 30).round() * 30;
              if (minutes == 60) return TimeOfDay(hour: (time.hour + 1) % 24, minute: 0);
              return TimeOfDay(hour: time.hour, minute: minutes);
            }
            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Create Reservation', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    vehiclesAsync.when(
                      data: (v) => DropdownButtonFormField<String>(
                        value: selectedVehicleId,
                        items: v.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.brand} ${v.model}'))).toList(),
                        onChanged: (val) => setModalState(() => selectedVehicleId = val),
                        decoration: const InputDecoration(labelText: 'Select Vehicle', border: OutlineInputBorder()),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Error loading vehicles'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(initialValue: stationName, readOnly: true, decoration: const InputDecoration(labelText: 'Station', border: OutlineInputBorder(), filled: true)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_today), label: Text('${selectedDate.day}/${selectedDate.month}'), onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 7)));
                        if (d != null) setModalState(() => selectedDate = d);
                      })),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.access_time), label: Text('Start: ${startTime.format(context)}'), onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: startTime);
                        if (t != null) setModalState(() => startTime = snapTime(t));
                      })),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.access_time_filled), label: Text(endTime == null ? 'Pick End' : 'End: ${endTime!.format(context)}'), onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: endTime ?? startTime);
                        if (t != null) setModalState(() => endTime = snapTime(t));
                      })),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      onPressed: isSaving ? null : () async {
                        if (selectedVehicleId == null || endTime == null) return;
                        setModalState(() => isSaving = true);
                        try {
                          final slotId = await _ensureSlotExists(stationName);
                          final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                          final end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime!.hour, endTime!.minute);
                          await ref.read(reservationProvider.notifier).createReservation(slotId: slotId, vehicleId: selectedVehicleId!, startTime: start, endTime: end);
                          if (mounted) {
                             Navigator.pop(ctx);
                             await ref.read(reservationProvider.notifier).fetchReservations();
                             final resState = ref.read(reservationProvider);
                             final latestRes = resState.reservations.isNotEmpty ? resState.reservations.first : null;
                             Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen(reservation: latestRes, amount: 1000)));
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        } finally {
                          if (mounted) setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Pay & Reserve'),
                    )),
                  ],
                ),
              ),
            );
          });
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationProvider);
    final activeRes = state.reservations.where((r) => r.status == 'active' || r.status == 'paid' || r.status == 'to pay').toList();
    final pastRes = state.reservations.where((r) => r.status == 'cancelled' || r.status == 'completed').toList();

    ref.listen<String?>(pendingBookingStationProvider, (prev, next) {
      if (next != null) {
        if (activeRes.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 4 active reservations allowed.')));
        } else {
          _showCreateReservationForm(context, stationName: next);
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
                        Text('Status: ${isPaid ? 'paid' : res.status}', 
                          style: TextStyle(color: isToPay ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (res.startTime != null) ...[
                      Text('Date: ${res.startTime!.day}/${res.startTime!.month}/${res.startTime!.year}'),
                      Text('Time: ${res.startTime!.hour}:${res.startTime!.minute.toString().padLeft(2, '0')} - ${res.endTime?.hour}:${res.endTime?.minute.toString().padLeft(2, '0')}'),
                    ],
                    if (isToPay) ...[
                      const SizedBox(height: 8),
                      Text('Expires in: ${_getRemainingTime(res)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
          ]
        ],
      ),
    );
  }
}
