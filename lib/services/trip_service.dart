import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../providers/auth_provider.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _tripsCollection => _firestore.collection('trips');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Save a new trip to Firestore
  Future<String> saveTrip(Trip trip) async {
    try {
      // Create new document in trips collection
      DocumentReference tripRef =
          await _tripsCollection.add(trip.toFirestore());

      print('Saved trip to Firestore with ID: ${tripRef.id}');
      print('Trip carbon credits: ${trip.carbonCredits}');

      // Update the user's carbon credits
      await _updateUserCarbonCredits(trip.userId, trip.carbonCredits);

      return tripRef.id;
    } catch (e) {
      print('Error saving trip: $e');
      // Still try to update user carbon credits even if trip saving fails
      try {
        await _updateUserCarbonCredits(trip.userId, trip.carbonCredits);
      } catch (creditError) {
        print('Additional error updating carbon credits: $creditError');
      }
      throw e;
    }
  }

  // Update user's carbon credits in Firestore
  Future<void> _updateUserCarbonCredits(
      String userId, double creditsToAdd) async {
    try {
      // Get current user document
      DocumentSnapshot userDoc = await _usersCollection.doc(userId).get();

      if (userDoc.exists) {
        // Extract current credits
        double currentCredits = 0.0;
        final userData = userDoc.data() as Map<String, dynamic>?;

        if (userData != null) {
          if (userData.containsKey('carbonCredits') &&
              userData['carbonCredits'] is num) {
            currentCredits = (userData['carbonCredits'] as num).toDouble();
          }

          // Add new credits
          double newCredits = currentCredits + creditsToAdd;

          // Update the user document
          await _usersCollection
              .doc(userId)
              .update({'carbonCredits': newCredits});

          print(
              'Updated user carbon credits: $currentCredits + $creditsToAdd = $newCredits');
        } else {
          // If userData is null or doesn't have carbonCredits, create it with the new credits
          await _usersCollection
              .doc(userId)
              .update({'carbonCredits': creditsToAdd});

          print('Created user carbon credits field with value: $creditsToAdd');
        }
      } else {
        print('User document does not exist for userId: $userId');
      }
    } catch (e) {
      print('Error updating user carbon credits: $e');
      // Don't rethrow the error to prevent trip saving from failing
    }
  }

  // Get all trips for a specific user
  Future<List<Trip>> getUserTrips(
    String userId, {
    int? limit,
    Trip? startAfterTrip,
  }) async {
    try {
      // Start with the basic query
      Query query = _tripsCollection.where('userId', isEqualTo: userId);

      // Add pagination if needed
      if (startAfterTrip != null && startAfterTrip.tripDate != null) {
        // Use the tripDate field for pagination
        query = query.where('tripDate', isLessThan: startAfterTrip.tripDate);
      }

      // Apply limit if specified
      if (limit != null) {
        query = query.limit(limit);
      }

      // Execute the query
      QuerySnapshot querySnapshot = await query.get();

      // Convert documents to Trip objects
      List<Trip> trips =
          querySnapshot.docs.map((doc) => Trip.fromFirestore(doc)).toList();

      // Sort by tripDate in descending order (newest first)
      trips.sort((a, b) => b.tripDate.compareTo(a.tripDate));

      return trips;
    } catch (e) {
      print('Error getting user trips: $e');
      return [];
    }
  }

  // Get a specific trip by ID
  Future<Trip?> getTripById(String tripId) async {
    try {
      DocumentSnapshot doc = await _tripsCollection.doc(tripId).get();

      if (doc.exists) {
        return Trip.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      print('Error getting trip: $e');
      return null;
    }
  }
}
