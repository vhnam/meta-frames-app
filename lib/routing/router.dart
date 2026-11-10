import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/local_store.dart';
import '../data/services/session_store.dart';
import '../domain/models/models.dart';
import '../providers.dart';
import '../ui/auth/widgets/login_screen.dart';
import '../ui/auth/widgets/recover_screen.dart';
import '../ui/auth/widgets/register_screen.dart';
import '../ui/film/widgets/film_tab.dart';
import '../ui/film/widgets/stock_detail.dart';
import '../ui/film/widgets/stock_form.dart';
import '../ui/gear/widgets/camera_detail.dart';
import '../ui/gear/widgets/camera_form.dart';
import '../ui/gear/widgets/gear_tab.dart';
import '../ui/gear/widgets/lens_detail.dart';
import '../ui/gear/widgets/lens_form.dart';
import '../ui/labs/widgets/lab_detail.dart';
import '../ui/labs/widgets/labs_screen.dart';
import '../ui/labs/widgets/negatives_at_lab.dart';
import '../ui/labs/widgets/processing_detail.dart';
import '../ui/labs/widgets/send_roll.dart';
import '../ui/more/widgets/more_tab.dart';
import '../ui/more/widgets/settings_screen.dart';
import '../ui/rolls/widgets/add_rolls.dart';
import '../ui/rolls/widgets/expiry_screen.dart';
import '../ui/rolls/widgets/frame_notes.dart';
import '../ui/rolls/widgets/load_roll.dart';
import '../ui/rolls/widgets/roll_detail.dart';
import '../ui/rolls/widgets/roll_form.dart';
import '../ui/rolls/widgets/roll_lenses.dart';
import '../ui/rolls/widgets/rolls_tab.dart';
import '../ui/scans/widgets/scan_viewer.dart';
import '../ui/shooting/widgets/shooting_tab.dart';
import '../ui/sync/view_models/drafts.dart';
import '../ui/sync/widgets/sync_screen.dart';
import 'loaded.dart';
import 'routes.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Sends visitors to the login screen and signed-in users away from the
/// signed-out screens. Settings is open to both, because a visitor may need to
/// set the server URL before signing in.
String? authRedirect({required bool signedIn, required String location}) {
  if (location == Routes.settings) return null;
  final signedOutScreen =
      location == Routes.login ||
      location == Routes.register ||
      location == Routes.recover;
  if (!signedIn && !signedOutScreen) return Routes.login;
  if (signedIn && signedOutScreen) return Routes.shooting;
  return null;
}

/// Screens that open over the tab bar are top-level routes on the root
/// navigator. Each takes ids in its path and loads what it needs, so any
/// location can be opened directly. With a [session], every route follows
/// [authRedirect].
GoRouter buildRouter({
  String initialLocation = Routes.shooting,
  SessionStore? session,
}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  refreshListenable: session,
  redirect: session == null
      ? null
      : (_, state) => authRedirect(
          signedIn: session.signedIn,
          location: state.matchedLocation,
        ),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => Routes.shooting),
    GoRoute(path: Routes.home, redirect: (_, _) => Routes.shooting),
    _route(Routes.login, (_) => const LoginScreen()),
    _route(Routes.register, (_) => const RegisterScreen()),
    _route(Routes.recover, (_) => const RecoverScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.shooting,
              builder: (_, _) => const ShootingTab(),
            ),
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
    _route(Routes.gear, (_) => const GearTab()),
    _route(Routes.film, (_) => const FilmTab()),
    _route(Routes.expiry, (_) => const ExpiryScreen()),
    _route(Routes.labs, (_) => const LabsScreen()),
    _route('/labs/:id', (s) => LabDetailScreen(labId: s.pathParameters['id']!)),
    _route(Routes.negativesAtLab, (_) => const NegativesAtLabScreen()),
    _route(Routes.settings, (_) => const SettingsScreen()),
    _route(Routes.sync, (_) => const SyncScreen()),

    // Cameras. `new` is declared before `:id` so it is not read as an id.
    _route(
      Routes.cameraNew,
      (s) => _create(s, (d, _) => CameraFormScreen(draft: d)),
    ),
    _route(
      '/cameras/:id',
      (s) => CameraDetailScreen(cameraId: s.pathParameters['id']!),
    ),
    _route(
      '/cameras/:id/load',
      (s) => routeData(
        cameraProvider(s.pathParameters['id']!),
        (c) => LoadRollScreen(camera: c),
      ),
    ),

    // Lenses.
    _route(
      Routes.lensNew,
      (s) => _create(
        s,
        (d, _) =>
            LensFormScreen(draft: d, mount: s.uri.queryParameters['mount']),
      ),
    ),
    _route(
      '/lenses/:id',
      (s) => LensDetailScreen(lensId: s.pathParameters['id']!),
    ),
    // Film stocks.
    _route(
      Routes.stockNew,
      (s) => _create(s, (d, _) => StockFormScreen(draft: d)),
    ),
    _route(
      '/stocks/:id',
      (s) => StockDetailScreen(stockId: s.pathParameters['id']!),
    ),
    // Rolls.
    _route(Routes.load, (_) => const LoadRollScreen()),
    _route('/rolls/new', (s) {
      final stockId = s.uri.queryParameters['stockId'];
      if (stockId == null) {
        return _create(s, (d, q) => AddRollsScreen(draft: d, quick: q));
      }
      return routeData(
        stockDetailProvider(stockId),
        (d) => AddRollsScreen(
          stock: d.stock,
          quick: s.uri.queryParameters['quick'] == '1',
        ),
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
      (s) => routeData(rollDetailProvider(s.pathParameters['id']!), (d) {
        final rescan = s.uri.queryParameters['resend'] == 'true';
        final types = sendableTypes(d.roll.status, d.processing.length);
        return SendRollScreen(
          roll: d.roll,
          stock: d.stock,
          rescan: rescan,
          types: rescan
              ? const [ProcessingType.scan]
              // A link can open a roll with nothing to send; the server refuses.
              : (types.isEmpty ? ProcessingType.values : types),
        );
      }),
    ),
    _route(
      '/rolls/:id/notes',
      (s) => RollNotesScreen(rollId: s.pathParameters['id']!),
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
            rollId: p.rollId,
          ),
        ),
      );
    }),
  ],
);

/// A create form: `quick=1` asks only what the server needs, and `draft=<id>`
/// reopens an unsent draft (a draft sent or discarded meanwhile opens empty).
Widget _create(
  GoRouterState s,
  Widget Function(Draft? draft, bool quick) build,
) {
  final quick = s.uri.queryParameters['quick'] == '1';
  final id = s.uri.queryParameters['draft'];
  if (id == null) return build(null, quick);
  return routeData(draftProvider(id), (d) => build(d, quick));
}

/// A screen over the tab bar. It has no bottom bar to hold it above the system
/// navigation bar, so the route keeps it clear.
GoRoute _route(String path, Widget Function(GoRouterState state) builder) =>
    GoRoute(
      path: path,
      parentNavigatorKey: _rootKey,
      builder: (context, state) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(top: false, child: builder(state)),
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionStoreProvider);
  final router = buildRouter(session: session);
  // Records belong to an account: never show one user's cache to the next.
  void dropCachedData() => invalidateAllData(ref);
  session.addListener(dropCachedData);
  ref.onDispose(() {
    session.removeListener(dropCachedData);
    router.dispose();
  });
  return router;
});
