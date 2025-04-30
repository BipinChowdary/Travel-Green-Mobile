import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  // Map controller
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  GoogleMapController? _mapController;

  // Location tracking
  Position? _currentPosition;
  Position? _destinationPosition;
  String? _destinationAddress;
  String? _startAddress;

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Placemark> _searchResults = [];

  // Route data
  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoordinates = [];

  // Trip state
  bool _isTripActive = false;
  bool _isSelectingDestination = false;
  bool _isSavingTrip = false;

  // Trip statistics
  double _totalDistance = 0.0;
  double _averageSpeed = 0.0;

  // Markers
  Set<Marker> _markers = {};

  // Timer for location updates
  Timer? _locationTimer;
  List<Position> _locationHistory = [];
  DateTime? _tripStartTime;
  DateTime? _tripEndTime;

  // Trip service for Firestore operations
  final TripService _tripService = TripService();

  // Selected transport mode
  TransportMode _selectedTransportMode = TransportMode.unknown;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      _showSnackBar(
          'Location services are disabled. Please enable location services');
      return;
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied');
      return;
    }

    // Get current position
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;
        _updateMarkers();
      });

      if (_mapController != null) {
        _animateToCurrentPosition();
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _animateToCurrentPosition() {
    if (_currentPosition != null && _mapController != null) {
      if (_isTripActive && _destinationPosition != null) {
        // During active trip, try to keep both the current position and destination visible
        // But prioritize following the user's movement
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15.0, // Slightly zoomed out to provide context
            ),
          ),
        );
      } else {
        // Before trip starts, just center on current position
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 16.0,
            ),
          ),
        );
      }
    }
  }

  void _startTrip() {
    setState(() {
      _isSelectingDestination = true;
      _showSnackBar('Tap on the map to select your destination');
    });
  }

  void _confirmDestination(LatLng position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      // Get the start address as well
      String? startAddress;
      if (_currentPosition != null) {
        List<Placemark> startPlacemarks = await placemarkFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude);
        if (startPlacemarks.isNotEmpty) {
          Placemark startPlace = startPlacemarks[0];
          startAddress =
              '${startPlace.street}, ${startPlace.locality}, ${startPlace.country}';
          _startAddress = startAddress;
        }
      }

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '${place.street}, ${place.locality}, ${place.country}';

        setState(() {
          _destinationPosition = Position(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0);
          _destinationAddress = address;
          _isSelectingDestination = false;
          if (_currentPosition != null) {
            _routeCoordinates = [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(position.latitude, position.longitude)
            ];
            _updatePolylines();
          }
          _updateMarkers();
        });

        // Display route without starting the trip
        await _getRouteCoordinates();

        // Show confirmation to the user
        _showSnackBar(
            'Destination selected: $address. You can now start your trip.');
      }
    } catch (e) {
      _showSnackBar('Error selecting destination: $e');
    }
  }

  Future<void> _updateLocation() async {
    if (!_isTripActive) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Skip if this is the first position update
      if (_locationHistory.isEmpty) {
        setState(() {
          _currentPosition = position;
          _locationHistory.add(position);
          _updateMarkers();
          _updatePolylines();
        });
        return;
      }

      // Get the previous location
      Position previousPosition = _locationHistory.last;

      // Calculate distance from previous position
      double distanceInMeters = Geolocator.distanceBetween(
        previousPosition.latitude,
        previousPosition.longitude,
        position.latitude,
        position.longitude,
      );

      // Only update if moved more than accuracy threshold (5 meters)
      // This prevents small GPS fluctuations from being counted as movement
      if (distanceInMeters > 5) {
        setState(() {
          _currentPosition = position;
          _locationHistory.add(position);
          _updateMarkers();
          _updatePolylines();

          // Calculate distance and speed
          _calculateTripStats();

          // Check if we've reached the destination
          if (_hasReachedDestination()) {
            _stopTrip();
          }
        });

        if (_mapController != null) {
          _animateToCurrentPosition();
        }
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  void _updatePolylines() {
    _polylines.clear();

    if (_isTripActive) {
      // During active trip, only show the actual path traced by the user
      List<LatLng> actualPath = _locationHistory
          .map((position) => LatLng(position.latitude, position.longitude))
          .toList();

      if (actualPath.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('actual_path'),
            color: Colors.blue,
            points: actualPath,
            width: 5,
          ),
        );
      }
    } else {
      // Before trip starts, show the planned route line
      _polylines.add(
        Polyline(
          polylineId: PolylineId('planned_route'),
          color: Colors.blue,
          points: _routeCoordinates,
          width: 5,
        ),
      );
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Add current location marker (only if trip is not active)
    if (_currentPosition != null && !_isTripActive) {
      _markers.add(
        Marker(
          markerId: MarkerId('current_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(title: 'Current Location'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Add starting point marker if trip is active
    if (_isTripActive && _locationHistory.isNotEmpty) {
      Position startPosition = _locationHistory.first;
      _markers.add(
        Marker(
          markerId: MarkerId('start_location'),
          position: LatLng(startPosition.latitude, startPosition.longitude),
          infoWindow:
              InfoWindow(title: 'Starting Point', snippet: _startAddress),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      // Add current position marker with different color during active trip
      if (_currentPosition != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('current_location'),
            position:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: InfoWindow(title: 'Current Location'),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      }
    }

    // Add destination marker if available (always show it)
    if (_destinationPosition != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('destination'),
          position: LatLng(
              _destinationPosition!.latitude, _destinationPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _destinationAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _getRouteCoordinates() async {
    if (_currentPosition == null || _destinationPosition == null) return;

    try {
      // Instead of relying on the directions API which requires API key,
      // let's create a straight line from current position to destination
      // This is a simplification that doesn't require an API key
      setState(() {
        _routeCoordinates = [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(
              _destinationPosition!.latitude, _destinationPosition!.longitude)
        ];
        _updatePolylines();
      });
    } catch (e) {
      print('Error creating route: $e');
    }
  }

  void _calculateTripStats() {
    if (_locationHistory.length < 2) return;

    // Calculate total distance
    _totalDistance = 0;
    for (int i = 0; i < _locationHistory.length - 1; i++) {
      double segmentDistance = Geolocator.distanceBetween(
        _locationHistory[i].latitude,
        _locationHistory[i].longitude,
        _locationHistory[i + 1].latitude,
        _locationHistory[i + 1].longitude,
      );

      // Only add segment if it's significant movement (> 5 meters)
      // This helps filter out GPS jitter when stationary
      if (segmentDistance > 5) {
        _totalDistance += segmentDistance;
      }
    }

    // Convert to kilometers
    _totalDistance = _totalDistance / 1000;

    // Calculate average speed using the actual movement
    if (_tripStartTime != null) {
      final tripDuration = DateTime.now().difference(_tripStartTime!);
      final hours = tripDuration.inSeconds / 3600;
      if (hours > 0) {
        // Don't allow extremely low speeds to account for stationary periods
        double calculatedSpeed = _totalDistance / hours; // km/h
        _averageSpeed = calculatedSpeed;

        // If we're not moving (or very slowly), set speed close to zero
        if (_totalDistance < 0.01) {
          // Less than 10 meters
          _averageSpeed = 0.0;
        }
      }
    }
  }

  bool _hasReachedDestination() {
    if (_currentPosition == null || _destinationPosition == null) return false;

    // Calculate distance to destination
    final distanceToDestination = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _destinationPosition!.latitude,
      _destinationPosition!.longitude,
    );

    // Consider destination reached if within 100 meters
    return distanceToDestination < 100;
  }

  void _stopTrip() {
    setState(() {
      _isTripActive = false;
      _locationTimer?.cancel();
      _locationTimer = null;
      _tripEndTime = DateTime.now();
    });

    // Calculate final stats
    _calculateTripStats();

    // Determine transport mode based on average speed
    _selectedTransportMode = Trip.determineTransportMode(_averageSpeed);

    // If it's a motorized vehicle, ask for more details
    if (_averageSpeed >= 12) {
      _showTransportModeSelection();
    } else {
      // Show trip summary directly for walking or cycling
      _showTripSummary();
    }
  }

  void _showTransportModeSelection() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('What type of transport did you use?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.directions_bus, color: Colors.blue),
              title: Text('Public Transport'),
              onTap: () {
                setState(() {
                  _selectedTransportMode = TransportMode.publicTransport;
                });
                Navigator.pop(context);
                _showTripSummary();
              },
            ),
            ListTile(
              leading: Icon(Icons.people, color: Colors.green),
              title: Text('Ride Share'),
              onTap: () {
                setState(() {
                  _selectedTransportMode = TransportMode.rideShare;
                });
                Navigator.pop(context);
                _showTripSummary();
              },
            ),
            ListTile(
              leading: Icon(Icons.directions_car, color: Colors.red),
              title: Text('Own Vehicle'),
              onTap: () {
                setState(() {
                  _selectedTransportMode = TransportMode.ownVehicle;
                });
                Navigator.pop(context);
                _showTripSummary();
              },
            ),
          ],
        ),
      ),
    );
  }

  double _calculateCarbonCredits() {
    return Trip.calculateCarbonCredits(_selectedTransportMode, _totalDistance);
  }

  Future<void> _saveTrip() async {
    // Verify all required data is available
    if (_currentPosition == null ||
        _destinationPosition == null ||
        _tripStartTime == null ||
        _tripEndTime == null ||
        _locationHistory.isEmpty) {
      _showSnackBar('Cannot save trip: Missing required data');
      return;
    }

    setState(() {
      _isSavingTrip = true;
    });

    try {
      // Get user ID from auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.appUser?.uid;

      if (userId == null) {
        _showSnackBar('Cannot save trip: User not logged in');
        setState(() {
          _isSavingTrip = false;
        });
        return;
      }

      // Calculate carbon credits
      final carbonCredits = _calculateCarbonCredits();

      // Create trip object
      final trip = Trip(
        id: '', // ID will be assigned by Firestore
        userId: userId,
        startLocation: GeoPoint(
            _locationHistory.first.latitude, _locationHistory.first.longitude),
        endLocation:
            GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        startAddress: _startAddress,
        endAddress: _destinationAddress,
        startTime: _tripStartTime!,
        endTime: _tripEndTime!,
        tripDate: DateTime(
            _tripStartTime!.year, _tripStartTime!.month, _tripStartTime!.day),
        distanceKm: _totalDistance,
        avgSpeedKmh: _averageSpeed,
        transportMode: _selectedTransportMode,
        carbonCredits: carbonCredits,
      );

      // Save to Firestore
      await _tripService.saveTrip(trip);

      // Show success message
      _showSnackBar('Trip saved successfully!');

      // Return to home screen
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error saving trip: ${e.toString()}');
      print('Error details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTrip = false;
        });
      }
    }
  }

  void _showTripSummary() {
    // Calculate carbon credits based on selected transport mode
    final carbonCredits = _calculateCarbonCredits();

    // Format trip date and time for sharing
    final tripDate = _tripStartTime != null
        ? '${_tripStartTime!.year}-${_tripStartTime!.month.toString().padLeft(2, '0')}-${_tripStartTime!.day.toString().padLeft(2, '0')}'
        : 'Unknown';

    final tripDuration = _tripStartTime != null && _tripEndTime != null
        ? _tripEndTime!.difference(_tripStartTime!)
        : Duration.zero;

    final durationText = _formatDuration(tripDuration);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Trip Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip distance
            Row(
              children: [
                Icon(Icons.straighten, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Distance: ${_totalDistance.toStringAsFixed(2)} km',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Average speed - only shown in summary
            Row(
              children: [
                Icon(Icons.speed, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Average Speed: ${_averageSpeed.toStringAsFixed(2)} km/h',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Trip duration
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Duration: $durationText',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Transport mode
            Row(
              children: [
                Icon(Icons.directions, size: 18, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Transport Mode: ${_getTransportModeText(_selectedTransportMode)}',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Add estimated carbon credits earned
            Row(
              children: [
                Icon(Icons.eco, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Carbon Credits Earned: ${carbonCredits.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            // Share button - Add a more prominent share button
            SizedBox(height: 24),
            InkWell(
              onTap: () {
                _shareTrip(
                  distance: _totalDistance.toStringAsFixed(2),
                  speed: _averageSpeed.toStringAsFixed(2),
                  transportMode: _getTransportModeText(_selectedTransportMode),
                  credits: carbonCredits.toStringAsFixed(2),
                  date: tripDate,
                  duration: durationText,
                  startAddress: _startAddress ?? 'Unknown starting point',
                  endAddress: _destinationAddress ?? 'Unknown destination',
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Share Trip Details',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Dialog action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(
                      context); // Return to home screen without saving
                },
                child: Text('Discard'),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSavingTrip
                    ? null
                    : () {
                        Navigator.pop(context);
                        _saveTrip();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSavingTrip
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Save & Return'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  // Method to share trip details
  void _shareTrip({
    required String distance,
    required String speed,
    required String transportMode,
    required String credits,
    required String date,
    required String duration,
    required String startAddress,
    required String endAddress,
  }) {
    final String shareText = '''
🌿 Green Trip Summary 🌿

📆 Date: $date
⏱️ Duration: $duration
🚶 From: $startAddress
🏁 To: $endAddress
📏 Distance: $distance km
🚗 Transport Mode: $transportMode
⚡ Average Speed: $speed km/h
💰 Carbon Credits Earned: $credits

I'm helping the environment by tracking my carbon footprint with the Carbon Credit app! Join me in making a difference!
''';

    Share.share(shareText, subject: 'My Carbon-Saving Trip');
  }

  String _getTransportModeText(TransportMode mode) {
    switch (mode) {
      case TransportMode.walking:
        return 'Walking';
      case TransportMode.cycling:
        return 'Cycling';
      case TransportMode.publicTransport:
        return 'Public Transport';
      case TransportMode.rideShare:
        return 'Ride Share';
      case TransportMode.ownVehicle:
        return 'Own Vehicle';
      case TransportMode.unknown:
        return 'Unknown';
    }
  }

  // Search for locations by address
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        List<Placemark> placemarks = [];

        // Get placemark details for each location
        for (var location in locations.take(5)) {
          // Limit to 5 results
          List<Placemark> locationPlacemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (locationPlacemarks.isNotEmpty) {
            placemarks.add(locationPlacemarks.first);
          }
        }

        setState(() {
          _searchResults = placemarks;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        _showSnackBar('No results found for "$query"');
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _showSnackBar('Error searching for address: $e');
    }
  }

  // Select destination from search results
  void _selectDestinationFromSearch(
      Placemark placemark, Location location) async {
    // Clear search
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });

    // Create the full address
    String address =
        '${placemark.street}, ${placemark.locality}, ${placemark.country}';

    // Set the destination and create route
    setState(() {
      _destinationPosition = Position(
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _destinationAddress = address;
      _isSelectingDestination = false;

      if (_currentPosition != null) {
        _routeCoordinates = [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(location.latitude, location.longitude)
        ];
        _updatePolylines();
      }
      _updateMarkers();
    });

    // Get detailed route
    await _getRouteCoordinates();

    // Animate camera to show the route
    if (_mapController != null &&
        _destinationPosition != null &&
        _currentPosition != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(_currentPosition!.latitude, _destinationPosition!.latitude),
          min(_currentPosition!.longitude, _destinationPosition!.longitude),
        ),
        northeast: LatLng(
          max(_currentPosition!.latitude, _destinationPosition!.latitude),
          max(_currentPosition!.longitude, _destinationPosition!.longitude),
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }

    // Show confirmation
    _showSnackBar(
        'Destination selected: $address. You can now start your trip.');
  }

  // Helper function for min
  double min(double a, double b) => a < b ? a : b;

  // Helper function for max
  double max(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Tracking'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map
          _currentPosition == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 16.0,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    _controllerCompleter.complete(controller);
                    _mapController = controller;
                  },
                  onTap: _isSelectingDestination
                      ? (LatLng position) {
                          _confirmDestination(position);
                        }
                      : null,
                ),

          // Search Box - Only show during destination selection or before trip starts
          if (!_isTripActive)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search for destination address',
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 16),
                              ),
                              onSubmitted: (value) {
                                _searchPlaces(value);
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchResults = [];
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Search Results
                  if (_searchResults.isNotEmpty)
                    Card(
                      margin: EdgeInsets.only(top: 4),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            Placemark placemark = _searchResults[index];
                            String address =
                                '${placemark.street}, ${placemark.locality}, ${placemark.country}';

                            return ListTile(
                              leading: Icon(Icons.location_on),
                              title: Text(placemark.street ?? 'Unknown Street'),
                              subtitle: Text(address),
                              onTap: () async {
                                try {
                                  List<Location> locations =
                                      await locationFromAddress(address);
                                  if (locations.isNotEmpty) {
                                    _selectDestinationFromSearch(
                                        placemark, locations.first);
                                  }
                                } catch (e) {
                                  _showSnackBar('Error selecting location: $e');
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),

                  // Loading indicator
                  if (_isSearching)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Searching...'),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Trip Statistics Panel (only shown during active trip)
          if (_isTripActive)
            Positioned(
              top:
                  16, // Changed back to 16 since search box is hidden during trip
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatDisplay(
                        'Distance',
                        '${_totalDistance.toStringAsFixed(2)} km',
                        Icons.straighten,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Instruction text when selecting destination
          if (_isSelectingDestination)
            Positioned(
              top: 70, // Keep this adjusted for search box
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap on the map to select your destination',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Bottom button for all states
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBottomButton(),
        ),
      ),
    );
  }

  Widget _buildStatDisplay(
      String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    if (_isSelectingDestination) {
      // Cancel destination selection button
      return ElevatedButton(
        onPressed: () {
          setState(() {
            _isSelectingDestination = false;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancel Selection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (_destinationPosition != null && !_isTripActive) {
      // Start trip button (destination selected but trip not started)
      return ElevatedButton(
        onPressed: () {
          setState(() {
            _isTripActive = true;
            _tripStartTime = DateTime.now();

            // Clear location history and start fresh
            _locationHistory.clear();

            // Add current position as the starting point
            if (_currentPosition != null) {
              _locationHistory.add(_currentPosition!);

              // Save the starting address explicitly
              if (_startAddress == null || _startAddress!.isEmpty) {
                _getAddressFromPosition(_currentPosition!).then((address) {
                  setState(() {
                    _startAddress = address;
                  });
                });
              }
            }

            // Keep the destination visible during the trip, but clear planned route
            // since we'll create a new path based on actual movement
            _routeCoordinates.clear();

            // Update markers and polylines for trip start state
            _updateMarkers();
            _updatePolylines();

            // Start location tracking
            _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
              _updateLocation();
            });
          });

          // Fit both starting point and destination on the map
          _fitStartAndDestinationBounds();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Start Trip',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (_isTripActive) {
      // End trip button
      return ElevatedButton(
        onPressed: _stopTrip,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'End Trip',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      // Initial select destination button
      return ElevatedButton(
        onPressed: () {
          setState(() {
            _isSelectingDestination = true;
            _showSnackBar('Tap on the map to select your destination');
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Select Destination',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  // Helper method to fit both start and destination on the map
  void _fitStartAndDestinationBounds() {
    if (_mapController != null &&
        _destinationPosition != null &&
        _currentPosition != null) {
      // Create bounds that include both points with some padding
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(_currentPosition!.latitude, _destinationPosition!.latitude) -
              0.01,
          min(_currentPosition!.longitude, _destinationPosition!.longitude) -
              0.01,
        ),
        northeast: LatLng(
          max(_currentPosition!.latitude, _destinationPosition!.latitude) +
              0.01,
          max(_currentPosition!.longitude, _destinationPosition!.longitude) +
              0.01,
        ),
      );

      // Animate camera to show both points
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // Helper method to get address from position
  Future<String> _getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    return 'Unknown location';
  }
}
