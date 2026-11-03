# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-11-03

### Added

- Settings keeps a list of named API servers, such as Localhost and Production. Tap a saved server and then Save to switch to it. Switching logs you out.
- A Scanners screen under More lists the shared built-in scanners and your own. You can add, edit and delete your own, with brand, model, kind, default scan settings and notes. Built-in scanners open read-only.
- A film stock's box ISO can be a range as well as a single speed, like 100-400 or 50-200. The ISO field takes either, and a roll shot at a speed within the range counts as box speed. Needs the server version where `boxIso` is a string.
- A lab page shows the lab's name, address and scanners in the lab's order, with its default scanner marked, as on the dashboard. The Labs list opens it, and the page edits or deletes the lab.
- The Add and Edit lab dialogs pick the scanners a lab runs and an optional default, which moves to the top. The Labs list names each lab's scanners.
- Edit Roll has a Processing section that lists the roll's jobs as the dashboard does, latest first: service, process and price, each step's expected and actual dates with its status, scanners and notes. Edit Processing Job changes a job's process, price, scanners and dates, and deletes a job that has no imported scans. Its lab and service are locked.
- Accounts: log in, register and request a password reset email with an email and password, or continue with Google through the device's account picker. iOS builds without their client id hide the Google button. The session stays in the device's secure storage, and More shows the signed-in user and a log out action.

### Changed

- Lists and frame comparisons stay cached when you switch tabs or segments or swipe between frames, and the app calls the API again only after a write, a pull to refresh or a session change. Changes made on another device appear after a pull to refresh or an app restart.
- A processing job's page matches the other details screens: Edit in the top bar, a job summary, each step's dates and status, the scanners, notes and scans in labelled cards, and the actions in full-width buttons at the bottom. Editing and deleting the job start from Edit. A job done at home can now record that its negatives are developed or its prints are done.
- A film stock's notes take the full width of the card below their label and render as Markdown.
- A film stock's page shows its type, process and packaging as badges.
- Activate, Deactivate and Delete camera moved from the camera's page to Edit Camera. Deleting a camera returns to the screen that opened its page.
- Activate, Deactivate and Delete lens moved from the lens's page to Edit Lens. Deleting a lens returns to the screen that opened its page.
- The tab bar has three tabs, in the order Rolls, Home, More. Gear moved into More. The app still opens on Home.
- Edit Roll groups its fields into numbered Film, Purchase and Expiry sections like the dashboard, with quick picks for 12, 24 and 36 exposures. Delete roll moved from the roll's page to Edit Roll, for a roll still in stock, and returns to the screen that opened the roll.
- Send to Lab follows the dashboard: numbered Roll, Lab & service, Scans, Dates and Notes sections. It starts at home, where it records the days the work was done, and a lab adds expected dates. A processed roll now offers Re-scan instead of Send again, for scans only.
- A roll's page shows its status under the stock and base stock names, so a long name has the card's full width.
- The app needs a signed-in account. It opens on the login screen without a session and returns there when the session ends.
- Settings opens from the login screen: double-tap the copyright line to set the server URL before signing in.
- Changing the server URL ends the session.
- Scan images and downloads send the session.
- Failed-request logs hide session cookies and auth request bodies.
- New roll follows the dashboard's Add rolls: formats 135, 120 and 110, and film stocks in name order.
- Edit roll follows the dashboard's Edit roll: film stock, format, exposures, price and expiry. Shot ISO, dates and notes keep their values but are no longer edited here. A saved format outside the list stays available.
- Roll forms accept expiry years from 1900 to 2100. The year comes first and stays optional, and the month opens once a year is entered.

### Fixed

- A processing job's page shows its imported scans. It read a `scanners` field the API does not send, so it always said no scans were imported, and the scanner comparison never appeared.
- Text buttons such as Edit and + Add are readable in dark mode.
- A scanning job names its scanners, with their settings. The API requires at least one, which the old form never sent.
- New roll and Edit roll save the expiry. The server ignored it before, so each edit cleared it.
- The system navigation bar no longer covers the bottom of forms, detail screens and bottom sheets.

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

[Unreleased]: https://github.com/vhnam/meta-frames-app/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/vhnam/meta-frames-app/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vhnam/meta-frames-app/releases/tag/v1.0.0
