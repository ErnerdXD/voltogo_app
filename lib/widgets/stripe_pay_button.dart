import 'package:flutter/material.dart';
import 'package:voltogo_app/services/stripe_service.dart';

class StripePayButton extends StatefulWidget {
  final int amount;
  final String currency;
  final String email;
  final VoidCallback? onSuccess;

  const StripePayButton({
    super.key,
    required this.amount,
    required this.currency,
    required this.email,
    this.onSuccess,
  });

  @override
  State<StripePayButton> createState() => _StripePayButtonState();
}

class _StripePayButtonState extends State<StripePayButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
               // Use StripeService instead of StripePaymentService
               // You will need to pass the user's email as well
               final success = await StripeService.payWithStripe(
                 amountCents: widget.amount,
                 currency: widget.currency,
                 email: widget.email,
               );
              setState(() => _loading = false);
              if (success && widget.onSuccess != null) {
                widget.onSuccess!();
              }
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment failed or cancelled.')),
                );
              }
            },
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Pay with Stripe'),
    );
  }
}

