import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class StripeService {
  static const String _payIntentUrl = 'https://ejeseyuqdubakwqnzjbz.supabase.co/functions/v1/payIntent';

  static Future<bool> payWithStripe({
    required int amountCents,
    required String currency,
    required String email,
  }) async {
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (anonKey.isEmpty) {
      print('[StripeService] Error: SUPABASE_ANON_KEY is missing in .env');
      return false;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $anonKey',
      'apikey': anonKey,
    };

    try {
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
        print('[StripeService] payIntent failed (${response.statusCode}): ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'] as String?;

      if (clientSecret == null) {
        print('[StripeService] No clientSecret in response: ${response.body}');
        return false;
      }

      // Initialize Payment Sheet
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

      // Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      return true;
    } catch (e) {
      if (e is StripeException) {
        print('[StripeService] Stripe Error: ${e.error.localizedMessage}');
      } else {
        print('[StripeService] Payment error: $e');
      }
      return false;
    }
  }
}