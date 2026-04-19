import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voltogo_app/providers/auth_provider.dart';
import 'package:voltogo_app/providers/reservation_provider.dart';
import 'package:voltogo_app/services/supabase_service.dart';
import 'package:voltogo_app/widgets/stripe_pay_button.dart';
import 'package:voltogo_app/models/reservation_model.dart';

class PaymentScreen extends ConsumerWidget {
  final ReservationModel? reservation;
  final int amount;

  const PaymentScreen({
    super.key,
    this.reservation,
    this.amount = 1000,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: profileAsync.when(
        data: (profile) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payment, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Amount to Pay',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'RM ${(amount / 100).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 40),
              if (reservation != null) ...[
                Text('Reservation ID: ${reservation!.id}'),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: StripePayButton(
                  amount: amount,
                  currency: 'myr',
                  email: profile?.email ?? '',
                  onSuccess: () async {
                    print('[Payment] onSuccess called, reservation: ${reservation?.id}');
                    try {
                      if (reservation != null) {
                        // 1) First mark reservation as paid on server and refresh via provider
                        debugPrint('[Payment] Marking reservation ${reservation!.id} as paid');
                        await ref.read(reservationProvider.notifier).completeReservation(reservation!.id);

                        // 2) Persist a payment record to Supabase (best-effort)
                        final service = SupabaseService();
                        try {
                          await service.createPayment(
                            reservationId: reservation!.id,
                            userId: null,
                            amount: (amount / 100), // store as RM amount (double)
                            energyKwh: null,
                            status: 'paid',
                            paidAt: DateTime.now(),
                            stripePaymentIntentId: null,
                            stripeCustomerId: null,
                            paymentMethodType: null,
                            paymentMethodLast4: null,
                          );
                          debugPrint('[Payment] Payment record created for reservation ${reservation!.id}');
                        } catch (e) {
                          debugPrint('[Payment] Failed to create payment record: $e');
                        }
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment successful! Reservation updated.')),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Payment succeeded but failed to update reservation: $e')),
                        );
                        Navigator.of(context).pop();
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}