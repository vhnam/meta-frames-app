# MetaFrames improvement plan: architecture and performance

This plan compares the app against two Flutter guides and lists changes in priority order:

- [Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Performance best practices](https://docs.flutter.dev/perf/best-practices)

The audit covers the 43 Dart files under `lib/`. Counts come from searching the source. The performance items have not yet been confirmed by profiling.

## Current state

### Already aligned

- Riverpod provides dependency injection. `prefsProvider` and `apiProvider` are overridden in `main.dart`. Keep Riverpod; switching to `provider` or `ChangeNotifier` is not needed.
- Model fields are `final`, and models are built only through `fromJson`.
- The tab shell uses `IndexedStack`, and some lists already use lazy `.builder` constructors.

### Gaps

| Guide rule (strongly recommended) | Current state |
|---|---|
| Separate data and UI layers; use the repository pattern | One class, [`api.dart`](../lib/core/api.dart), handles HTTP, preferences, URL building and every endpoint. There are no repositories. |
| MVVM; no logic in widgets | Widgets contain 37 `ref.read(apiProvider)` calls across 21 files. Filtering, sorting and multi-call API flows live in `State` classes, for example [`load_roll.dart` lines 44–150](../lib/features/rolls/load_roll.dart#L44-L150). |
| Abstract repositories and fakes for testing | There are no abstractions or fakes. The test imports `isExpired` from a screen file ([`load_roll.dart` line 12](../lib/features/rolls/load_roll.dart#L12)). |
| Unidirectional data flow | After any mutation, `refreshAll` invalidates all 17 providers. It has 27 call sites, so every edit refetches the whole app. |
| Immutable, typed models | Request bodies are `Map<String, dynamic>`. Models have no `toJson`, `==` or `copyWith`. |

## Phase 0: Guardrails

1. Enable these lints in [`analysis_options.yaml`](../analysis_options.yaml):
   - `prefer_const_constructors`
   - `prefer_const_literals_to_create_immutables`
   - `prefer_const_declarations`
   - `avoid_unnecessary_containers`
   - `sized_box_for_whitespace`
2. Record a baseline with DevTools in profile mode on a low-end Android device. Measure frame times on these screens:
   - Home
   - Rolls
   - Processing detail with scans
   - Compare

## Phase 1: Performance fixes

These fixes do not depend on the refactor and are small.

1. **The scan grid builds every item at once.** In [`scan_grid.dart` line 62](../lib/features/scans/scan_grid.dart#L62), a `GridView.builder` uses `shrinkWrap: true` and `NeverScrollableScrollPhysics`. It sits inside the `ListView` at [`processing_detail.dart` line 87](../lib/features/labs/processing_detail.dart#L87). As a result, every thumbnail is built and downloaded at once: 36 frames × 2 scanners = 72 images.
   - Change the parent to a `CustomScrollView` with a `SliverGrid`.
   - Move the frame sort out of `build`.
2. **Scans decode at full resolution.** [`compare_screen.dart` line 109](../lib/features/scans/compare_screen.dart#L109) and [`scan_viewer.dart` line 88](../lib/features/scans/scan_viewer.dart#L88) call `Image.network` without `cacheWidth`. A 20–50 MP film scan takes about 80–200 MB of RGBA memory per image.
   - Set `cacheWidth` to screen width × `devicePixelRatio`.
   - Load the full-resolution image only when the user zooms past a threshold.
3. **Sharing buffers the whole file in memory.** `scanBytes` ([`api.dart` line 307](../lib/core/api.dart#L307)) loads the full scan into RAM. Stream it to a temporary file from `path_provider` instead.
4. **Fonts download at runtime.** `google_fonts` fetches Space Grotesk, JetBrains Mono and Geist Mono on first launch. Text changes appearance after the download, and fonts are missing when offline.
   - Bundle the font files under `assets/fonts`.
   - Set `GoogleFonts.config.allowRuntimeFetching = false`.
5. **List rows use `Opacity`.** [`cards.dart` lines 128–132](../lib/widgets/cards.dart#L128-L132) wraps dimmed rows in `Opacity`. Apply the alpha to text and icon colors instead.
6. **Some lists build all children up front.** Convert these from `ListView(children: ...)` with `for` loops to `CustomScrollView` with `SliverList.builder`. Forms can keep `ListView(children: ...)`.
   - [`home_tab.dart` line 75](../lib/features/home/home_tab.dart#L75)
   - [`gear_tab.dart` line 86](../lib/features/gear/gear_tab.dart#L86)
   - The camera and lens detail lists
7. **Low priority:**
   - Replace the `IntrinsicHeight` in `_Counter` ([`home_tab.dart` line 448](../lib/features/home/home_tab.dart#L448)) with a fixed-height row.
   - Convert the 18 `Widget _buildX()` helper methods to `StatelessWidget` classes with `const` constructors.

## Phase 2: Data layer

Target structure, following the layer-first layout in the Flutter guide:

```
lib/
  data/
    services/      api_client.dart (HTTP, errors, base URL), prefs_service.dart
    repositories/  camera/, lens/, film_stock/, roll/, processing/, scan/, settings/
                   each: x_repository.dart (abstract) + x_repository_remote.dart
  domain/
    models/        immutable models, plus expiry.dart (isExpired, expiryKey)
  ui/
    core/          theme and shared widgets (today's widgets/ and core/theme.dart)
    <feature>/     view_models/, widgets/
  routing/         (Phase 4)
  main.dart, app.dart
test/
  data/
  ui/
  testing/fakes/
```

1. Split `Api` into two parts:
   - `ApiClient`, which handles only transport: HTTP, errors and the base URL.
   - One repository per domain. Each repository has an abstract interface and a remote implementation.
2. Replace `Map<String, dynamic>` request bodies with typed request classes that have `toJson`.
3. Make the models value types with `==`, `hashCode` and `copyWith`. Write these by hand or generate them with `freezed`. With equality, `ref.watch(provider.select(...))` can skip unneeded rebuilds.
4. Move `isExpired`, `ymd` and `newId` out of UI and API files into the domain layer.

## Phase 3: UI layer (MVVM with Riverpod)

1. **ViewModels:** give each screen a `Notifier` or `AsyncNotifier`, for example `LoadRollViewModel` and `RollsViewModel`. Widgets only watch state and call ViewModel methods. This removes all 37 `ref.read(apiProvider)` calls from widgets.
2. **Commands:** use Riverpod 3 mutations, or a small `Command` class with running, error and completed states. This replaces the manual `busy` flags and the `guard()` and `toast` code repeated in each screen.
3. **Targeted invalidation:** remove `refreshAll`. Each mutation invalidates only the providers it affects. For example, `finishRoll` invalidates `rollDetailProvider(id)`, `rollsProvider` and `expiryProvider`. This fixes correctness and performance together.
4. **Derived data:** move computed data into providers so `build` does not repeat it on every rebuild:
   - The home counters and home sections
   - The gear active/inactive split
   - The sorts in the stock picker and in manage lenses

## Phase 4: Navigation (optional)

The app has about 125 `Navigator` and `MaterialPageRoute` call sites. The guide recommends `go_router` for most apps.

- Adopt it only if deep links (for example to a roll or a frame) or state restoration are needed. Otherwise skip this phase.
- Do this phase last, and migrate one feature at a time.

## Phase 5: Tests

1. Write fake repositories in `test/testing/fakes/`.
2. Unit-test the ViewModels against the fakes.
3. Unit-test the repositories against a mock `http.Client`. The `Api` constructor already accepts one.
4. Widget-test each screen by overriding the repository providers with fakes.
5. Keep [`widget_test.dart`](../test/widget_test.dart) as a smoke test.

## Order of work

1. Do Phase 0 and Phase 1 first. They take about one day and give visible improvements.
2. Do Phase 2 and Phase 3 one feature at a time, not as one large change. Use this order:
   1. `rolls` (most logic and most `setState` calls)
   2. `scans`
   3. `gear`
   4. `film`
   5. `labs`
3. Put each feature migration in its own commit, together with its tests.
