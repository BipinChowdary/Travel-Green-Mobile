import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../models/app_user.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final TripService _tripService = TripService();
  bool _isEditing = false;
  bool _isLoadingCredits = true;
  double _totalCarbonCredits = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeNameController();
    _loadTotalCarbonCredits();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if user is authenticated and reload credits
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.appUser != null) {
      _loadTotalCarbonCredits();
    }
  }

  void _initializeNameController() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.appUser != null) {
      _nameController.text = authProvider.appUser!.name;
    }
  }

  Future<void> _loadTotalCarbonCredits() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.appUser?.uid;

    if (userId == null) return;

    setState(() {
      _isLoadingCredits = true;
    });

    try {
      // Get all trips for this user
      final allTrips = await _tripService.getUserTrips(userId);

      // Calculate total carbon credits
      double totalCredits = 0.0;
      for (var trip in allTrips) {
        totalCredits += trip.carbonCredits;
      }

      if (mounted) {
        setState(() {
          _totalCarbonCredits = totalCredits;
          _isLoadingCredits = false;
        });
      }
    } catch (e) {
      print('Error loading total carbon credits: $e');
      if (mounted) {
        setState(() {
          _isLoadingCredits = false;
        });
      }
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset the name if cancelled
        _initializeNameController();
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.updateProfile(name);

      if (success && mounted) {
        setState(() {
          _isEditing = false;
        });

        // Refresh carbon credits after profile update
        _loadTotalCarbonCredits();
      }
    }
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.appUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: _toggleEditing,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 32),
              _buildProfileDetails(user),
              const SizedBox(height: 32),
              _buildOrganizationInfo(user),
              const SizedBox(height: 32),
              if (_isEditing)
                ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: authProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AppUser user) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              )
            else
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails(AppUser user) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Carbon Credits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.eco, color: Colors.green),
              title: const Text('Current Balance'),
              trailing: _isLoadingCredits
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    )
                  : Text(
                      '${_totalCarbonCredits.toStringAsFixed(2)} credits',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Member Since'),
              trailing: Text(
                '${user.createdAt.toDate().day}/${user.createdAt.toDate().month}/${user.createdAt.toDate().year}',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Account Type'),
              trailing: Text(
                _getRoleText(user.role),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationInfo(AppUser user) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organization Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Organization'),
              subtitle: Text(user.organizationName ?? 'Not specified'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('Domain'),
              subtitle: Text(user.domain ?? 'Not specified'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return 'Employee';
      case UserRole.employer:
        return 'Employer';
      case UserRole.bank:
        return 'Bank';
      case UserRole.system_admin:
        return 'System Admin';
      default:
        return 'Unknown';
    }
  }
}
