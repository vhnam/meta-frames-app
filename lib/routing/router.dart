import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/models.dart';
import '../providers.dart';
import '../ui/film/widgets/film_tab.dart';
import '../ui/film/widgets/stock_detail.dart';
import '../ui/film/widgets/stock_form.dart';
import '../ui/gear/widgets/camera_detail.dart';
import '../ui/gear/widgets/camera_form.dart';
import '../ui/gear/widgets/gear_tab.dart';
import '../ui/gear/widgets/lens_detail.dart';
import '../ui/gear/widgets/lens_form.dart';
import '../ui/gear/widgets/manage_lenses.dart';
import '../ui/home/widgets/home_tab.dart';
import '../ui/labs/widgets/labs_screen.dart';
import '../ui/labs/widgets/negatives_at_lab.dart';
import '../ui/labs/widgets/processing_detail.dart';
import '../ui/labs/widgets/send_roll.dart';
import '../ui/more/widgets/more_tab.dart';
import '../ui/more/widgets/settings_screen.dart';
import '../ui/rolls/widgets/add_rolls.dart';
import '../ui/rolls/widgets/expiry_screen.dart';
import '../ui/rolls/widgets/load_roll.dart';
import '../ui/rolls/widgets/roll_detail.dart';
import '../ui/rolls/widgets/roll_form.dart';
import '../ui/rolls/widgets/roll_lenses.dart';
import '../ui/rolls/widgets/rolls_tab.dart';
import '../ui/scans/widgets/compare_screen.dart';
import '../ui/scans/widgets/frame_screen.dart';
import '../ui/scans/widgets/import_scans.dart';
import '../ui/scans/widgets/scan_viewer.dart';
import 'loaded.dart';
import 'routes.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Screens that open over the tab bar are top-level routes on the root
/// navigator. Each takes ids in its path and loads what it needs, so any
/// location can be opened directly.
GoRouter buildRouter({String initialLocation = Routes.home}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', redirect: (_, _) => Routes.home),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.gear, builder: (_, _) => const GearTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.rolls, builder: (_, _) => const RollsTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.more, builder: (_, _) => const MoreTab()),
          ],
        ),
      ],
    ),

    // Secondary screens.
    _route(Routes.film, (_) => const FilmTab()),
    _route(Routes.expiry, (_) => const ExpiryScreen()),
    _route(Routes.labs, (_) => const LabsScreen()),
    _route(Routes.negativesAtLab, (_) => const NegativesAtLabScreen()),
    _route(Routes.settings, (_) => const SettingsScreen()),

    // Cameras. `new` is declared before `:id` so it is not read as an id.
    _route(Routes.cameraNew, (_) => const CameraFormScreen()),
    _route(
      '/cameras/:id',
      (s) => CameraDetailScreen(cameraId: s.pathParameters['id']!),
    ),
    _route(
      '/cameras/:id/edit',
      (s) => routeData(
        cameraProvider(s.pathParameters['id']!),
        (c) => CameraFormScreen(camera: c),
      ),
    ),
    _route(
      '/cameras/:id/lenses',
      (s) => routeData(
        cameraProvider(s.pathParameters['id']!),
        (c) => ManageLensesScreen(camera: c),
      ),
    ),
    _route(
      '/cameras/:id/load',
      (s) => routeData(
        cameraProvider(s.pathParameters['id']!),
        (c) => LoadRollScreen(camera: c),
      ),
    ),

    // Lenses.
    _route(Routes.lensNew, (_) => const LensFormScreen()),
    _route(
      '/lenses/:id',
      (s) => LensDetailScreen(lensId: s.pathParameters['id']!),
    ),
    _route(
      '/lenses/:id/edit',
      (s) => routeData(
        lensProvider(s.pathParameters['id']!),
        (l) => LensFormScreen(lens: l),
      ),
    ),

    // Film stocks.
    _route(Routes.stockNew, (_) => const StockFormScreen()),
    _route(
      '/stocks/:id',
      (s) => StockDetailScreen(stockId: s.pathParameters['id']!),
    ),
    _route(
      '/stocks/:id/edit',
      (s) => routeData(
        stockDetailProvider(s.pathParameters['id']!),
        (d) => StockFormScreen(stock: d.stock, baseStock: d.baseStock),
      ),
    ),

    // Rolls.
    _route('/rolls/new', (s) {
      final stockId = s.uri.queryParameters['stockId'];
      if (stockId == null) return const AddRollsScreen();
      return routeData(
        stockDetailProvider(stockId),
        (d) => AddRollsScreen(stock: d.stock),
      );
    }),
    _route(
      '/rolls/:id',
      (s) => RollDetailScreen(rollId: s.pathParameters['id']!),
    ),
    _route(
      '/rolls/:id/edit',
      (s) => routeData(
        rollDetailProvider(s.pathParameters['id']!),
        (d) => RollFormScreen(detail: d),
      ),
    ),
    _route(
      '/rolls/:id/load',
      (s) => routeData(
        rollDetailProvider(s.pathParameters['id']!),
        (d) => LoadRollScreen(roll: d.roll),
      ),
    ),
    _route(
      '/rolls/:id/lenses',
      (s) => routeData(
        rollDetailProvider(s.pathParameters['id']!),
        (d) => RollLensesScreen(
          rollId: d.roll.id,
          cameraId: d.roll.cameraId!,
          current: d.lenses,
        ),
      ),
    ),
    _route(
      '/rolls/:id/send',
      (s) => routeData(
        rollDetailProvider(s.pathParameters['id']!),
        (d) => SendRollScreen(
          roll: d.roll,
          stock: d.stock,
          resend: s.uri.queryParameters['resend'] == 'true',
        ),
      ),
    ),
    _route(
      '/rolls/:id/frames/:n',
      (s) => FrameScreen(
        rollId: s.pathParameters['id']!,
        number: int.parse(s.pathParameters['n']!),
      ),
    ),

    // Processing jobs and their scans.
    _route(
      '/processing/:id',
      (s) => ProcessingDetailScreen(processingId: s.pathParameters['id']!),
    ),
    _route(
      '/processing/:id/import',
      (s) => ImportScansScreen(processingId: s.pathParameters['id']!),
    ),
    _route('/processing/:id/scans/:scanner/:index', (s) {
      final id = s.pathParameters['id']!;
      final scanner = Scanner.values.byName(s.pathParameters['scanner']!);
      return routeData(
        processingProvider(id),
        (p) => routeData(
          scansProvider((id, scanner)),
          (scans) => ScanViewerScreen(
            scans: scans,
            index: int.parse(s.pathParameters['index']!),
            processing: p,
            rollId: p.rollId,
          ),
        ),
      );
    }),
    _route(
      '/processing/:id/frames/:n/compare',
      (s) => CompareScreen(
        processingId: s.pathParameters['id']!,
        frameNumber: int.parse(s.pathParameters['n']!),
      ),
    ),
  ],
);

GoRoute _route(String path, Widget Function(GoRouterState state) builder) =>
    GoRoute(
      path: path,
      parentNavigatorKey: _rootKey,
      builder: (_, state) => builder(state),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
