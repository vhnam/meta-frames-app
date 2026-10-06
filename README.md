# MetaFrames

A film photography log for Android and iOS, built with Flutter. MetaFrames tracks your cameras and lenses, film stocks, rolls, lab processing and scans. It is a client for the MetaFrames API server and keeps no data on the device except settings.

## Features

- **Gear**: cameras and lenses, including fixed-lens bodies.
- **Film**: a film stock catalog with ISO, process and packaging.
- **Rolls**: a roll log with status filters. Load a roll into a camera, finish it, record the lenses used, and see which film is about to expire.
- **Labs**: send rolls to a lab, track negatives at the lab, and record processing.
- **Scans**: import scans, view frames, add frame notes, and compare scans side by side.
- **Home**: a dashboard of loaded cameras, rolls ready for the lab, negatives at the lab, and film expiring soon.

See [CHANGELOG.md](CHANGELOG.md) for what changed in each release.

## Requirements

- Flutter 3.47 or later, with Dart SDK `^3.13.4`
- Android Studio with an Android emulator, or Xcode with an iOS simulator
- A running MetaFrames API server

## Getting started

Install the dependencies:

```bash
flutter pub get
```

### Android

Start the emulator, then run the app:

```bash
emulator -avd Pixel_7_API_34
flutter run -d emulator-5554
```

### iOS

Open the simulator, then run the app:

```bash
open -a Simulator
flutter run -d ios
```

In VS Code, the **Development Debug** and **Development Release** launch configurations run the app in debug or release mode.

## Connecting to the API server

The app sends every request to a configurable base URL. The default is `http://10.0.2.2:8080`, which is the host machine's port 8080 as seen from the Android emulator.

To use a different server, open **More > Settings** and change the base URL. The value is stored with `shared_preferences`. For the iOS simulator, use `http://127.0.0.1:8080` to reach a server on the host machine.

Android allows cleartext HTTP (`android:usesCleartextTraffic="true"`), so a local server does not need TLS.

In debug builds, a failed request prints an equivalent `curl` command and the server response to the console.

## Project structure

The app follows the [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations), with Riverpod for state and dependency injection and `go_router` for navigation.

```text
lib/
├── main.dart            # Entry point; sets up SharedPreferences and the ProviderScope
├── app.dart             # MaterialApp and themes
├── providers.dart       # Query providers
├── data/
│   ├── services/        # ApiClient: HTTP transport, error mapping, JSON decoding
│   └── repositories/    # One abstract repository and one remote version per domain
├── domain/
│   └── models/          # Models and typed request bodies
├── routing/             # Router, Routes path builders, tab shell
└── ui/
    ├── core/            # Theme and shared widgets
    └── <feature>/       # home, gear, film, rolls, labs, scans, more
        ├── view_models/
        └── widgets/
```

- Widgets do not read repositories. Logic lives in view models, actions classes and derived providers.
- The four tabs (Home, Gear, Rolls, More) sit in a stateful shell. Every other screen is a root-level route that takes ids in its path and loads its own data.
- Build paths with `Routes`, for example `context.push(Routes.roll(id))`.

[docs/improvement-plan.md](docs/improvement-plan.md) records the architecture and performance work and what is still open.

## Testing

Run the tests and the analyzer:

```bash
flutter test
flutter analyze
```

The tests use fake repositories from `test/testing/` and a mock `http.Client`. They cover view models, actions, repositories, `ApiClient`, and smoke tests for the main screens.
