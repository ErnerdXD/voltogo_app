import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:voltogo_app/services/location_service.dart';
import 'package:voltogo_app/services/open_charge_map_service.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:voltogo_app/screens/discovery/station_detail_screen.dart';

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
  bool _isRadiusExpanded = false;

  double? _heading;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // --- Highlight logic ---
  String? _highlightStationId;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndStations();
    _initCompass(); // gyro/magnetometer
    // Read highlightStationId from route name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeName = ModalRoute.of(context)?.settings.name;
      String? highlightId;
      if (routeName != null && routeName.contains('highlightStationId=')) {
        final uri = Uri.parse(routeName);
        highlightId = uri.queryParameters['highlightStationId'];
      }
      if (highlightId != null && highlightId.isNotEmpty) {
        setState(() => _highlightStationId = highlightId);
      }
    });
  }

  // Initialize the Compass Listener
  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
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
      // 1. Fetch data from OpenChargeMap
      final stations = await _chargingService.getNearbyStations(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        radiusKm: _radiusKm,
      );

      if (!mounted) return;

      // 2. Map the API response into FlutterMap Markers
      final markers = stations.map((station) {
        final isHighlighted = _highlightStationId != null &&
            (station.id.toString() == _highlightStationId);
        return Marker(
          point: LatLng(station.latitude, station.longitude),
          width: 60,
          height: 60,
          rotate: true,
          child: GestureDetector(
            onTap: () => _showStationDetails(station),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isHighlighted ? Colors.blue : Colors.green,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.ev_station,
                    color: Colors.white,
                    size: isHighlighted ? 32 : 24,
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

      debugPrint('[MapScreen] Successfully loaded \\${markers.length} stations.');
    } catch (e) {
      debugPrint('Error loading stations: \\${e}');
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

  void _showStationDetails(ChargingStation station) async {
    // Wait to see what the user pressed in the bottom sheet
    final shouldLocate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StationDetailSheet(station: station),
    );

    // If they clicked Locate, move the map!
    if (shouldLocate == true) {
      // Zoom in tight (level 16 or 17) and snap upright
      _mapController.moveAndRotate(
          LatLng(station.latitude, station.longitude),
          16.5,
          0
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.voltogo_app',

                      keepBuffer: 3,
                      panBuffer: 2,
                      retinaMode: true,
                      
                      tileProvider: NetworkTileProvider(
                        headers: {
                          'User-Agent': 'VoltogoApp/1.0',
                        },
                      ),
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint('Tile load error: \\${error}');
                      },
                    ),
                    MarkerLayer(
                      markers: [
                        ..._stationMarkers,
                        Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          rotate: false,
                          child: _buildUserLocationMarker(),
                        ),
                      ],
                    ),
                  ],
                ),
                // --- Highlight dismiss X button ---
                if (_highlightStationId != null)
                  Positioned(
                    top: 36,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _highlightStationId = null);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, size: 18, color: Colors.blue),
                      ),
                    ),
                  ),
                // Unified Bottom Controls
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        heroTag: 'locator_fab',
                        onPressed: () {
                          _mapController.moveAndRotate(_currentLocation, 14, 0);
                        },
                        child: const Icon(Icons.my_location),
                        tooltip: 'Recentre and Reset Orientation',
                      ),
                      const SizedBox(height: 16),
                      if (!_isRadiusExpanded)
                        FloatingActionButton.extended(
                          heroTag: 'radius_fab',
                          onPressed: () => setState(() => _isRadiusExpanded = true),
                          icon: const Icon(Icons.radar),
                          label: Text('\\${_radiusKm.toStringAsFixed(1)} km'),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 25),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Search Radius: \\${_radiusKm.toStringAsFixed(1)} km',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _isRadiusExpanded = false),
                                    child: const Icon(Icons.close, color: Colors.grey),
                                  ),
                                ],
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
                                'Stations found: \\${_stationMarkers.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // helper method to build the rotating blue dot
  Widget _buildUserLocationMarker() {
    return Transform.rotate(
      angle: ((_heading ?? 0) * (math.pi / 180)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_heading != null)
            Positioned(
              top: 0,
              child: Icon(
                Icons.navigation,
                color: Colors.blue.withValues(alpha: 0.7),
                size: 32,
              ),
            ),
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
    _compassSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}

