# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A job on an order shows the order's code and products in the roll's processing history. The order is read-only.
- A Shooting tab, where the app now opens, shows every camera holding a roll: the stock, the shot ISO against the box speed, and the start date. Each camera has Finish. Frame notes are on the roll's page. Empty cameras each have Load, and + Load picks both a camera and a roll.
- The Rolls list has a Negatives at lab chip that finds rolls whose negatives are still at a lab, whatever their status, and format pills built from the formats in the list.
- The field workflow works offline. Cameras, rolls, frames, film and labs you have opened are kept on the phone, and loading a roll, finishing it, roll notes and frame notes are saved on the phone first and sent when the server can be reached, in order, once each. A change made elsewhere in the meantime is shown as a conflict with the server's side and yours, never overwritten. More > Sync status lists what waits, with Sync now, and what other accounts have left on the phone.
- Roll notes can be edited from the roll and from the Shooting card, and frame notes show their sync state.
- Logging out or switching server with unsent changes asks to keep them on the phone or discard them. Kept changes are sent only when the same account signs in again on the same server.
- Quick-create forms for cameras, lenses, film stocks, labs and added rolls save a draft before sending. A create that times out or is interrupted is kept, listed in the picker and in Sync status, and sent again under the same id without making a second record.
- Each saved server can have a dashboard URL. The Dashboard entry in More opens it in the browser (the one of the server in use when tapped); if no browser takes it, the address can be copied.
- A roll card names the jobs as well as the status: "At lab · Develop + Scan" while a job is open at a lab, "At home · Develop" while the work is at home, and "Developed + Scanned" once both are back. A printed-only roll reads "Printed". Needs a MetaFrames API that sends `developed`, `scanned`, `openJobTypes` and `openAtLab`; an older one shows the plain status.
- Edit Roll sends the version of the roll it opened with. If the roll changed meanwhile, such as a note saved from the phone, nothing is saved and the form reloads to show what changed. Needs a MetaFrames API that returns `version` on rolls and accepts `If-Match`.

### Changed

- Settings has Appearance: System, Light or Dark, kept on this phone. Dark mode uses a lighter orange and lighter text so filled buttons, links and secondary text stay readable.
- The Developed and Scanned chips each count a roll that is both. A roll processed at home is under neither. Rolls other than film in stock list the newest start date first, and rolls not started come last.
- The tabs are Shooting, Rolls and More. Shooting replaces Home and its counters. Rolls ready for the lab are under the Done shooting chip, negatives at the lab under More and the new Negatives at lab chip, and expiring film in the Rolls list. Links to `/home` open Shooting.
- Note frame left the Shooting tab. The card still finishes the roll and opens roll notes. Frame notes stay on the roll's page.
- Note frame asks only for the frame number and starts empty each time: the app does not guess which frame was just taken. Any whole number from 0 opens, including frames past the exposure count. Frame notes need no scans.
- In stock, the Rolls list shows film soonest expiry first and marks expired film. Load roll's picker marks expired and expiring rolls, and searching it by format, such as 120, narrows the list.
- The Expiry entry left More. The screen still opens from a link.
- Load roll's ISO field shows the box speed it defaults to, and refuses text that is not a whole number instead of loading the roll at box speed. Lenses are marked optional.
- A camera's page shows the shot ISO with the box speed it differs from, instead of calling it pushed or pulled: the development request is asked for separately when the roll is sent to a lab.

### Removed

These workflows left the phone. The data stays on the server. Use the dashboard.

- Scanners and orders: the Scanners and Orders screens and their links. Use the dashboard to add, edit and delete scanners, to set scan settings, and to record orders, order lines and prices. Send to Lab still picks a scanner and its settings for a scan job.
- Processing edit: Edit Processing Job. A job can no longer be edited or deleted on the phone. Send to Lab and Re-scan still record new jobs, with no order and no price. Use the dashboard to change a job.
- Import and compare: Import scans and the scan comparison. Use the dashboard to import and to compare scans. A roll's page still shows scans, with view, zoom, download and share.
- Full gear admin: edit, activate, deactivate and delete for cameras and lenses, and the Manage lenses screen. A camera's page and a lens's page are read-only. Quick add of a camera or a lens stays. Use the dashboard for specs, notes and lens links.
- Stock and lab admin: edit for film stocks, and edit and delete for labs. A film stock's page and a lab's page are read-only. Quick add of a film stock or a lab name stays. Use the dashboard for stock origins, base stock, notes, lab address and lab scanners.

### Fixed

- After a change sent from the phone lands, the lists on the phone take the roll the server returned. A finish that happened meanwhile shows, instead of the phone's guess of that one step.
- A list or roll that was read while one of your own changes reached the server is read again, instead of showing the earlier state or nothing.
- Opening a frame that has no notes or scans yet no longer leaves the app asking the server for it again in the background.

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
