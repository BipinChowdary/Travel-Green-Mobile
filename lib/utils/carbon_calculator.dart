import 'package:flutter/material.dart';

/// A utility class for calculating carbon credits based on sustainable activities
class CarbonCalculator {
  /// Calculates carbon credits earned for various sustainable activities
  ///
  /// [activityType] - Type of sustainable activity (e.g., public_transport, recycling)
  /// [activityAmount] - Amount of activity done (units depend on activity type)
  ///
  /// Returns the number of carbon credits earned
  static double calculateActivityCredits({
    required String activityType,
    required double activityAmount,
  }) {
    // Credit multipliers for different activities
    // These values can be adjusted based on desired incentives
    final Map<String, double> creditMultipliers = {
      'public_transport': 0.05, // Credits per km
      'renewable_energy': 0.02, // Credits per kWh
      'recycling': 0.5, // Credits per kg
      'tree_planting': 5.0, // Credits per tree
      'local_food': 0.5, // Credits per meal
      'vegetarian_meal': 0.8, // Credits per meal
      'vegan_meal': 1.2, // Credits per meal
    };

    // Get the appropriate multiplier for the activity type
    final multiplier = creditMultipliers[activityType] ?? 0.0;

    // Calculate total credits
    return activityAmount * multiplier;
  }
}
