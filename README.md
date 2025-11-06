# Baby Sleep Tracker

Lightweight Flutter app to monitor a baby's sleep and environment. The app reads streaming sensor data (temperature, humidity, position, crying) and displays status cards, charts and an urgent overlay alert when the baby is detected crying.

## Quick overview

-   Platform: Flutter (Android / iOS / Windows / macOS / Linux)
-   Entry point: `lib/main.dart`
-   Key screens: `lib/screens/dashboard_screen.dart`, `lib/screens/auth_screen.dart`
-   Services: `lib/services/data_service.dart` (stream-based data), `lib/services/auth_service.dart` (auth wrapper)
-   UI components: `lib/widgets/*` (`AppCard`, `AlertBanner`, `SleepChart`, `StatusBadge`)
-   Firebase integration: project contains `firebase/` and `lib/firebase_options.dart` and uses `firebase_auth` in places.

## Features

-   Live streaming of the latest sensor `SleepEntry` via `DataService` streams
-   Visual charts for baby temperature, room temperature and humidity (`SleepLineChart`)
-   Status badges and concise info rows for current readings
-   Urgent overlay alert when baby is detected crying (implemented in `dashboard_screen.dart`)

## Run (development)

Prerequisites: Flutter SDK installed and in PATH, and any required device/emulator configured.

Windows cmd examples:

```cmd
flutter pub get
flutter analyze
flutter run
```

To run platform builds:

```cmd
flutter build apk        # Android
flutter build ios        # iOS (macOS required)
flutter build windows    # Windows desktop
```

## Tests & static checks

-   Run unit/widget tests:

```cmd
flutter test
```

-   Static analysis / lints:

```cmd
flutter analyze
```

The repo uses `flutter_lints` and `analysis_options.yaml` — follow the existing lint rules.

## Notable implementation notes

-   `DataService` exposes `latestEntryStream` and `historyStream` — UI commonly uses `StreamBuilder` to render current and historical data.
-   To avoid duplicate listeners, the dashboard now uses a single `StreamBuilder` and renders the crying overlay from the same `entry` instance. See `lib/screens/dashboard_screen.dart` for the overlay implementation and logic that hides the in-flow `AlertBanner` when the overlay is active.
-   If you need to change the overlay width or behavior, edit the `Positioned`/`ConstrainedBox` block in `dashboard_screen.dart` (currently `maxWidth: 420`).

## Troubleshooting

-   If Firebase services fail on startup, ensure you added platform-specific Firebase configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) under the respective platform folders.
-   If hot reload doesn't reflect native changes, perform a full rebuild (`flutter clean` then `flutter run`).

## Contributing

Keep changes small and focused. Run `flutter analyze` and `flutter test` before submitting PRs.
