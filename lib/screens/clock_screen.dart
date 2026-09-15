import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import 'face_auth_screen.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  String? _locationError;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'Location permissions are permanently denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation!, 14.5);
      }
      
      // Also start listening to continuous updates
      // Also start listening to continuous updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // update every 5 meters
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            final lat = position.latitude;
            final lng = position.longitude;
            setState(() {
              _currentLocation = LatLng(lat, lng);
              _isLoadingLocation = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _locationError = 'Stream error: $e';
            });
          }
        },
      );
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Error getting location: $e';
          _isLoadingLocation = false;
        });
      }
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

  Future<void> _handleAction(AttendanceProvider provider, bool isClockIn) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // First, verify location constraints
    final locError = await provider.verifyLocation();
    if (locError != null && mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(locError),
          backgroundColor: const Color(0xFFFF5C5C),
          duration: const Duration(seconds: 4),
        ),
      );
      return; // Block clock in/out
    }

    // Perform Face Authentication if the employee has a registered face
    if (provider.currentEmployee?.faceEmbedding != null) {
      if (!mounted) return;
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceAuthScreen(
            targetEmbedding: provider.currentEmployee!.faceEmbedding,
          ),
        ),
      );
      
      if (success != true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(provider.translate('face_auth_failed') != 'face_auth_failed' ? provider.translate('face_auth_failed') : 'Face authentication failed or cancelled.'),
            backgroundColor: Colors.redAccent,
          )
        );
        return;
      }
    }
    
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CircularProgressIndicator(color: Color(0xFF00FF87)),
        ),
      ),
    );

    final String? result;
    if (isClockIn) {
      result = await provider.clockIn();
    } else {
      result = await provider.clockOut();
    }

    if (!mounted) return;
    
    // Hide loading
    Navigator.of(context).pop();

    if (result == null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
              SizedBox(width: 12),
              Text(
                isClockIn ? 'Successfully Clocked In!' : 'Successfully Clocked Out!',
                style: TextStyle(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00FF87).withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else if (result == 'missed_checkin') {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.translate('missed_check_in_msg'),
                  style: TextStyle(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFFA726).withValues(alpha: 0.9), // Orange warning
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
              SizedBox(width: 12),
              Expanded(child: Text(result, style: TextStyle(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))))),
            ],
          ),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding, double? height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.2)),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final emp = provider.currentEmployee;
    
    List<WorkLocation> assignedLocations = [];
    if (emp != null) {
      assignedLocations = provider.locations.where((l) => l.groupIds.contains(emp.groupId)).toList();
    }
    final primaryLocation = assignedLocations.isNotEmpty ? assignedLocations.first : null;

    final Distance distance = const Distance();
    bool isInsideZone = false;
    double? distanceInMeters;

    if (primaryLocation != null && _currentLocation != null) {
      distanceInMeters = distance.distance(
        _currentLocation!, 
        LatLng(primaryLocation.latitude, primaryLocation.longitude)
      );
      isInsideZone = distanceInMeters <= primaryLocation.radius;
    }

    final dateStr = DateFormat('EEEE, MMM d').format(_currentTime);
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          provider.translate('clock'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              
              // 1. Date/Time Card
              _buildGlassContainer(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                      child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          provider.isClockedIn ? 'On shift' : 'Off shift',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                        ),
                        const Text(
                          '--:--',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 2. The Map Card
              _buildGlassContainer(
                height: 200,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLocation ?? const LatLng(33.3152, 44.3661),
                          initialZoom: 14.5,
                          minZoom: 3.0,
                          maxZoom: 19.0,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.didam.attendance_app',
                            maxZoom: 19,
                          ),
                          PolygonLayer(
                            polygons: assignedLocations.map((loc) {
                              return Polygon(
                                points: _createCirclePolygon(
                                  LatLng(loc.latitude, loc.longitude),
                                  loc.radius,
                                ),
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderColor: Colors.blue,
                                borderStrokeWidth: 2,
                              );
                            }).toList(),
                          ),
                          if (_currentLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentLocation!,
                                  width: 50,
                                  height: 50,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(Icons.circle, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 28),
                                      const Icon(Icons.circle, color: Colors.blue, size: 22),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.my_location, color: Color(0xFF2E65FF)),
                          onPressed: () {
                            if (_currentLocation != null) {
                              _mapController.move(_currentLocation!, 14.5);
                            } else {
                              _determinePosition();
                            }
                          },
                        ),
                      ),
                    ),
                    if (_isLoadingLocation)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: CircularProgressIndicator(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
                        ),
                      ),
                    if (_locationError != null && !_isLoadingLocation)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                            ]
                          ),
                          child: Text(
                            _locationError!,
                            style: TextStyle(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 3. Assigned Location Info Card
              _buildGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        isInsideZone ? Icons.location_on : Icons.location_off, 
                        color: isInsideZone ? Colors.greenAccent : Colors.orangeAccent, 
                        size: 20
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryLocation?.name ?? 'Unknown Location',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            distanceInMeters != null 
                                ? '${distanceInMeters.toInt()}m away (Radius: ${primaryLocation?.radius.toInt()}m)'
                                : (primaryLocation != null ? '${primaryLocation.latitude}, ${primaryLocation.longitude}' : 'Waiting for location...'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isInsideZone ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isInsideZone ? 'In Zone' : 'Out of Zone',
                        style: TextStyle(
                          color: isInsideZone ? Colors.greenAccent : Colors.redAccent, 
                          fontSize: 12,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 4. Status Dashboard
              _buildGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isClockedIn ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        provider.isClockedIn ? Icons.work_outline : Icons.check_circle_outline, 
                        color: provider.isClockedIn ? Colors.blueAccent : Colors.greenAccent, 
                        size: 24
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.isClockedIn ? 'WORKING' : 'READY TO WORK',
                          style: TextStyle(
                            color: provider.isClockedIn ? Colors.blueAccent : Colors.greenAccent, 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 1.2
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.isClockedIn ? 'Clocked in successfully' : 'Not clocked in',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 5. The Clock Buttons
              _buildClockButtons(provider),
              const SizedBox(height: 16),

              
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockButtons(AttendanceProvider provider) {
    final bool isClockedIn = provider.isClockedIn;
    
    return Row(
      children: [
        // Clock In
        Expanded(
          child: GestureDetector(
            onTap: (_isLoadingLocation || isClockedIn) ? null : () => _handleAction(provider, true),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: isClockedIn ? const Color(0xFF1AD579).withValues(alpha: 0.4) : const Color(0xFF1AD579),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.login_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text('Clock In', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Start shift', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Clock Out
        Expanded(
          child: GestureDetector(
            onTap: _isLoadingLocation ? null : () => _handleAction(provider, false),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B4B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text('Clock Out', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('End shift', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
