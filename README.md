# Carbon Credit Project

A Flutter mobile application for tracking, trading, and managing carbon credits.

## Overview

This application helps users track their carbon footprint, earn carbon credits through sustainable activities, and participate in a carbon credit marketplace. The app aims to incentivize environmentally friendly behaviors through a gamified approach to sustainability.

## Features

1. **Credit Summary Card**: Displays total credits and monthly credits
2. **Trip Tracking**: GPS-based trip tracking with automatic transport mode detection
3. **Trip History**: List of past trips with details and earned carbon credits
4. **Firestore Integration**: All trips are now stored in Firebase Firestore and synchronized across devices
5. **Enhanced Location Permissions**: Improved location permission handling with user guidance

## Getting Started

### Prerequisites

- Flutter (2.0.0 or higher)
- Dart SDK
- Android Studio / Xcode for emulation

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the application

## Project Structure

The project follows a feature-based architecture:

- `lib/`
  - `main.dart` - Entry point of the application
  - `models/` - Data models and business logic
  - `screens/` - UI screens for different app features
  - `widgets/` - Reusable UI components
  - `services/` - API and business services
  - `utils/` - Helper functions and utilities

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
