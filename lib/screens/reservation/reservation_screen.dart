import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation_model.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  bool _isLoading = false;

  Future<void> _createReservation(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final newReservation = ReservationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'demoUser', // Replace with actual userId if available
      );
      context.read<ReservationProvider>().setReservation(newReservation);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation created!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create reservation: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelReservation(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      context.read<ReservationProvider>().clearReservation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel reservation: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = context.watch<ReservationProvider>().reservation;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reservation == null) ...[
                    const Text('No reservation found.'),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _createReservation(context),
                      child: const Text('Create Reservation'),
                    ),
                  ],
                  if (reservation != null) ...[
                    Text('Reservation ID: \\${reservation.id}'),
                    // Add more reservation details here as needed
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _cancelReservation(context),
                      child: const Text('Cancel Reservation'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
