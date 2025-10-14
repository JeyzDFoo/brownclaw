# BrownClaw - Whitewater Kayaking LogBook

A Firebase-powered Flutter app designed specifically for whitewater kayakers to track their river descents and adventures.

## 🛶 Features

- **Google Sign-In Authentication** - Secure, one-tap login with your Google account
- **River Descent Logging** - Track river name, section, and run details
- **Difficulty Classification** - Log rapids difficulty from Class I to Class VI
- **Water Level Recording** - Note water conditions for better planning
- **Personal Notes** - Add thoughts, highlights, and tips from your runs
- **Real-time Sync** - Your logbook syncs across all your devices
- 🌐 **Multi-platform**: Supports web, iOS, Android, and desktop

## Firebase Services Integrated

- **Firebase Core**: Base Firebase functionality
- **Firebase Auth**: User authentication and management with Google Sign-In
- **Cloud Firestore**: NoSQL document database
- **Firebase Storage**: File storage (configured but not implemented in UI yet)
- **Google Sign-In**: OAuth authentication with Google accounts

## Getting Started

### Prerequisites

- Flutter SDK installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- A Firebase project (already configured for this app)

### Installation

1. Clone the repository:
   ```bash
   git clone <your-repo-url>
   cd brownclaw
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Project Structure

```
lib/
├── main.dart                    # App entry point with Firebase initialization
├── firebase_options.dart        # Firebase configuration (auto-generated)
└── screens/
    ├── auth_screen.dart         # Authentication UI (login/signup)
    ├── dashboard_screen.dart    # Main dashboard with quick actions
    └── logbook_screen.dart      # Personal LogBook entries
```

## How to Use

1. **Welcome Screen**: Start here and tap "Get Started"
2. **Authentication**: Choose from multiple sign-in options:
   - Email/password signup and login
   - **Google Sign-In** - Quick OAuth authentication
3. **Dashboard**: Once authenticated, you'll see:
   - Personal welcome message with your details
   - Quick action cards for easy navigation
   - Profile management and sign-out options
4. **LogBook**: Record your personal entries:
   - Add titled log entries with descriptions
   - View all your entries in chronological order
   - Delete entries you no longer need

## Firebase Configuration

Your app is configured with:
- **Project ID**: `brownclaw`
- **Platform**: Web (you can add more platforms using `flutterfire configure`)

## Adding More Platforms

To add iOS, Android, or other platforms:

```bash
flutterfire configure
```

Follow the prompts to select additional platforms.

## Google Sign-In Setup

To enable Google Sign-In, you need to configure it in the Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/project/brownclaw)
2. Navigate to **Authentication** > **Sign-in method**
3. Click on **Google** and enable it
4. Add your domain to authorized domains (for web deployment)
5. For web apps, no additional configuration is needed in the code

### For iOS/Android (when you add those platforms):
- iOS: Add your iOS bundle ID and download the GoogleService-Info.plist
- Android: Add your Android package name and SHA-1 certificate fingerprint

## Firestore Security Rules

Make sure to update your Firestore security rules in the Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /logbook_entries/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Next Steps

Consider adding:
- User profiles
- File upload with Firebase Storage  
- Push notifications
- Offline capability
- Data validation and error handling
- User roles and permissions

## Firebase Console

Access your Firebase project at: https://console.firebase.google.com/project/brownclaw
