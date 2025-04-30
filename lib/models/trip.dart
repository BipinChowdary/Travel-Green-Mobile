import 'package:cloud_firestore/cloud_firestore.dart';

enum TransportMode {
  walking,
  cycling,
  publicTransport,
  rideShare,
  ownVehicle,
  unknown
}

class Trip {
  final String id;
  final String userId;

  // Trip locations
  final GeoPoint startLocation;
  final GeoPoint endLocation;
  final String? startAddress;
  final String? endAddress;

  // Trip timing
  final DateTime startTime;
  final DateTime endTime;
  final DateTime tripDate;

  // Trip metrics
  final double distanceKm;
  final double avgSpeedKmh;
  final TransportMode transportMode;

  // Carbon credits
  final double carbonCredits;

  // Work from home flag
  final bool isWorkFromHome;

  Trip({
    required this.id,
    required this.userId,
    required this.startLocation,
    required this.endLocation,
    this.startAddress,
    this.endAddress,
    required this.startTime,
    required this.endTime,
    required this.tripDate,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.transportMode,
    required this.carbonCredits,
    this.isWorkFromHome = false,
  });

  // Convert Firestore data to Trip object
  factory Trip.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Trip(
      id: doc.id,
      userId: data['userId'] ?? '',
      startLocation: data['startLocation'] ?? const GeoPoint(0, 0),
      endLocation: data['endLocation'] ?? const GeoPoint(0, 0),
      startAddress: data['startAddress'],
      endAddress: data['endAddress'],
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : DateTime.now(),
      tripDate: data['tripDate'] != null
          ? (data['tripDate'] as Timestamp).toDate()
          : DateTime.now(),
      distanceKm: (data['distanceKm'] is num)
          ? (data['distanceKm'] as num).toDouble()
          : 0.0,
      avgSpeedKmh: (data['avgSpeedKmh'] is num)
          ? (data['avgSpeedKmh'] as num).toDouble()
          : 0.0,
      transportMode: _stringToTransportMode(data['transportMode'] ?? 'unknown'),
      carbonCredits: (data['carbonCredits'] is num)
          ? (data['carbonCredits'] as num).toDouble()
          : 0.0,
      isWorkFromHome: data['isWorkFromHome'] ?? false,
    );
  }

  // Convert Trip object to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'tripDate': Timestamp.fromDate(tripDate),
      'distanceKm': distanceKm,
      'avgSpeedKmh': avgSpeedKmh,
      'transportMode': transportMode.toString().split('.').last,
      'carbonCredits': carbonCredits,
      'isWorkFromHome': isWorkFromHome,
    };
  }

  // Helper method to calculate carbon credits based on transport mode and distance
  static double calculateCarbonCredits(TransportMode mode, double distanceKm) {
    switch (mode) {
      case TransportMode.walking:
        return distanceKm * 0.2; // 0.2 credits per km for walking
      case TransportMode.cycling:
        return distanceKm * 0.15; // 0.15 credits per km for cycling
      case TransportMode.publicTransport:
        return distanceKm * 0.1; // 0.1 credits per km for public transport
      case TransportMode.rideShare:
        return distanceKm * 0.08; // 0.08 credits per km for ride sharing
      case TransportMode.ownVehicle:
        return distanceKm * 0.02; // 0.02 credits per km for own vehicle
      case TransportMode.unknown:
        return distanceKm * 0.01; // 0.01 credits per km for unknown transport
    }
  }

  // Helper method to determine transport mode based on average speed
  static TransportMode determineTransportMode(double avgSpeedKmh) {
    if (avgSpeedKmh < 5) {
      return TransportMode.walking;
    } else if (avgSpeedKmh >= 5 && avgSpeedKmh < 12) {
      return TransportMode.cycling;
    } else {
      return TransportMode.unknown; // Will be updated after user selection
    }
  }

  // Helper method to convert string to TransportMode enum
  static TransportMode _stringToTransportMode(String mode) {
    switch (mode) {
      case 'walking':
        return TransportMode.walking;
      case 'cycling':
        return TransportMode.cycling;
      case 'publicTransport':
        return TransportMode.publicTransport;
      case 'rideShare':
        return TransportMode.rideShare;
      case 'ownVehicle':
        return TransportMode.ownVehicle;
      default:
        return TransportMode.unknown;
    }
  }
}
