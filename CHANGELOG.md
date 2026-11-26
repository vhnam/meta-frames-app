# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- When the server requires a verified email, creating an account shows the server message and opens the login screen instead of signing in.
- Roll status, film process and lab step colors now come from the design tokens and match the dashboard.

## [3.0.0] - 2026-11-24

### Added

- Trivy security scan. `trivy fs .` checks `pubspec.lock` and the iOS `Package.resolved` files for known vulnerabilities and the repository for secrets and misconfigurations (`trivy.yaml`). After `git config core.hooksPath .githooks`, the pre-push hook runs it and blocks the push on a HIGH or CRITICAL finding.
- Gitleaks secret scan. `gitleaks git --redact --no-banner` checks the git history for secrets. After `git config core.hooksPath .githooks`, the pre-commit hook checks the staged changes and blocks the commit when it finds a secret.
- A profile or release build reads its API server from `--dart-define=API_BASE_URL=<HTTPS origin>`. A build with a missing or invalid value shows a blocking message at startup and does not use any other server.
- The Development Release launch configuration prompts for the API origin.

### Changed

- The app imports the `material_ui` package instead of `flutter/material.dart`.
- Notes in the film stock and processing job screens use a Markdown style sheet built from the app theme. It styles paragraphs, links, headings 1 to 3, bold, italic, code, quotes and list bullets.
- The app has a new slate and emerald look in light and dark mode. Text sizes follow the new type scale, corners are rounder, and filled and outlined buttons have a minimum height of 48. The fonts are unchanged.
- The account card in More and Settings shows the Google profile picture when the account has one.
- Appearance in Settings has Theme, which opens a choice of System, Light or Dark, and Language, which opens a choice with English. Tiếng Việt shows there but is not available yet.
- Log out in Settings is a separate button at the bottom.
- Sync status shows the account, server and status in one card. It shows a card when there are no changes or no drafts.
- A profile or release build talks to one fixed server. Settings shows Appearance only, the login screen's hidden route to Settings is off, and connection errors no longer link to Settings or tell you to change the URL.
- When the stored session does not match the build's server, the app signs you out once and shows a notice. Your offline work stays on the phone. When the same account signs in on the original server, the app sends the eligible pending changes. You open each draft in Sync status and send it yourself.
- Scan images load through the same server check as the API and refuse a redirect to another origin in a profile or release build.
- In a debug build, Server connection opens from the Connection group in Settings, on a screen of its own. It lists the saved servers in one card, with an In use mark. + Add in the top bar (+ Server when no server is saved) opens a dialog for the name and address. Save is under the saved servers. A keep-or-discard question closes and changes nothing when the session ends or changes while it is open. A failed Save shows an error and stays on the screen.
- More shows your profile at the top, then Gear, Film stocks and Labs under Library, then Settings and Help under App. Your profile, sync status and Log out are in Settings. Help opens the help page inside the app, under a Help title bar. Links to other sites, email and phone links do not open there and show a notice. The Settings row in More shows when a change needs your attention. When Sync status cannot read the changes or drafts on this phone, it shows a notice in place of that list, not an empty list, and Sync now reads them again.
- The local Google sign-in config file is now `env.json` (template: `env.example.json`), not `google_sign_in.json`. Rename your local copy and pass `--dart-define-from-file=env.json`.
- Internal: `CLAUDE.md` contains only `@AGENTS.md`, and the GitNexus rules live in `AGENTS.md`. The impact check no longer applies to comment, docs, and formatting edits.

### Removed

- More no longer lists Negatives at lab or Dashboard.
- Settings no longer has the Dashboard URL field.

## [2.0.0] - 2026-11-15

### Added

- The app reads each roll's stage, stage detail, Needs scan mark, plan and open lab handoff from the MetaFrames API, and the developed date of each job. Nothing on screen changes yet. A roll kept on the phone from an older API gets its stage only while it is in stock, in a camera or done shooting; its plan and Needs scan mark stay unknown until the next refresh.
- A job on an order shows the order's code and products in the roll's processing history. The order is read-only.
- A Shooting tab, where the app now opens, shows every camera holding a roll: the stock, the shot ISO against the box speed, and the start date. Each camera has Finish. Frame notes are on the roll's page. Empty cameras each have Load, and + Load picks both a camera and a roll.
- The Rolls list filter has At lab, which finds rolls whose negatives are still at a lab whatever their stage, such as a completed roll the lab has not returned, and Needs scan, which finds rolls marked for a scan. Format pills are built from the formats in the list.
- The field workflow works offline. Cameras, rolls, frames, film and labs you have opened are kept on the phone, and loading a roll, finishing it, roll notes and frame notes are saved on the phone first and sent when the server can be reached, in order, once each. A change made elsewhere in the meantime is shown as a conflict with the server's side and yours, never overwritten. More > Sync status lists what waits, with Sync now, and what other accounts have left on the phone.
- Roll notes can be edited from the roll and from the Shooting card, and frame notes show their sync state.
- Logging out or switching server with unsent changes asks to keep them on the phone or discard them. Kept changes are sent only when the same account signs in again on the same server.
- Quick-create forms for cameras, lenses, film stocks, labs and added rolls save a draft before sending. A create that times out or is interrupted is kept, listed in the picker and in Sync status, and sent again under the same id without making a second record.
- Each saved server can have a dashboard URL. The Dashboard entry in More opens it in the browser (the one of the server in use when tapped); if no browser takes it, the address can be copied.
- A roll card shows one stage label, the same as the dashboard: what a processing roll is doing or waiting for, such as "Lab developing" or "Waiting to scan at home", else its stage, such as "Completed". A Negatives at lab stamp shows when the label does not already say a lab has the roll. When two cards in the Rolls list read the same, each shows the start of its id, such as #1c8d. A roll kept on the phone from an older API shows its plain status until the list is refreshed.
- Edit Roll sends the version of the roll it opened with. If the roll changed meanwhile, such as a note saved from the phone, nothing is saved and the form reloads to show what changed. Needs a MetaFrames API that returns `version` on rolls and accepts `If-Match`.
- A roll's page has one button for the next processing step, taken from its stage, jobs and plan: Develop, Scan, Start developing at home, Start scanning at home or Hand to lab. When the plan does not say where the step is done, a How is it processed? sheet asks for home or a lab first; a home develop is offered only when no job or lab holds the film, and a home scan only with a scanner of your own. The send form then opens with the service the roll needs.
- A roll's page has a More actions menu with Change plan, Needs scan and Remove needs scan, the same as the dashboard. Change plan opens the saved plan: goal, develop by and scan by, each can be Not decided. A develop-only goal sends no scanner. The plan and the Needs scan mark are saved online only; if the server refuses the plan, the sheet stays open with your choices and the reason.
- A roll's page can record the develop date (Mark as developed, from the job's sent date or the finish date up to today) and the return of the negatives (Negatives returned, by the roll's lab handoff). A roll from before handoffs opens its lab job to record the return there, and one job in progress opens with Open job. Returning the negatives comes before a scan.

### Changed

- Settings has Appearance: System, Light or Dark, kept on this phone. Dark mode uses a lighter orange and lighter text so filled buttons, links and secondary text stay readable.
- The Rolls chips are the stages the dashboard uses: All, In stock, In camera, Done shooting, Processing and Completed. Each roll is under one stage, including rolls processed at home. The chips count the rolls left after the filters, and changing the chip keeps the filters. A roll kept on the phone from an older API is only under All until the list is refreshed. Rolls other than film in stock list the newest start date first, and rolls not started come last.
- The tabs are Shooting, Rolls and More. Shooting replaces Home and its counters. Rolls ready for the lab are under the Done shooting chip, negatives at the lab under More and the At lab filter, and expiring film in the Rolls list. Links to `/home` open Shooting.
- Note frame left the Shooting tab. The card still finishes the roll and opens roll notes. Frame notes stay on the roll's page.
- Note frame asks only for the frame number and starts empty each time: the app does not guess which frame was just taken. Any whole number from 0 opens, including frames past the exposure count. Frame notes need no scans.
- A roll's page shows one main button, from its stage, jobs and plan. Send to lab (to record processing already done) and Re-scan moved to the More actions menu. Re-scan is offered only when the negatives are at home.
- The main button is at the top of a roll's page. In stock it loads the roll; in a camera it is Log frame, which asks for the frame number and opens its notes, and Finish roll is in the More actions menu. In a camera, frames and notes come before the processing history; while a roll is processed, its jobs come right after the roll card.
- In stock, the Rolls list shows film soonest expiry first and marks expired film. Load roll's picker marks expired and expiring rolls, and searching it by format, such as 120, narrows the list.
- The Expiry entry left More. The screen still opens from a link.
- Lenses used lists each lens as a row you can tap, shows how many are selected, and the save button waits while the change is sent.
- Load roll's ISO field shows the box speed it defaults to, and refuses text that is not a whole number instead of loading the roll at box speed. Lenses are marked optional.
- A camera's page shows the shot ISO with the box speed it differs from, instead of calling it pushed or pulled: the development request is asked for separately when the roll is sent to a lab.
- A job done at home shows a stored expected date for negatives or scans.
- New app icon and logo: a film canister, on the home screen and next to the title on the sign-in screen.

### Removed

These workflows left the phone. The data stays on the server. Use the dashboard.

- Scanners and orders: the Scanners and Orders screens and their links. Use the dashboard to add, edit and delete scanners, to set scan settings, and to record orders, order lines and prices. Send to Lab still picks a scanner and its settings for a scan job.
- Processing edit: Edit Processing Job. A job can no longer be edited or deleted on the phone. Send to Lab and Re-scan still record new jobs, with no order and no price. Use the dashboard to change a job.
- Import and compare: Import scans and the scan comparison. Use the dashboard to import and to compare scans. A roll's page still shows scans, with view, zoom, download and share.
- Full gear admin: edit, activate, deactivate and delete for cameras and lenses, and the Manage lenses screen. A camera's page and a lens's page are read-only. Quick add of a camera or a lens stays. Use the dashboard for specs, notes and lens links.
- Stock and lab admin: edit for film stocks, and edit and delete for labs. A film stock's page and a lab's page are read-only. Quick add of a film stock or a lab name stays. Use the dashboard for stock origins, base stock, notes, lab address and lab scanners.

### Fixed

- After a change sent from the phone lands, the lists on the phone take the roll the server returned. A finish that happened meanwhile shows, instead of the phone's guess of that one step.
- A conflict that could not read the server's note says so, instead of showing an empty note.
- A list or roll that was read while one of your own changes reached the server is read again, instead of showing the earlier state or nothing.
- Opening a frame that has no notes or scans yet no longer leaves the app asking the server for it again in the background.
- On a phone with on-screen navigation buttons, the Start / Send to lab button at the end of the send form scrolls above them instead of staying under them.
- A roll's page shows the same stage label as its card in the list, such as "Developing at home", instead of the plain status "At lab".
- Starting a home scan without a scanner of your own says to add one on the dashboard first, before you tap Start.

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

[Unreleased]: https://github.com/vhnam/meta-frames-app/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/vhnam/meta-frames-app/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/vhnam/meta-frames-app/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/vhnam/meta-frames-app/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vhnam/meta-frames-app/releases/tag/v1.0.0
