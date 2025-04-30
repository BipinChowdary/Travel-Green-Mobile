import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';
import '../models/app_user.dart';
import 'trip_screen.dart';
import 'all_activities_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TripService _tripService = TripService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Trip> _recentTrips = [];
  bool _isLoadingTrips = false;
  bool _isLoadingLeaderboard = true;
  double _totalCarbonCredits = 0.0;
  List<Map<String, dynamic>> _leaderboardData = [];

  @override
  void initState() {
    super.initState();
    _loadRecentTrips();
    _loadLeaderboardData();
  }

  Future<void> _loadRecentTrips() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.appUser?.uid;

    if (userId == null) return;

    setState(() {
      _isLoadingTrips = true;
    });

    try {
      // Get all trips for this user
      final allTrips = await _tripService.getUserTrips(userId);

      // Calculate total carbon credits from all trips
      // This calculates credits directly from trips instead of using the user.carbonCredits field
      double totalCredits = 0.0;
      for (var trip in allTrips) {
        totalCredits += trip.carbonCredits;
      }

      if (mounted) {
        setState(() {
          _recentTrips =
              allTrips.take(3).toList(); // Just take the 3 most recent trips
          _totalCarbonCredits = totalCredits;
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      print('Error loading trips: $e');

      if (mounted) {
        setState(() {
          _recentTrips = [];
          _isLoadingTrips = false;
        });

        // Show a non-intrusive error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load recent trips'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Load the leaderboard data
  Future<void> _loadLeaderboardData() async {
    setState(() {
      _isLoadingLeaderboard = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.appUser;

      if (currentUser == null ||
          currentUser.organizationName == null ||
          currentUser.organizationName!.isEmpty) {
        setState(() {
          _isLoadingLeaderboard = false;
        });
        return;
      }

      // Get all users from the same organization
      final usersSnapshot = await _firestore
          .collection('users')
          .where('organizationName', isEqualTo: currentUser.organizationName)
          .get();

      List<Map<String, dynamic>> leaderboard = [];

      // For each user, fetch their trips and calculate total credits
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Skip if this is the current user's document
        if (userId == currentUser.uid) continue;

        // Get all trips for this user
        final trips = await _tripService.getUserTrips(userId);

        // Calculate total carbon credits
        double totalCredits = 0.0;
        for (var trip in trips) {
          totalCredits += trip.carbonCredits;
        }

        // Determine badge based on credits
        String badge = _determineBadge(totalCredits);

        leaderboard.add({
          'userId': userId,
          'name': userData['name'] ?? 'Unknown',
          'credits': totalCredits,
          'badge': badge,
        });
      }

      // Add current user to the leaderboard
      String currentUserBadge = _determineBadge(_totalCarbonCredits);
      leaderboard.add({
        'userId': currentUser.uid,
        'name': currentUser.name,
        'credits': _totalCarbonCredits,
        'badge': currentUserBadge,
        'isCurrentUser': true,
      });

      // Sort by credits in descending order
      leaderboard.sort((a, b) => b['credits'].compareTo(a['credits']));

      // Assign ranks
      for (int i = 0; i < leaderboard.length; i++) {
        leaderboard[i]['rank'] = i + 1;
      }

      if (mounted) {
        setState(() {
          _leaderboardData = leaderboard;
          _isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      print('Error loading leaderboard data: $e');
      if (mounted) {
        setState(() {
          _isLoadingLeaderboard = false;
        });
      }
    }
  }

  // Determine badge based on credits
  String _determineBadge(double credits) {
    if (credits >= 100) {
      return 'Diamond';
    } else if (credits >= 50) {
      return 'Platinum';
    } else if (credits >= 25) {
      return 'Gold';
    } else if (credits >= 10) {
      return 'Silver';
    } else {
      return 'Bronze';
    }
  }

  // Get badge icon and color
  IconData _getBadgeIcon(String badge) {
    switch (badge) {
      case 'Diamond':
        return Icons.diamond;
      case 'Platinum':
        return Icons.workspace_premium;
      case 'Gold':
        return Icons.military_tech;
      case 'Silver':
        return Icons.stars;
      case 'Bronze':
      default:
        return Icons.emoji_events;
    }
  }

  // Get badge color
  Color _getBadgeColor(String badge) {
    switch (badge) {
      case 'Diamond':
        return Colors.lightBlueAccent;
      case 'Platinum':
        return Colors.purpleAccent;
      case 'Gold':
        return Colors.amberAccent;
      case 'Silver':
        return Colors.grey.shade400;
      case 'Bronze':
      default:
        return Colors.brown.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.appUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadRecentTrips(),
            _loadLeaderboardData(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome section with gradient
              Container(
                padding: EdgeInsets.only(
                    left: 20.0, right: 20.0, top: 30.0, bottom: 30.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.name ?? 'User'}!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Let\'s make a positive impact today',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 25),

                    // Credit counter circle
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Carbon Credit Balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${_totalCarbonCredits.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.eco,
                              color: Colors.green[700],
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24),

                    // Start New Activity button
                    Container(
                      decoration: BoxDecoration(
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _showStartActivityOptions(context);
                          },
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.directions_car,
                                    color: Colors.green[700],
                                    size: 32,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start New Activity',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Track your journey and earn carbon credits',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 30),

                    // Leaderboard section
                    _buildLeaderboardSection(),

                    SizedBox(height: 30),

                    // Recent trips section
                    if (_recentTrips.isNotEmpty || _isLoadingTrips) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activities',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (_recentTrips.length >= 3)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AllActivitiesScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'See All',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12),
                      if (_isLoadingTrips)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ...(_recentTrips
                            .map((trip) => _buildTripCard(trip))
                            .toList()),
                    ] else ...[
                      SizedBox(height: 30),
                      _buildEmptyState(),
                    ],

                    SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(24),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk,
            size: 48,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 18,
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
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    try {
      // Format dates for display with null safety
      final date = trip.startTime != null
          ? '${trip.startTime.day}/${trip.startTime.month}/${trip.startTime.year}'
          : 'Unknown date';

      // Get transport mode icon
      IconData modeIcon;
      Color iconColor;

      // Special handling for work from home entries
      if (trip.isWorkFromHome) {
        modeIcon = Icons.home_work;
        iconColor = Colors.blue;
      } else {
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTransportModeText(
                                trip.transportMode, trip.isWorkFromHome),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
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
                  SizedBox(height: 16),

                  // Trip stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildTripStat(Icons.straighten, 'Distance',
                            '${trip.distanceKm.toStringAsFixed(2)} km'),
                      ),
                      Expanded(
                        child: _buildTripStat(Icons.speed, 'Speed',
                            '${trip.avgSpeedKmh.toStringAsFixed(2)} km/h'),
                      ),
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
                              fontSize: 14,
                            ),
                            maxLines: 1,
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
    } catch (e) {
      // Fallback card for any rendering errors
      print('Error rendering trip card: $e');
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
        padding: EdgeInsets.all(16),
        child: Text(
          'Trip data unavailable',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildTripStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ],
    );
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
        ? '${trip.endTime.difference(trip.startTime).inMinutes} min'
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
              // Title, share button and close button
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
                  Row(
                    children: [
                      // Share button
                      IconButton(
                        icon: Icon(Icons.share, color: Colors.blue),
                        tooltip: 'Share Trip Details',
                        onPressed: () => _shareTrip(
                          distance: trip.distanceKm.toStringAsFixed(2),
                          speed: trip.avgSpeedKmh.toStringAsFixed(2),
                          transportMode: _getTransportModeText(
                              trip.transportMode, trip.isWorkFromHome),
                          credits: trip.carbonCredits.toStringAsFixed(2),
                          date: date,
                          duration: duration,
                          startAddress:
                              trip.startAddress ?? 'Unknown starting point',
                          endAddress: trip.endAddress ?? 'Unknown destination',
                        ),
                      ),
                      // Close button
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),

              // Trip map (moved to the top for more prominence)
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
                              _getTransportModeText(
                                  trip.transportMode, trip.isWorkFromHome),
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

                        // Add a Share button at the end
                        Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _shareTrip(
                            distance: trip.distanceKm.toStringAsFixed(2),
                            speed: trip.avgSpeedKmh.toStringAsFixed(2),
                            transportMode: _getTransportModeText(
                                trip.transportMode, trip.isWorkFromHome),
                            credits: trip.carbonCredits.toStringAsFixed(2),
                            date: date,
                            duration: duration,
                            startAddress:
                                trip.startAddress ?? 'Unknown starting point',
                            endAddress:
                                trip.endAddress ?? 'Unknown destination',
                          ),
                          icon: Icon(Icons.share, size: 18),
                          label: Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
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

  String _getTransportModeText(TransportMode mode, bool isWorkFromHome) {
    if (isWorkFromHome) {
      return 'Work from Home';
    }
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

  // Add this new method to show the activity options dialog
  void _showStartActivityOptions(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start New Activity',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  'Choose an activity to earn carbon credits',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),

                // Work from Home option
                _buildActivityOption(
                  icon: Icons.home_work,
                  iconColor: Colors.blue,
                  title: 'Work from Home',
                  subtitle: 'Earn 3 carbon credits automatically',
                  onTap: () {
                    Navigator.pop(context);
                    _recordWorkFromHome();
                  },
                ),

                SizedBox(height: 15),
                Divider(),
                SizedBox(height: 15),

                // Start a Trip option
                _buildActivityOption(
                  icon: Icons.directions,
                  iconColor: theme.colorScheme.primary,
                  title: 'Start a Trip',
                  subtitle: 'Track your journey and earn credits',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TripScreen()),
                    ).then((_) => _loadRecentTrips());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to build an activity option in the dialog
  Widget _buildActivityOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: iconColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to record work from home activity
  Future<void> _recordWorkFromHome() async {
    setState(() {
      _isLoadingTrips = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.appUser?.uid;

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Create a work from home trip
      final now = DateTime.now();

      // Create a trip with standard values for work from home
      Trip workFromHomeTrip = Trip(
        id: '', // Will be set by Firestore
        userId: userId,
        startLocation: const GeoPoint(0, 0), // Dummy location
        endLocation: const GeoPoint(0, 0), // Dummy location
        startTime: now,
        endTime: now.add(Duration(hours: 8)), // Standard 8-hour workday
        tripDate: now,
        distanceKm: 0, // No distance traveled
        avgSpeedKmh: 0, // No speed
        transportMode: TransportMode.unknown, // Special mode for WFH
        carbonCredits: 3.0, // Fixed 3 credits for WFH
        startAddress: 'Home',
        endAddress: 'Home',
        isWorkFromHome: true, // Mark as work from home
      );

      // Save the trip
      await _tripService.saveTrip(workFromHomeTrip);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work from home recorded! You earned 3 credits.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error recording work from home: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record work from home'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        // Reload trips to update the UI with the new work from home entry
        _loadRecentTrips();
      }
    }
  }

  // Build the leaderboard section widget
  Widget _buildLeaderboardSection() {
    if (_isLoadingLeaderboard) {
      return Container(
        padding: EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Leaderboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 15),
            Center(
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 10),
          ],
        ),
      );
    }

    if (_leaderboardData.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Leaderboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 15),
            Center(
              child: Text(
                'No leaderboard data available',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Only show top 5 users in leaderboard
    final displayData = _leaderboardData.length > 5
        ? _leaderboardData.sublist(0, 5)
        : _leaderboardData;

    // Check if current user is in top 5
    bool currentUserInTop5 =
        displayData.any((user) => user['isCurrentUser'] == true);

    // If not, find current user's entry and add it to display data
    Map<String, dynamic>? currentUserData;
    if (!currentUserInTop5) {
      currentUserData = _leaderboardData.firstWhere(
        (user) => user['isCurrentUser'] == true,
        orElse: () => Map<String, dynamic>(),
      );
    }

    // Show top 3 medals if we have at least 3 entries
    bool showTopMedals = _leaderboardData.length >= 3;

    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Organization Leaderboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Top 5',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Top 3 medals display
          if (showTopMedals) ...[
            _buildTopThreeMedalsRow(),
            SizedBox(height: 20),
            Divider(thickness: 1),
            SizedBox(height: 15),
          ],

          // Table header
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 30,
                    child: Text('Rank',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Employee',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(
                    width: 80,
                    child: Text('Credits',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                SizedBox(
                    width: 70,
                    child: Text('Badge',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Leaderboard entries
          ...displayData.map((entry) => _buildLeaderboardEntry(entry)).toList(),

          // If current user is not in top 5, show their entry separately
          if (!currentUserInTop5 &&
              currentUserData != null &&
              currentUserData.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                thickness: 1,
                color: Colors.grey[300],
              ),
            ),
            _buildLeaderboardEntry(currentUserData),
          ],
        ],
      ),
    );
  }

  // New method to build the top 3 medals row
  Widget _buildTopThreeMedalsRow() {
    if (_leaderboardData.length < 3) return SizedBox.shrink();

    final top3 = _leaderboardData.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place (left)
        _buildTopMedalItem(top3[1], 2, 0.85),

        SizedBox(width: 10),

        // 1st place (center, taller)
        _buildTopMedalItem(top3[0], 1, 1.0),

        SizedBox(width: 10),

        // 3rd place (right)
        _buildTopMedalItem(top3[2], 3, 0.7),
      ],
    );
  }

  // New method to build a single medal item
  Widget _buildTopMedalItem(
      Map<String, dynamic> user, int position, double scaleFactor) {
    final bool isCurrentUser = user['isCurrentUser'] == true;
    final IconData medalIcon = position == 1
        ? Icons.emoji_events
        : position == 2
            ? Icons.workspace_premium
            : Icons.military_tech;

    final Color medalColor = position == 1
        ? Colors.amber
        : position == 2
            ? Colors.blueGrey
            : Colors.brown;

    // For the podium display, get medal based on position
    final String medalName = position == 1
        ? 'Gold'
        : position == 2
            ? 'Silver'
            : 'Bronze';

    // Calculate the heights based on scale factor
    final double containerHeight = 110 * scaleFactor;
    final double avatarSize = 40 * scaleFactor;
    final double medalSize = 24 * scaleFactor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: containerHeight,
          width: 80,
          decoration: BoxDecoration(
            color: isCurrentUser
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: isCurrentUser
                ? Border.all(color: Colors.green.shade300, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Medal icon on top
              Icon(
                medalIcon,
                color: medalColor,
                size: medalSize,
              ),

              SizedBox(height: 4),

              // User avatar/initial
              CircleAvatar(
                radius: avatarSize / 2,
                backgroundColor: Colors.grey[200],
                child: Text(
                  user['name'].toString().isNotEmpty
                      ? user['name'][0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),

              SizedBox(height: 4),

              // Medal name
              Text(
                medalName,
                style: TextStyle(
                  fontSize: 11 * scaleFactor,
                  fontWeight: FontWeight.bold,
                  color: medalColor,
                ),
              ),

              // Credits
              Text(
                '${user['credits'].toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 10 * scaleFactor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Container(
          width: 80,
          child: Text(
            user['name'],
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          position == 1
              ? '🥇 1st'
              : position == 2
                  ? '🥈 2nd'
                  : '🥉 3rd',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Build a single leaderboard entry
  Widget _buildLeaderboardEntry(Map<String, dynamic> entry) {
    bool isCurrentUser = entry['isCurrentUser'] == true;
    Color bgColor =
        isCurrentUser ? Colors.green.withOpacity(0.1) : Colors.transparent;

    // Medal based on rank
    Widget medalWidget;
    int rank = entry['rank'];

    if (rank == 1) {
      medalWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 20),
          SizedBox(width: 4),
          Text(
            'Gold',
            style: TextStyle(
              fontSize: 12,
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (rank == 2) {
      medalWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium, color: Colors.blueGrey, size: 20),
          SizedBox(width: 4),
          Text(
            'Silver',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (rank == 3) {
      medalWidget = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.military_tech, color: Colors.brown, size: 20),
          SizedBox(width: 4),
          Text(
            'Bronze',
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // For ranks beyond 3, don't show any medal or badge
      medalWidget = SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 30,
            child: Text(
              '#${entry['rank']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getRankColor(entry['rank']),
              ),
            ),
          ),
          SizedBox(width: 10),

          // Name
          Expanded(
            child: Text(
              '${entry['name']}${isCurrentUser ? ' (You)' : ''}',
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Credits
          SizedBox(
            width: 80,
            child: Text(
              '${entry['credits'].toStringAsFixed(1)}',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),

          // Medal (only for top 3)
          SizedBox(
            width: 70,
            child: medalWidget,
          ),
        ],
      ),
    );
  }

  // Get color based on rank
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blueGrey;
      case 3:
        return Colors.brown;
      default:
        return Colors.grey;
    }
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
}
