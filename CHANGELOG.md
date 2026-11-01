# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Accounts: log in, register and request a password reset email with an email and password, or continue with Google through the device's account picker. iOS builds without their client id hide the Google button. The session stays in the device's secure storage, and More shows the signed-in user and a log out action.

### Changed

- The app needs a signed-in account. It opens on the login screen without a session and returns there when the session ends.
- Settings opens from the login screen: double-tap the copyright line to set the server URL before signing in.
- Changing the server URL ends the session.
- Scan images and downloads send the session.
- Failed-request logs hide session cookies and auth request bodies.

## [1.0.0] - 2026-10-06

### Added

- Android and iOS Flutter app.
- Shared API client, film-log models, light and dark themes, and form widgets.
- Gear locker for cameras and lenses, including fixed-lens bodies.
- Film stock catalog with ISO, process, and packaging. Pack origin is hidden for factory packaging.
- Roll log with status filters, loading a roll into a camera, finishing a roll, recording the lenses used, and an expiry list.
- Lab workflow for sending rolls, tracking negatives, and recording processing.
- Scan import, frame viewing and notes, and side-by-side compare.
- Home dashboard for loaded cameras, rolls ready for the lab, negatives at the lab, and film expiring soon.
- Home, Gear, Rolls, and More tabs. More links to film stocks, the expiry list, labs, and settings.
- Settings with a configurable API base URL.
- Camera, lens, roll, and film stock details with one card-based layout, an Edit button, and action rows for activate, deactivate, and delete.
- Failed API requests print a curl command and the response in debug builds.

[Unreleased]: https://github.com/vhnam/meta-frames-app/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/vhnam/meta-frames-app/releases/tag/v1.0.0
