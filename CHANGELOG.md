# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Failed API requests print a curl command and the response in debug builds.

### Fixed

- Film stock, lab, roll, and processing writes leave out unset optional fields instead of sending null.
- Pack origin is hidden and not sent for factory packaging.
- An empty status chip on the rolls tab keeps the chips on screen and shows "No rolls here."

### Changed

- Camera, lens, roll, and film stock details share one card-based layout with a bordered app bar, an Edit button, and labelled sections.
- Lens and roll details move activate, deactivate, and delete into action rows at the bottom, as camera details does.
- Roll details lists gear, cost, processing history, and frames in cards. Its status actions are full-width buttons, with Manage lenses as a dashed button under the gear card.
- Camera details shows Load roll as a full-width button below the lenses.
- Load roll, Manage lenses, and Lenses used use the form style of the other forms, with a full-width Save or Load button at the bottom.
- Dependencies update to their latest versions, including cupertino_icons 2.0.

## [1.0.0] - 2026-10-03

### Added

- Android and iOS Flutter app.
- Shared API client, film-log models, light and dark themes, and form widgets.
- Gear locker for cameras and lenses, including fixed-lens bodies.
- Film stock catalog with ISO, process, and packaging.
- Roll log with status filters, loading a roll into a camera, finishing a roll, recording the lenses used, and an expiry list.
- Lab workflow for sending rolls, tracking negatives, and recording processing.
- Scan import, frame viewing, and side-by-side compare.
- Home dashboard for loaded cameras, rolls ready for the lab, negatives at the lab, and film expiring soon.
- Search and a configurable API base URL.

[Unreleased]: https://github.com/vhnam/meta-frames-app/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/vhnam/meta-frames-app/releases/tag/v1.0.0
