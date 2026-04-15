import 'package:http/http.dart' as http;
import 'dart:convert';

/// Model for EV charging stations from OpenChargeMap
class ChargingStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final int? availablePoints;
  final List<String>? connectorTypes;

  ChargingStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.availablePoints,
    this.connectorTypes,
  });

  factory ChargingStation.fromJson(Map<String, dynamic> json) {
    return ChargingStation(
      id: json['ID']?.toString() ?? '',
      name: json['AddressInfo']?['Title'] ?? 'Unknown Station',
      latitude: (json['AddressInfo']?['Latitude'] ?? 0.0).toDouble(),
      longitude: (json['AddressInfo']?['Longitude'] ?? 0.0).toDouble(),
      address: json['AddressInfo']?['AddressLine1'],
      availablePoints: json['NumberOfPoints'],
      connectorTypes: _extractConnectorTypes(json),
    );
  }

  static List<String> _extractConnectorTypes(Map<String, dynamic> json) {
    final connections = json['Connections'] as List?;
    if (connections == null) return [];
    return connections
        .map((c) => c['ConnectionType']?['Title'] ?? 'Unknown')
        .cast<String>()
        .toList();
  }
}

/// Service for fetching EV charging station data from OpenChargeMap API
class OpenChargeMapService {
  static const String _apiKey = 'f950a5c9-201a-4bfc-85a0-edb23d38a093';
  static const String _baseUrl = 'https://api.openchargemap.io/v3/poi';

  static final OpenChargeMapService _instance = OpenChargeMapService._internal();

  factory OpenChargeMapService() => _instance;
  OpenChargeMapService._internal();

  /// Fetch charging stations near a location
  Future<List<ChargingStation>> getNearbyStations({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int maxResults = 100,
  }) async {
    try {
      final radiusMeters = radiusKm * 1000;
      final url = Uri.parse(
        '$_baseUrl?'
        'latitude=$latitude&'
        'longitude=$longitude&'
        'distance=$radiusMeters&'
        'distanceunit=M&'
        'maxresults=$maxResults&'
        'key=$_apiKey&'
        'outputtype=json',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((station) => ChargingStation.fromJson(station))
            .toList();
      } else {
        throw Exception('Failed to load stations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching charging stations: $e');
    }
  }

  /// Search stations by location name
  Future<List<ChargingStation>> searchByLocation(
    String locationName, {
    int maxResults = 50,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?'
        'address=$locationName&'
        'maxresults=$maxResults&'
        'key=$_apiKey&'
        'outputtype=json',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((station) => ChargingStation.fromJson(station))
            .toList();
      } else {
        throw Exception('Failed to search stations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching stations: $e');
    }
  }
}


