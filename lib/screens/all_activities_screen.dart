import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

class AllActivitiesScreen extends StatefulWidget {
  const AllActivitiesScreen({super.key});

  @override
  State<AllActivitiesScreen> createState() => _AllActivitiesScreenState();
}

class _AllActivitiesScreenState extends State<AllActivitiesScreen> {
  final TripService _tripService = TripService();
  List<Trip> _trips = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Pagination control
  bool _hasMoreTrips = true;
  bool _isLoadingMore = false;
  final int _pageSize = 10;
  Trip? _lastVisibleTrip;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTrips();

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (_hasMoreTrips && !_isLoadingMore) {
          _loadMoreTrips();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.appUser?.uid;

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Refresh user data to get latest carbon credit balance
      await authProvider.refreshUserData();

      // Get first page of trips
      final trips = await _tripService.getUserTrips(userId, limit: _pageSize);

      setState(() {
        _trips = trips;
        _isLoading = false;
        _hasMoreTrips = trips.length >= _pageSize;
        if (trips.isNotEmpty) {
          _lastVisibleTrip = trips.last;
        }
      });
    } catch (e) {
      print('Error loading trips: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load trips';
      });
    }
  }

  Future<void> _loadMoreTrips() async {
    if (!_hasMoreTrips || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.appUser?.uid;

      if (userId == null) return;

      final moreTrips = await _tripService.getUserTrips(
        userId,
        limit: _pageSize,
        startAfterTrip: _lastVisibleTrip,
      );

      setState(() {
        _trips.addAll(moreTrips);
        _isLoadingMore = false;
        _hasMoreTrips = moreTrips.length >= _pageSize;
        if (moreTrips.isNotEmpty) {
          _lastVisibleTrip = moreTrips.last;
        }
      });
    } catch (e) {
      print('Error loading more trips: $e');
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading more activities'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('All Activities'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorView()
              : _trips.isEmpty
                  ? _buildEmptyView()
                  : _buildTripsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage.isEmpty
                  ? 'Failed to load activities'
                  : _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTrips,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_walk,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No activities yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start tracking your journeys to earn carbon credits',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/trip');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Start New Activity'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount: _trips.length + (_hasMoreTrips ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _trips.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return _buildTripCard(_trips[index]);
        },
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    // Format dates for display with null safety
    final date = trip.startTime != null
        ? '${trip.startTime.day}/${trip.startTime.month}/${trip.startTime.year}'
        : 'Unknown date';

    final time = trip.startTime != null
        ? '${trip.startTime.hour.toString().padLeft(2, '0')}:${trip.startTime.minute.toString().padLeft(2, '0')}'
        : '';

    final duration = trip.startTime != null && trip.endTime != null
        ? _formatDuration(trip.endTime.difference(trip.startTime))
        : 'Unknown';

    // Get transport mode icon
    IconData modeIcon;
    Color iconColor;

    switch (trip.transportMode) {
      case TransportMode.walking:
        modeIcon = Icons.directions_walk;
        iconColor = Colors.green;
        break;
      case TransportMode.cycling:
        modeIcon = Icons.directions_bike;
        iconColor = Colors.lightGreen;
        break;
      case TransportMode.publicTransport:
        modeIcon = Icons.directions_bus;
        iconColor = Colors.blue;
        break;
      case TransportMode.rideShare:
        modeIcon = Icons.people;
        iconColor = Colors.orange;
        break;
      case TransportMode.ownVehicle:
        modeIcon = Icons.directions_car;
        iconColor = Colors.red;
        break;
      default:
        modeIcon = Icons.help_outline;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTripDetailsBottomSheet(trip),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(modeIcon, color: iconColor, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTransportModeText(trip.transportMode),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (time.isNotEmpty) ...[
                                Text(
                                  ' • $time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.eco,
                            color: Colors.green[700],
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            trip.carbonCredits.toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(),
                SizedBox(height: 12),

                // Trip stats
                Row(
                  children: [
                    _buildTripStat(Icons.straighten, 'Distance',
                        '${trip.distanceKm.toStringAsFixed(2)} km'),
                    SizedBox(width: 24),
                    _buildTripStat(Icons.speed, 'Speed',
                        '${trip.avgSpeedKmh.toStringAsFixed(2)} km/h'),
                    SizedBox(width: 24),
                    _buildTripStat(Icons.timer, 'Duration', duration),
                  ],
                ),

                if (trip.startAddress != null && trip.endAddress != null) ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.route, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${trip.startAddress} to ${trip.endAddress}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[500]),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
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

  void _showTripDetailsBottomSheet(Trip trip) {
    // Format dates
    final date = trip.startTime != null
        ? '${trip.startTime.day}/${trip.startTime.month}/${trip.startTime.year}'
        : 'Unknown date';

    final startTime = trip.startTime != null
        ? '${trip.startTime.hour}:${trip.startTime.minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    final endTime = trip.endTime != null
        ? '${trip.endTime.hour}:${trip.endTime.minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    final duration = trip.startTime != null && trip.endTime != null
        ? _formatDuration(trip.endTime.difference(trip.startTime))
        : 'Unknown';

    // Get transport mode icon
    IconData modeIcon;
    Color iconColor;

    switch (trip.transportMode) {
      case TransportMode.walking:
        modeIcon = Icons.directions_walk;
        iconColor = Colors.green;
        break;
      case TransportMode.cycling:
        modeIcon = Icons.directions_bike;
        iconColor = Colors.lightGreen;
        break;
      case TransportMode.publicTransport:
        modeIcon = Icons.directions_bus;
        iconColor = Colors.blue;
        break;
      case TransportMode.rideShare:
        modeIcon = Icons.people;
        iconColor = Colors.orange;
        break;
      case TransportMode.ownVehicle:
        modeIcon = Icons.directions_car;
        iconColor = Colors.red;
        break;
      default:
        modeIcon = Icons.help_outline;
        iconColor = Colors.grey;
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              // Trip map
              Container(
                height: MediaQuery.of(context).size.height * 0.3,
                margin: EdgeInsets.symmetric(vertical: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: trip.startLocation != null && trip.endLocation != null
                    ? _buildTripMap(trip)
                    : Center(child: Text('Map data not available')),
              ),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  children: [
                    // Trip header with date and mode
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            modeIcon,
                            color: iconColor,
                            size: 32,
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getTransportModeText(trip.transportMode),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              date,
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Trip stats as simple text fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTextField(
                            'Distance',
                            '${trip.distanceKm.toStringAsFixed(2)} km',
                            Icons.straighten),
                        _buildTextField(
                            'Avg. Speed',
                            '${trip.avgSpeedKmh.toStringAsFixed(2)} km/h',
                            Icons.speed),
                      ],
                    ),

                    SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTextField('Duration', duration, Icons.timer),
                        _buildTextField(
                            'Carbon Credits',
                            '${trip.carbonCredits.toStringAsFixed(2)}',
                            Icons.eco),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Trip location details
                    Text(
                      'Location Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Start location
                    _buildLocationField(
                      'Start Location',
                      '${startTime}',
                      trip.startAddress ?? 'Address not available',
                      Icons.trip_origin,
                      Colors.green,
                    ),

                    SizedBox(height: 16),

                    // End location
                    _buildLocationField(
                      'End Location',
                      '${endTime}',
                      trip.endAddress ?? 'Address not available',
                      Icons.place,
                      Colors.red,
                    ),

                    SizedBox(height: 32),

                    // Full-width share button
                    ElevatedButton(
                      onPressed: () => _shareTrip(trip),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Share This Trip',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[700]),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField(
      String label, String time, String address, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 8),
            Text(
              '$label: $time',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 24),
          child: Text(
            address,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildTripMap(Trip trip) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          trip.startLocation.latitude,
          trip.startLocation.longitude,
        ),
        zoom: 12,
      ),
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: MarkerId('start'),
          position: LatLng(
            trip.startLocation.latitude,
            trip.startLocation.longitude,
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: MarkerId('end'),
          position: LatLng(
            trip.endLocation.latitude,
            trip.endLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      },
      polylines: {
        Polyline(
          polylineId: PolylineId('route'),
          points: [
            LatLng(trip.startLocation.latitude, trip.startLocation.longitude),
            LatLng(trip.endLocation.latitude, trip.endLocation.longitude),
          ],
          color: Colors.blue,
          width: 5,
        ),
      },
    );
  }

  void _shareTrip(Trip trip) {
    // Format dates with null safety
    final date = trip.startTime != null
        ? '${trip.startTime.day}/${trip.startTime.month}/${trip.startTime.year}'
        : 'Unknown date';

    final time = trip.startTime != null
        ? '${trip.startTime.hour.toString().padLeft(2, '0')}:${trip.startTime.minute.toString().padLeft(2, '0')}'
        : '';

    final duration = trip.startTime != null && trip.endTime != null
        ? _formatDuration(trip.endTime.difference(trip.startTime))
        : 'Unknown';

    // Create a nicely formatted share message
    String shareText = 'My Eco-Friendly Trip 🌿\n\n';
    shareText += 'Date: $date\n';
    if (time.isNotEmpty) shareText += 'Time: $time\n';
    shareText += 'Mode: ${_getTransportModeText(trip.transportMode)}\n';
    shareText += 'Distance: ${trip.distanceKm.toStringAsFixed(2)} km\n';
    shareText += 'Duration: $duration\n';
    shareText +=
        'Carbon Credits Earned: ${trip.carbonCredits.toStringAsFixed(2)}\n';

    if (trip.startAddress != null && trip.endAddress != null) {
      shareText += 'Route: ${trip.startAddress} to ${trip.endAddress}\n';
    }

    shareText += '\nTracked with Carbon Credit App 🌎';

    // Share the text
    Share.share(shareText);
  }
}
