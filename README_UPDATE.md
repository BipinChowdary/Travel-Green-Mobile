# Carbon Credit Project - Update Instructions

## New Features Added

The home screen has been updated with the following features:
**No Marketplace feature needed**: Marketplace functionality is not required
1. **Credit Summary Card**: Displays total credits and monthly credits
2. **Trip Tracking**: GPS-based trip tracking with automatic transport mode detection
3. **Trip History**: List of past trips with details and earned carbon credits
4. **Firestore Integration**: All trips are now stored in Firebase Firestore and synchronized across devices
5. **Enhanced Location Permissions**: Improved location permission handling with user guidance

## Setup Instructions

After pulling these changes, you need to run the following command to install the new dependencies:

```bash
flutter pub get
```

## Firebase Firestore Setup

This update now uses Firestore to store trip data. Make sure your Firebase project is properly set up with Firestore:

1. Go to your Firebase Console and ensure Firestore Database is enabled
2. Set up the following security rules for your Firestore Database:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /trips/{tripId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow update: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Firestore Data Structure

The application now uses the following Firestore collections:

1. **trips**: Stores all user trip data with the following fields:
   - id: String - Unique trip identifier
   - userId: String - ID of the user who created the trip
   - date: Timestamp - When the trip took place
   - distance: Number - Distance traveled in kilometers
   - transportMode: String - Mode of transport (Walking, Bicycle, etc.)
   - carbonCredits: Number - Credits earned for this trip
   - duration: Number - Trip duration in seconds
   - createdAt: Timestamp - When the trip was recorded

2. **users**: The existing user collection now has an additional field:
   - carbonCredits: Number - Total carbon credits earned by the user

## Platform-Specific Setup for Location Services

### Android

1. Add the following permissions to your `AndroidManifest.xml` file:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

2. **Important Note for Android 10 (API level 29) and above**: For background location access, you need to request location permissions in a two-step process:
   
   a. Request foreground location permission first:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   ```
   
   b. Then request background permission separately:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
   ```

   This two-step approach is now implemented in the app. Users will first be asked for foreground location, then background location if needed.

### iOS

1. Add the following entries to your `Info.plist` file:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to track your trips for calculating carbon credits.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location when in the background to track trips for calculating carbon credits.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location to track your trips, even when in background, for calculating carbon credits accurately.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

## Permission Request Flow

The app now uses an improved permission request flow:

1. The app checks if location services are enabled on the device
   - If disabled, a dialog prompts the user to enable location services with a direct link to system settings

2. The app checks current location permission status:
   - If denied, the app explains why location is needed before requesting permission
   - If permanently denied, the app guides the user to app settings to enable permissions
   - If "while in use" permission is granted but background tracking is needed, the app suggests upgrading to "always" permission

3. Interactive dialogs provide:
   - Clear explanations of why permissions are needed
   - Direct links to relevant settings
   - Options to proceed or cancel

## Trip Tracking Behavior

The application now follows this GPS tracking behavior:

1. **Automatic Location Tracking**: The app automatically starts tracking location when the home screen loads (permission will be requested)
2. **Manual Trip Recording**: Press the play button to start recording a specific trip
3. **Transport Mode Detection**: The app automatically detects transport mode based on speed:
   - < 5 mph: Walking
   - 5-12 mph: Bicycle
   - > 12 mph: You will be asked to choose between Car, Public Transport, or Ride-share
4. **Stopping a Trip**: Press the stop button to end tracking and save the trip
5. **Offline Support**: If there's no internet connection, the trip will be saved locally and synced when connection is restored

## Technical Implementation Details

- GPS tracking uses the Geolocator package to continuously update location in the background
- Distance is calculated between sequential GPS points for accurate measurements
- Speed is used to determine the transportation mode automatically
- Carbon credits are calculated based on distance and transport mode
- All trip data is stored in Firebase Firestore for cross-device synchronization
- Real-time updates are implemented using Firestore streams
- Enhanced permission handling with user guidance and error recovery 