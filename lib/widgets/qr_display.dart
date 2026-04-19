
import 'package:flutter/material.dart';

class QRDisplay extends StatelessWidget {
  final String data;
  const QRDisplay({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
	// Placeholder: just show the data as text
	return Column(
	  mainAxisSize: MainAxisSize.min,
	  children: [
		const Icon(Icons.qr_code, size: 80),
		const SizedBox(height: 16),
		Text('QR Data: $data'),
	  ],
	);
  }
}
