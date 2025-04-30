import 'package:flutter/material.dart';
import '../utils/carbon_calculator.dart';

class ActivityTrackingScreen extends StatefulWidget {
  const ActivityTrackingScreen({super.key});

  @override
  State<ActivityTrackingScreen> createState() => _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState extends State<ActivityTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedActivityType = 'public_transport';
  double _activityAmount = 0;
  double _earnedCredits = 0;

  final Map<String, String> _activityTypes = {
    'public_transport': 'Public Transportation',
    'renewable_energy': 'Renewable Energy Usage',
    'recycling': 'Recycling',
    'tree_planting': 'Tree Planting',
    'local_food': 'Local Food Consumption',
    'vegetarian_meal': 'Vegetarian Meal',
    'vegan_meal': 'Vegan Meal',
  };

  final Map<String, String> _unitLabels = {
    'public_transport': 'km',
    'renewable_energy': 'kWh',
    'recycling': 'kg',
    'tree_planting': 'trees',
    'local_food': 'meals',
    'vegetarian_meal': 'meals',
    'vegan_meal': 'meals',
  };

  void _calculateCredits() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _earnedCredits = CarbonCalculator.calculateActivityCredits(
          activityType: _selectedActivityType,
          activityAmount: _activityAmount,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'Track Sustainable Activities',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Your Sustainable Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Activity Type',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedActivityType,
                        items: _activityTypes.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedActivityType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText:
                              'Amount (${_unitLabels[_selectedActivityType]})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _activityAmount = double.tryParse(value) ?? 0;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _calculateCredits,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Calculate Credits'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_earnedCredits > 0)
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Credits Earned',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _earnedCredits.toStringAsFixed(2),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            // TODO: Save the activity and add credits to user
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Activity saved and credits added!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Submit Activity'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
