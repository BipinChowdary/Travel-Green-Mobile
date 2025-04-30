# Firebase Setup Guide

This guide will help you connect the Carbon Credit Project app to Firebase.

## Prerequisites

1. A Google account
2. Flutter SDK installed
3. Firebase CLI installed (optional, but recommended)

## Steps to Configure Firebase

### 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and follow the setup wizard
3. Give your project a name (e.g., "Carbon Credit Project")
4. Choose whether to enable Google Analytics (recommended)
5. Create the project

### 2. Register Your App with Firebase

#### For Android:

1. In the Firebase console, click "Add app" and select the Android platform
2. Enter your app's package name: `com.example.carbon_credit_project`
3. (Optional) Enter your app nickname and SHA-1 key
4. Download the `google-services.json` file
5. Place the file in the `android/app/` directory of your Flutter project

#### For iOS:

1. In the Firebase console, click "Add app" and select the iOS platform
2. Enter your iOS bundle ID (usually the same as your package name)
3. Download the `GoogleService-Info.plist` file
4. Place the file in the `ios/Runner/` directory of your Flutter project
5. Open your iOS project in Xcode and ensure the file is added to your main target

### 3. Configure Firebase Authentication

1. In the Firebase console, go to "Authentication" in the sidebar
2. Click "Get started"
3. Enable the "Email/Password" sign-in method
4. (Optional) Configure other sign-in methods as needed

### 4. Set Up Firestore Database

1. In the Firebase console, go to "Firestore Database" in the sidebar
2. Click "Create database"
3. Choose "Start in production mode" or "Start in test mode" (for development)
4. Select a location for your Firestore database
5. Create the following collections:
   - `users`
   - `pending_employees`
   - `organizations`

### 5. Configure Security Rules

Set up appropriate security rules for your Firestore database. Here's a basic example:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && (request.auth.uid == userId || request.resource.data.role == "system_admin");
    }
    match /pending_employees/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null;
    }
    match /organizations/{orgId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.data.role == "employer" || request.resource.data.role == "system_admin";
    }
  }
}
```

### 6. Install FlutterFire CLI (Optional but Recommended)

For easier Firebase configuration, you can use the FlutterFire CLI:

```bash
# Install the FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure your Flutter app with Firebase
flutterfire configure --project=your-firebase-project-id
```

This will automatically generate the necessary configuration files for all platforms.

## Testing Firebase Integration

After setting up Firebase, test your integration:

1. Run the app
2. Try to sign up with a new account
3. Verify that the user data is stored in Firestore
4. Test the login functionality

## Troubleshooting

If you encounter issues:

- Ensure all configuration files are placed in the correct directories
- Make sure your app's package name matches what you registered in Firebase
- Check that you've enabled the necessary Firebase services
- Verify that your security rules allow the operations you're trying to perform

## Next Steps

After basic Firebase setup:

1. Implement additional security measures
2. Set up Firebase Cloud Functions for backend logic
3. Configure Firebase Crashlytics for crash reporting
4. Set up Firebase Analytics for usage tracking 