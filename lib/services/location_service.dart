import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Check and request location permissions
  Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      return await Geolocator.requestPermission() == LocationPermission.whileInUse;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openLocationSettings();
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Get current device location
  Future<LatLng?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two points (in km)
  double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  /// Get nearby stations (filter by distance)
  Future<List<Map<String, dynamic>>> getNearbyStations(
      List<Map<String, dynamic>> stations,
      LatLng userLocation, {
        double radiusKm = 5.0,
      }) async {
    final nearby = <Map<String, dynamic>>[];

    for (var station in stations) {
      final stationLocation = LatLng(
        station['latitude'] as double,
        station['longitude'] as double,
      );
      final distance = calculateDistance(userLocation, stationLocation);

      if (distance <= radiusKm) {
        nearby.add({
          ...station,
          'distance': distance.toStringAsFixed(2),
        });
      }
    }

    // Sort by distance
    nearby.sort((a, b) =>
        double.parse(a['distance']).compareTo(double.parse(b['distance'])));

    return nearby;
  }
}
