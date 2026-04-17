import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:voltogo_app/services/location_service.dart';
import 'package:voltogo_app/services/open_charge_map_service.dart';
import 'package:voltogo_app/widgets/brand_app_bar_title.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeLocationAndStations();
  }

  Future<void> _initializeLocationAndStations() async {
    final hasPermission =
        await _locationService.requestLocationPermission();

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
    // Start loading state
    setState(() => _isLoading = true);

    try {
      // 1. Fetch data from the external API service
      final stations = await _chargingService.getNearbyStations(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        radiusKm: _radiusKm,
      );

      if (!mounted) return;

      // 2. Map the API response (ChargingStation objects) into FlutterMap Markers
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
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.ev_station,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                // Optional: Show points available if data exists
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

      // 3. Add your current location marker (User's Blue Dot)
      markers.add(
        Marker(
          point: _currentLocation,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      );

      // 4. Update the state with the new markers and stop loading
      setState(() {
        _stationMarkers = markers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load charging stations: $e')),
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
      appBar: AppBar(
        titleSpacing: 0,
        title: const BrandAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center to current location',
            onPressed: () {
              _mapController.move(_currentLocation, 14);
            },
          ),
        ],
      ),
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
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.voltogo_app',
                      // This helps prevent some of the silent socket errors from bubbling up
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint('Tile load error: $error');
                      },
                    ),
                    MarkerLayer(
                      markers: _stationMarkers,
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
              ],
            ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
