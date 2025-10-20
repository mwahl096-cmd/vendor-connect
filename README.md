# Vendor Connect (Flutter)

Vendor Connect is a Flutter application that delivers articles, notifications, and admin tooling for vendors and administrators. The project integrates Firebase for authentication, Firestore, and Cloud Messaging, plus WordPress synchronization through Cloud Functions.

## Getting Started

### Prerequisites

- Flutter SDK (3.7.0 or later)
- Dart SDK (bundled with Flutter)
- Firebase project configured with iOS/Android apps
- For iOS builds: macOS with Xcode and CocoaPods

### Install dependencies

```bash
flutter pub get
```

If you regenerated the iOS directory or updated plugins, install CocoaPods (macOS only):

```bash
cd ios
pod install
cd ..
```

### Run the app

```bash
flutter run
```

To target a specific device/emulator:

```bash
flutter run -d <device-id>
```

### Building release binaries

#### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

#### iOS

```bash
flutter build ios --release
# then archive/sign via Xcode
```

## Firebase/Cloud Functions

Cloud Functions live in the `functions/` directory. To deploy:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## Code Formatting & Analysis

```bash
flutter format .
flutter analyze
```

## Device Preview

The app bundles the `device_preview` package; when not in release mode you can switch form factors from the toggle appearing in the lower corner of the UI.

## Contributing

1. Fork & clone the repository.
2. Create a feature branch: `git checkout -b feature/xyz`.
3. Commit your changes.
4. Open a pull request.

