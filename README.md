# MetaFrames

A film photography log for Android and iOS, built with Flutter. MetaFrames tracks your cameras and lenses, film stocks, rolls, lab processing and scans. It is a client for the MetaFrames API server and keeps no data on the device except settings and the session token.

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

### Real devices

List the connected devices to find the device ID:

```bash
flutter devices
```

For an Android phone, enable USB debugging and connect it with a cable. Forward the server's port over USB, then run the app:

```bash
adb -s <device-id> reverse tcp:8080 tcp:8080
flutter run -d <device-id> --dart-define-from-file=google_sign_in.json
```

On the login screen, double-tap the copyright line at the bottom to open Settings, and set the server URL to `http://127.0.0.1:8080`. Keep the cable connected. If the connection drops, run the `adb reverse` command again.

For an iPhone, select your development team under **Signing & Capabilities** in `ios/Runner.xcworkspace`, then run the app:

```bash
flutter run -d <device-id> --dart-define-from-file=google_sign_in.json
```

An iPhone cannot use `adb reverse`. Set the server URL to an address that the phone can reach, such as your computer's address on the same network.

In VS Code, the **Development Debug** and **Development Release** launch configurations run the app in debug or release mode.

## Connecting to the API server

The app sends every request to a configurable base URL. The default is `http://10.0.2.2:8080`, which is the host machine's port 8080 as seen from the Android emulator.

To use a different server, open **More > Settings** and change the base URL. The value is stored with `shared_preferences`. For the iOS simulator, use `http://127.0.0.1:8080` to reach a server on the host machine.

Android allows cleartext HTTP (`android:usesCleartextTraffic="true"`), so a local server does not need TLS.

To use the app, log in or register. The session token is stored with `flutter_secure_storage`. Saving a different base URL ends the session, so the token never goes to another server. Password reset emails link to the web dashboard.

### Sign in with Google

The app uses the device's Google account picker and sends the resulting ID token to the server's `POST /auth/google/token`. An iOS build without its client id hides the Google button. To enable it:

1. In the Google Cloud console, in the same project as the server's web client, create an Android OAuth client with the app's package name and signing SHA-1, and an iOS OAuth client with its bundle ID.
2. Create your local config files. Git ignores both of them:

   ```bash
   cp google_sign_in.example.json google_sign_in.json
   cp ios/Flutter/GoogleSignIn.example.xcconfig ios/Flutter/GoogleSignIn.xcconfig
   ```

   Fill in `google_sign_in.json`. The app reads `GOOGLE_IOS_CLIENT_ID`. `GOOGLE_ANDROID_CLIENT_ID` is for reference only: Android finds its client by package name and SHA-1. The web client id is not stored here: the app reads it from the server's `GET /auth/google/config` when the user taps the button.
3. Set `GOOGLE_REVERSED_CLIENT_ID` in `ios/Flutter/GoogleSignIn.xcconfig` to the iOS client id with its parts reversed, such as `com.googleusercontent.apps.1234-abcd`.
4. Set the server's `GOOGLE_MOBILE_CLIENT_IDS` to the iOS client id.
5. Build with `--dart-define-from-file=google_sign_in.json`. The VS Code launch configurations already pass it.

On an Android emulator, Google sign-in needs a **Google Play** system image with updated Play services. A `google_apis` image can fail with `No credentials available`.

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
