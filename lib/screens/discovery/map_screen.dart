import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:voltogo_app/services/location_service.dart';
import 'package:voltogo_app/services/open_charge_map_service.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final OpenChargeMapService _chargingService = OpenChargeMapService();
  final LocationService _locationService = LocationService();

  LatLng _currentLocation = const LatLng(3.1390, 101.6869); // KL default
  List<Marker> _stationMarkers = [];
  double _radiusKm = 5.0;
  bool _isLoading = false;

  double? _heading;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndStations();
    _initCompass(); // gyro/magnetometer
  }

  // Initialize the Compass Listener
  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      // Debugging: check if sensor is actually firing
      debugPrint('Compass Heading: ${event.heading}');

      if (mounted && event.heading != null) {
        setState(() {
          _heading = event.heading;
        });
      }
    }, onError: (error) {
      debugPrint('Compass Error: $error');
    });
  }

  Future<void> _initializeLocationAndStations() async {
    final hasPermission = await _locationService.requestLocationPermission();

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      if (hasPermission) {
        final location = await _locationService.getCurrentLocation();
        if (location != null) {
          setState(() {
            _currentLocation = location;
          });
        }
      }

      await _loadNearbyStations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNearbyStations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch data from OpenChargeMap (with the new headers)
      final stations = await _chargingService.getNearbyStations(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        radiusKm: _radiusKm,
      );

      if (!mounted) return;

      // 2. Map the API response into FlutterMap Markers
      final markers = stations.map((station) {
        return Marker(
          point: LatLng(station.latitude, station.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showStationDetails(station),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.ev_station,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (station.availablePoints != null && station.availablePoints! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${station.availablePoints}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList();

      setState(() {
        _stationMarkers = markers;
        _isLoading = false;
      });

      debugPrint('[MapScreen] Successfully loaded ${markers.length} stations.');
    } catch (e) {
      debugPrint('Error loading stations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load stations. Try again later.'),
            action: SnackBarAction(label: 'Retry', onPressed: _loadNearbyStations),
          ),
        );
      }
    }
  }

  void _showStationDetails(ChargingStation station) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              station.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (station.address != null)
              Text(
                station.address!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 8),
            if (station.availablePoints != null)
              Text(
                'Available Points: ${station.availablePoints}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (station.connectorTypes != null &&
                station.connectorTypes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connector Types:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    ...station.connectorTypes!
                        .map((type) => Text('• $type',
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar and all top bars completely removed
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 14,
                    maxZoom: 18.0,
                    minZoom: 5.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all, // Re-enables rotation
                      rotationThreshold: 25.0,    // But ignores slight accidental twists
                      pinchZoomThreshold: 0.5,    // Makes zooming smoother
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.voltogo_app',
                      tileProvider: NetworkTileProvider(
                        headers: {
                          'User-Agent': 'VoltogoApp/1.0',
                        },
                      ),
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint('Tile load error: $error');
                      },
                    ),
                    MarkerLayer(
                      markers: [
                        ..._stationMarkers, // These are the charging stations

                        // ADD THIS: The User Marker added separately
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: _buildUserLocationMarker(), // Calling the helper method below
                        ),
                      ],
                    ),
                  ],
                ),
                // Radius slider
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Radius: ${_radiusKm.toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 25,
                          divisions: 24,
                          onChanged: (value) {
                            setState(() => _radiusKm = value);
                            _loadNearbyStations();
                          },
                        ),
                        Text(
                          'Stations found: ${_stationMarkers.length - 1}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                // Locator FAB
                Positioned(
                  bottom: 100,
                  right: 20,
                  child: FloatingActionButton(
                    heroTag: 'locator_fab',
                    onPressed: () {
                      _mapController.move(_currentLocation, 14);
                    },
                    child: const Icon(Icons.my_location),
                    tooltip: 'Center to current location',
                  ),
                ),
              ],
            ),
    );
  }

  // helper method to build the rotating blue dot
  Widget _buildUserLocationMarker() {
    return Transform.rotate(
      // Convert degrees from compass to radians for Flutter
      angle: ((_heading ?? 0) * (math.pi / 180)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The directional "Beam" pointing UP
          if (_heading != null)
            Positioned(
              top: 0,
              child: Icon(
                Icons.navigation,
                color: Colors.blue.withValues(alpha: 0.5),
                size: 32,
              ),
            ),
          // The Blue Dot
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _compassSubscription?.cancel(); //stop sensor when leave screen
    _mapController.dispose();
    super.dispose();
  }
}
