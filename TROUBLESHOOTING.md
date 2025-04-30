# Troubleshooting Guide

## Location Permission Issues

### Error: "No location permissions are defined in the manifest"

This error occurs when the required location permissions are not properly configured in the Android manifest file.

#### Solution:

1. Open the `android/app/src/main/AndroidManifest.xml` file
2. Add the following permissions inside the `<manifest>` tag, before the `<application>` tag:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

3. For Android 10 (API level 29) and above, note that `ACCESS_BACKGROUND_LOCATION` must be requested separately in the app after the user has already granted the foreground location permissions.

### iOS Location Permission Issues

If you encounter permission issues on iOS, ensure that you have properly configured the Info.plist file.

#### Solution:

1. Open the `ios/Runner/Info.plist` file
2. Add the following entries before the closing `</dict>` tag:

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

## Common Location Tracking Issues

### Location Tracking Not Working or Inaccurate

1. **Check Device Settings**: Ensure that location services are enabled on the device
2. **Check Permission Status**: The app requires "Allow all the time" permission for best tracking results
3. **Battery Optimization**: Some devices aggressively optimize battery usage by restricting background services. Disable battery optimization for the app:
   - Android: Settings > Apps > Carbon Credit Project > Battery > Don't optimize
   - iOS: This is generally not an issue on iOS

### Trip Distance Not Updating

1. **GPS Signal**: Ensure you have a good GPS signal
2. **Movement Detection**: Make sure you're moving enough for the device to detect location changes
3. **Update Frequency**: Location updates happen every 10 seconds by default, so small movements might not register immediately

## Developer Troubleshooting

If you're a developer working on this project and encountering issues:

### Debugging Location Services

1. Add temporary debug prints to track the location update flow:

```dart
void _updateLocation() async {
  try {
    print("Updating location...");
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print("Got position: ${position.latitude}, ${position.longitude}");
    
    // Rest of the code...
  } catch (e) {
    print('Error updating location: $e');
  }
}
```

2. Check the Geolocator permission status manually:

```dart
LocationPermission permission = await Geolocator.checkPermission();
print("Current permission status: $permission");
```

3. If you need to test with mock locations, you can use the Geolocator test package.

### Firebase Integration Issues

If trips are not being saved to Firestore:

1. Check your Firebase project configuration
2. Verify that your app has internet connectivity
3. Check the Firebase security rules to ensure they allow writing to the trips collection
4. Verify the user authentication status

## Contact Support

If you continue to experience issues after trying these troubleshooting steps, please contact our support team at support@carboncreditproject.com or file an issue on our GitHub repository. 