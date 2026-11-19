# MetaFrames

A film photography log for Android and iOS, built with Flutter. MetaFrames is the field companion of the MetaFrames dashboard. It is a client for the MetaFrames API server.

The app keeps a local store (SQLite) on the phone, so the field workflow works without a signal (see [Working offline](#working-offline)). The store has one partition for each account and server. Pending changes and drafts stay on the phone until they sync. The app also keeps the settings and the session token.

## Features

The app has three tabs.

- **Shooting**: the cameras with film in them, each with its roll, shot ISO and start date. Finish a roll, or load a new one into an empty camera. Frame notes are on the roll's page.
- **Rolls**: a roll log with a chip for each status, a Negatives at lab chip and a format filter. Film in stock lists the soonest expiry first and marks expired or expiring film. Load a roll into a camera, finish it, record the lenses used, and note frames from the roll's page. Send a roll to a lab, or record work done at home, and mark negatives and scans as received. A roll's page shows its scans: view, zoom, download and share them.
- **More**: Gear, Film stocks, Labs, Sync status, the signed-in account, Settings and Log out.

Gear, Film stocks and Labs are for lookup and picking. A quick add makes the minimum record that lets you continue: a camera (brand, model, and a mount or a fixed lens's focal length and aperture), a lens (focal length, aperture), a film stock (brand, name, ISO, type, process, packaging) or a lab (name).

### Done on the dashboard

The app does not do these tasks. Use the dashboard.

- Scanners and scan settings.
- Lab orders and prices.
- Edit or delete a processing job.
- Import scans and compare scans.
- Full gear admin: edit, activate, deactivate and delete cameras and lenses, and link lenses to cameras.
- Full film stock admin: edit a stock, its origins, base stock and notes.
- Full lab admin: edit or delete a lab, its address and its scanners.

The app only hides these tasks. It does not delete data. A link to a removed screen opens the router error page.

See [CHANGELOG.md](CHANGELOG.md) for what changed in each release.

## Requirements

- Flutter 3.47 or later, with Dart SDK `^3.13.4`
- Android Studio with an Android emulator, or Xcode with an iOS simulator
- A running MetaFrames API server
- [Trivy](https://trivy.dev/) (`brew install trivy`) for the security scan
- [Gitleaks](https://github.com/gitleaks/gitleaks) (`brew install gitleaks`) for the secret scan

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

In a debug build, double-tap the copyright line at the bottom of the login screen to open Settings, and set the server URL to `http://127.0.0.1:8080`. Keep the cable connected. If the connection drops, run the `adb reverse` command again.

For an iPhone, select your development team under **Signing & Capabilities** in `ios/Runner.xcworkspace`, then run the app:

```bash
flutter run -d <device-id> --dart-define-from-file=google_sign_in.json
```

An iPhone cannot use `adb reverse`. Set the server URL to an address that the phone can reach, such as your computer's address on the same network.

In VS Code, the **Development Debug** and **Development Release** launch configurations run the app in debug or release mode. **Development Release** asks for the API origin and passes it as `--dart-define=API_BASE_URL=...` (see [Profile and release builds](#profile-and-release-builds)). Keep your own origin out of `.vscode/launch.json`: type it at the prompt.

## Connecting to the API server

The way you choose the server depends on the build mode.

### Debug builds

The app sends every request to a configurable base URL. The default is `http://10.0.2.2:8080`, which is the host machine's port 8080 as seen from the Android emulator. A debug build ignores `API_BASE_URL`.

To use a different server, open **More > Settings**. To add one, tap **Add server**, enter a name and its URL, and tap Add. Tap a saved server to select it, then tap **Save** to apply it. Changing the server ends the session. These values are stored with `shared_preferences`. For the iOS simulator, use `http://127.0.0.1:8080` to reach a server on the host machine.

Android allows cleartext HTTP (`android:usesCleartextTraffic="true"`), so a local server does not need TLS.

### Profile and release builds

A profile or release build talks to one server, which you set when you build the app. Settings shows Appearance only. The login screen has no hidden route to Settings, and connection errors do not link to it. Give the origin with a compile-time define:

```bash
flutter run --profile -d <device-id> --dart-define=API_BASE_URL=https://api.example.com
flutter run --release -d <device-id> --dart-define=API_BASE_URL=https://api.example.com
flutter build appbundle --dart-define=API_BASE_URL=https://api.example.com
flutter build ipa --dart-define=API_BASE_URL=https://api.example.com
```

Add `--dart-define-from-file=google_sign_in.json` to each command when you need Google sign-in. It is a separate argument.

To install a release build on a connected Android device without Google Play, build an APK and install it over the existing app:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

Add `--dart-define-from-file=google_sign_in.json` to the build command when you need Google sign-in.

`install -r` keeps the app's data. The update works only when the installed app has the same application ID, a compatible signing certificate, and a version code that is not higher than this build. This APK is signed with the debug key of the computer that builds it, and Google Play does not accept it. If `adb` reports a signature or version mismatch, do not uninstall the app: uninstalling deletes held offline work.

- **HTTPS only.** The value is an absolute HTTPS origin: a host, and an optional port from 1 to 65535. It has no credentials, path, query or fragment. Use a staging endpoint whose certificate the device trusts. A profile or release build cannot use plain HTTP.
- **Exact spelling.** The app trims spaces and trailing slashes, then compares the URL as an exact string. It keeps the host spelling and an explicit port. `https://API.example.com:443` and `https://api.example.com` are two different servers to the app, so a session and offline work filed under one are not found under the other. Use the same spelling as the build that the phone ran before.
- **Another server needs another build.** The server cannot change at run time. Build again with the new `API_BASE_URL`.
- **A missing or invalid define.** If a profile or release build has no `API_BASE_URL`, or the value is not an HTTPS origin, the app does not start. It shows "This build has no API server" and reads or changes nothing on the device. It never uses a stored or development URL instead. Build again with a correct define.
- **An unreachable server.** A valid URL with a server that cannot be reached is a normal connection failure. The app shows the usual offline messages. It does not show the startup error, and it does not sign you out.

When a build starts with a different URL than the one the stored session belongs to, or the stored session cannot be tied to that URL, the app ends the session and shows the login screen with a notice. It does not delete the offline work (see [Recovering held offline work](#recovering-held-offline-work)).

To use the app, log in or register. The session token is stored with `flutter_secure_storage`. The token goes only to the server it was issued by. Password reset emails link to the web dashboard.

## Working offline

The Shooting tab, load, finish, roll notes and frame notes keep working without a connection.

- **What is kept.** For the signed-in account on the selected server, the app stores the answers of the reads the field workflow uses (cameras, rolls, a loaded roll's page and frames, film, labs, lenses) in a SQLite file on the phone. Scans are never kept. A list that was never fetched shows "Not available offline yet", not an empty list.
- **What is queued.** Loading and finishing a roll, roll notes and frame notes are saved on the phone first, shown on the screens as "waiting to sync", and sent in order when the server can be reached. The app asks the server to confirm each one and never sends one twice; a change someone else made on the dashboard shows as a conflict with both sides, and nothing is overwritten until you choose (Use server, Keep mine or Try again, Copy mine). **More > Sync status** lists what is waiting, the drafts, and what other accounts have left on the phone.
- **Accounts and servers.** Everything kept is filed under one account on one server, in its own file. A queued change is only ever sent to that server as that account. Logging out, or changing the server in a debug build's Settings, with unsent changes asks whether to keep them on the phone (the default) or discard them. If the session expires, changes wait until the same account signs in again.
- **Drafts.** The quick-create forms (camera, lens, film stock, lab, added rolls) save what you typed before the first request, so a timeout or a restart never loses it. A record is not created offline: a draft waits until the server can be reached.

### Recovering held offline work

When a session ends because the build points to another server, the account's unsent changes, drafts and kept reads stay on the phone, in the file for that account and server. The app never merges them into another server's data, and it does not delete them at startup. After sign-in, **More > Sync status** lists the pending changes and drafts under **Other accounts on this phone**, as counts only.

To recover that work:

1. Get a build of the same app, with the same package name or bundle ID and signature, so it keeps the app's data. For a profile or release build, build it first with `--dart-define=API_BASE_URL=` set to the exact original URL (see the spelling rule above), because Settings cannot change it. A debug build can instead pick the original server in Settings after you install it.
2. Install that build over the existing app. Do not uninstall the app.
3. Sign in as the same account. The app sends the eligible pending changes in order. Cached reads stay on the phone and are not sent.
4. Open **More > Sync status**. Tap each draft to finish and send it. The app does not send a draft by itself.

Before you plan to go back to an older app version, sign out and keep the local work. Do not restore an old token or an old settings file.

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
5. Build with `--dart-define-from-file=google_sign_in.json`. The VS Code launch configurations already pass it. A profile or release build also needs `--dart-define=API_BASE_URL=...`.

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
│   ├── services/        # ApiClient: HTTP transport, error mapping, JSON decoding; SessionStore
│   ├── local/           # SQLite store per account and server, read cache, partition controller
│   ├── sync/            # The outbox: pending operations, projection, sync engine
│   └── repositories/    # One abstract repository and one remote version per domain
├── domain/
│   └── models/          # Models and typed request bodies
├── routing/             # Router, Routes path builders, tab shell
└── ui/
    ├── core/            # Theme and shared widgets
    └── <feature>/       # shooting, gear, film, rolls, labs, scanners, scans, more, sync, auth
        ├── view_models/
        └── widgets/
```

- Widgets do not read repositories. Logic lives in view models, actions classes and derived providers.
- The three tabs (Shooting, Rolls, More) sit in a stateful shell. Every other screen is a root-level route that takes ids in its path and loads its own data.
- Build paths with `Routes`, for example `context.push(Routes.roll(id))`.

[docs/improvement-plan.md](docs/improvement-plan.md) records the architecture and performance work and what is still open.

## Testing

Run the tests and the analyzer:

```bash
flutter test
flutter analyze
```

The tests use fake repositories from `test/testing/` and a mock `http.Client`. They cover view models, actions, repositories, `ApiClient`, and smoke tests for the main screens.

### Security scan

Trivy checks `pubspec.lock` and the iOS `Package.resolved` files for known vulnerabilities, and the
repository for secrets and misconfigurations. Settings are in `trivy.yaml`.

```bash
trivy fs .
```

Run this once per clone to use the git hooks in `.githooks/`. The pre-push hook runs the scan and
blocks the push on a HIGH or CRITICAL secret or misconfiguration, or a HIGH or CRITICAL vulnerability
that has a fix:

```bash
git config core.hooksPath .githooks
```

To accept a finding, add its ID to `.trivyignore` with a comment that says why.

### Secret scan

Gitleaks checks the git history for secrets. The same `core.hooksPath` setting enables the pre-commit
hook, which scans the staged changes and blocks the commit when it finds a secret.

```bash
gitleaks git --redact --no-banner
```

To accept a false positive, add its fingerprint to `.gitleaksignore`.
