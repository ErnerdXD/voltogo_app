import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Model for EV charging stations from OpenChargeMap
class ChargingStation {
  final String id;
  final String name;

  ChargingStation({
    required this.id,
    required this.name,
  });
  // ...existing code for ChargingStation...
  // ...existing code for ChargingStation...
}

class StripeService {
  static const String _payIntentUrl = 'https://ejeseyuqdubakwqnzjbz.supabase.co/functions/v1/payIntent';

  static Future<bool> payWithStripe({
    required int amountCents,
    required String currency,
    required String email,
  }) async {
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (anonKey.isEmpty) {
      debugPrint('[StripeService] Error: SUPABASE_ANON_KEY is missing in .env');
      _showErrorDialog('Payment configuration error. Please contact support.');
      return false;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $anonKey',
      'apikey': anonKey,
    };

    try {
      debugPrint('[StripeService] Requesting payment intent...');
      final response = await http.post(
        Uri.parse(_payIntentUrl),
        headers: headers,
        body: jsonEncode({
          'amount': amountCents,
          'currency': currency,
          'customer_email': email,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('[StripeService] payIntent failed (${response.statusCode}): ${response.body}');
        _showErrorDialog('Failed to start payment. Please try again.');
        return false;
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'] as String?;

      if (clientSecret == null) {
        debugPrint('[StripeService] No clientSecret in response: ${response.body}');
        _showErrorDialog('Payment could not be started. Please try again.');
        return false;
      }

      debugPrint('[StripeService] Initializing payment sheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Voltogo',
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: email,
            address: Address(
              country: 'MY',
              city: null,
              line1: null,
              line2: null,
              postalCode: null,
              state: null,
            ),
          ),
          billingDetailsCollectionConfiguration:
              BillingDetailsCollectionConfiguration(
            address: AddressCollectionMode.never,
          ),
        ),
      );

      debugPrint('[StripeService] Presenting payment sheet...');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('[StripeService] Payment sheet completed.');
      return true;
    } catch (e) {
      if (e is StripeException) {
        debugPrint('[StripeService] Stripe Error: ${e.error.localizedMessage}');
        _showErrorDialog('Payment cancelled or failed: ${e.error.localizedMessage}');
      } else {
        debugPrint('[StripeService] Payment error: $e');
        _showErrorDialog('Payment failed: $e');
      }
      return false;
    }
  }

  static void _showErrorDialog(String message) {
    // Use a global key or context if available, otherwise fallback to debugPrint
    // This is a placeholder; in production, use a proper context-aware dialog
    debugPrint('[StripeService] ERROR: $message');
    // Optionally, you can implement a global error dialog or snackbar here
  }
}
