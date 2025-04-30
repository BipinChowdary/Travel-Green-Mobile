import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/trip_screen.dart';
import 'screens/activity_tracking_screen.dart';
import 'screens/all_activities_screen.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CarbonCreditApp());
}

class CarbonCreditApp extends StatelessWidget {
  const CarbonCreditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'Carbon Credit Project',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            primary: Colors.green,
            secondary: Colors.lightGreen,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) =>
              const HomeScreen(title: 'Carbon Credit Dashboard'),
          '/profile': (context) => const ProfileScreen(),
          '/trip': (context) => const TripScreen(),
          '/activity': (context) => const ActivityTrackingScreen(),
          '/all_activities': (context) => const AllActivitiesScreen(),
          '/marketplace': (context) => Scaffold(
                appBar: AppBar(title: const Text('Marketplace')),
                body: const Center(child: Text('Marketplace coming soon!')),
              ),
        },
        home: const AuthCheckScreen(),
      ),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.initialize();
    authProvider.setupAuthListener();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show loading indicator while checking auth state
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Redirect based on authentication state
    if (authProvider.isAuthenticated) {
      return const HomeScreen(title: 'Carbon Credit Dashboard');
    } else {
      return const LoginScreen();
    }
  }
}
