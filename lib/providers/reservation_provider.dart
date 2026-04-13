// reservation_provider.dart
import 'package:flutter/material.dart';
import '../models/reservation_model.dart';

class ReservationProvider extends ChangeNotifier {
  ReservationModel? _reservation;

  ReservationModel? get reservation => _reservation;

  void setReservation(ReservationModel reservation) {
    _reservation = reservation;
    notifyListeners();
  }

  void clearReservation() {
    _reservation = null;
    notifyListeners();
  }
}
