import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialRadius;
  final bool fetchCurrentLocation;

  const MapPickerScreen({
    super.key,
    this.initialLatitude = 33.3152, // Default to Baghdad, Iraq for example
    this.initialLongitude = 44.3661,
    this.initialRadius = 100.0,
    this.fetchCurrentLocation = false,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  late double _radius;
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLatitude, widget.initialLongitude);
    _radius = widget.initialRadius;
    if (widget.fetchCurrentLocation) {
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      } 

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        if (_isMapReady) {
          _mapController.move(_selectedLocation, 15.0);
        }
      });
    } catch (e) {
      debugPrint("Error determining position: $e");
    }
  }

  // Generates a geographical polygon for the radius, which prevents the 
  // severe zooming lag caused by CircleMarker's useRadiusInMeter parameter.
  List<LatLng> _createCirclePolygon(LatLng center, double radiusInMeters) {
    const int points = 64;
    const double earthRadius = 6378137.0; // WGS84 major axis
    final List<LatLng> polygon = [];
    
    final double lat = center.latitude * math.pi / 180.0;
    final double lng = center.longitude * math.pi / 180.0;
    final double d = radiusInMeters / earthRadius;

    for (int i = 0; i <= points; i++) {
      final double bearing = 2 * math.pi * i / points;
      final double circleLat = math.asin(math.sin(lat) * math.cos(d) + 
                               math.cos(lat) * math.sin(d) * math.cos(bearing));
      final double circleLng = lng + math.atan2(math.sin(bearing) * math.sin(d) * math.cos(lat), 
                                     math.cos(d) - math.sin(lat) * math.sin(circleLat));
      polygon.add(LatLng(circleLat * 180.0 / math.pi, circleLng * 180.0 / math.pi));
    }
    return polygon;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: const Color(0xFF2E65FF),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop({
                'latitude': _selectedLocation.latitude,
                'longitude': _selectedLocation.longitude,
                'radius': _radius,
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Allowed Radius (meters)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Slider(
                  value: _radius,
                  min: 10,
                  max: 1000,
                  divisions: 99,
                  label: '${_radius.round()} m',
                  activeColor: const Color(0xFF2E65FF),
                  onChanged: (val) {
                    setState(() {
                      _radius = val;
                    });
                  },
                ),
                Text('Radius: ${_radius.round()} meters'),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15.0,
                minZoom: 3.0,
                maxZoom: 19.0,
                onMapReady: () {
                  _isMapReady = true;
                  if (widget.fetchCurrentLocation) {
                    _mapController.move(_selectedLocation, 15.0);
                  }
                },
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.didam.attendance_app',
                  maxZoom: 19,
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _createCirclePolygon(_selectedLocation, _radius),
                      color: Colors.blue.withValues(alpha: 0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text(
              'Tap on the map to set the center point.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _determinePosition,
        backgroundColor: const Color(0xFF2E65FF),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
