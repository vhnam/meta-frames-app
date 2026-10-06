import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repositories/camera_repository.dart';
import 'repositories/camera_repository_remote.dart';
import 'repositories/film_stock_repository.dart';
import 'repositories/film_stock_repository_remote.dart';
import 'repositories/lab_repository.dart';
import 'repositories/lab_repository_remote.dart';
import 'repositories/lens_repository.dart';
import 'repositories/lens_repository_remote.dart';
import 'repositories/processing_repository.dart';
import 'repositories/processing_repository_remote.dart';
import 'repositories/roll_repository.dart';
import 'repositories/roll_repository_remote.dart';
import 'repositories/scan_repository.dart';
import 'repositories/scan_repository_remote.dart';
import 'repositories/settings_repository.dart';
import 'repositories/settings_repository_prefs.dart';
import 'services/api_client.dart';

/// Overridden in `main()` once [SharedPreferences] has loaded.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryPrefs(ref.watch(prefsProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(() => ref.read(settingsRepositoryProvider).baseUrl),
);

// Tests override these with fakes.
final cameraRepositoryProvider = Provider<CameraRepository>(
  (ref) => CameraRepositoryRemote(ref.watch(apiClientProvider)),
);
final lensRepositoryProvider = Provider<LensRepository>(
  (ref) => LensRepositoryRemote(ref.watch(apiClientProvider)),
);
final filmStockRepositoryProvider = Provider<FilmStockRepository>(
  (ref) => FilmStockRepositoryRemote(ref.watch(apiClientProvider)),
);
final labRepositoryProvider = Provider<LabRepository>(
  (ref) => LabRepositoryRemote(ref.watch(apiClientProvider)),
);
final rollRepositoryProvider = Provider<RollRepository>(
  (ref) => RollRepositoryRemote(ref.watch(apiClientProvider)),
);
final processingRepositoryProvider = Provider<ProcessingRepository>(
  (ref) => ProcessingRepositoryRemote(ref.watch(apiClientProvider)),
);
final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepositoryRemote(ref.watch(apiClientProvider)),
);
