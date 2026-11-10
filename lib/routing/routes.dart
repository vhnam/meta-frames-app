import '../domain/models/models.dart';

/// Every location in the app. Screens navigate with `context.push(Routes.x(…))`
/// so a path is built in one place and always matches the router table.
abstract final class Routes {
  // Signed-out screens.
  static const login = '/login';
  static const register = '/register';
  static const recover = '/recover';

  // Tabs.
  static const shooting = '/shooting';
  static const rolls = '/rolls';
  static const more = '/more';

  /// Where the old Home tab was. Redirects to [shooting] so saved links work.
  static const home = '/home';

  // Secondary screens.
  static const gear = '/gear';
  static const film = '/film';
  static const expiry = '/expiry';
  static const labs = '/labs';
  static const negativesAtLab = '/negatives-at-lab';
  static const settings = '/settings';

  /// Changes waiting for the server, drafts and other accounts' kept data.
  static const sync = '/sync';

  // Labs.
  static String lab(String id) => '/labs/$id';

  // Cameras.
  static const cameraNew = '/cameras/new';

  /// New camera (always the quick form): [draft] reopens an unsent one.
  static String cameraCreate({String? draft}) =>
      _create('/cameras/new', {'draft': draft});
  static String camera(String id) => '/cameras/$id';
  static String cameraLoadRoll(String id) => '/cameras/$id/load';

  // Lenses.
  static const lensNew = '/lenses/new';
  static String lensCreate({String? mount, String? draft}) =>
      _create('/lenses/new', {'mount': mount, 'draft': draft});
  static String lens(String id) => '/lenses/$id';

  // Film stocks.
  static const stockNew = '/stocks/new';
  static String stockCreate({String? draft}) =>
      _create('/stocks/new', {'draft': draft});
  static String stock(String id) => '/stocks/$id';

  // Rolls.
  /// Load a roll, picking both the camera and the roll.
  static const load = '/load';
  static String rollNew({String? stockId, bool quick = false, String? draft}) =>
      _create('/rolls/new', {
        'stockId': stockId,
        'quick': quick ? '1' : null,
        'draft': draft,
      });
  static String roll(String id) => '/rolls/$id';
  static String rollEdit(String id) => '/rolls/$id/edit';
  static String rollLoad(String id) => '/rolls/$id/load';
  static String rollLenses(String id) => '/rolls/$id/lenses';
  static String rollSend(String id, {bool resend = false}) =>
      resend ? '/rolls/$id/send?resend=true' : '/rolls/$id/send';
  static String frame(String rollId, int number) =>
      '/rolls/$rollId/frames/$number';
  static String rollNotes(String id) => '/rolls/$id/notes';

  // Processing jobs and their scans.
  static String processing(String id) => '/processing/$id';
  static String scanViewer(String id, Scanner scanner, int index) =>
      '/processing/$id/scans/${scanner.name}/$index';

  static String _create(String path, Map<String, String?> query) {
    final q = {
      for (final e in query.entries)
        if (e.value != null) e.key: e.value!,
    };
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }
}
