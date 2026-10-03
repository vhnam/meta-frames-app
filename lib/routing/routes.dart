import '../domain/models/models.dart';

/// Every location in the app. Screens navigate with `context.push(Routes.x(…))`
/// so a path is built in one place and always matches the router table.
abstract final class Routes {
  // Tabs.
  static const home = '/home';
  static const gear = '/gear';
  static const rolls = '/rolls';
  static const more = '/more';

  // Secondary screens.
  static const film = '/film';
  static const expiry = '/expiry';
  static const labs = '/labs';
  static const negativesAtLab = '/negatives-at-lab';
  static const settings = '/settings';

  // Cameras.
  static const cameraNew = '/cameras/new';
  static String camera(String id) => '/cameras/$id';
  static String cameraEdit(String id) => '/cameras/$id/edit';
  static String cameraLenses(String id) => '/cameras/$id/lenses';
  static String cameraLoadRoll(String id) => '/cameras/$id/load';

  // Lenses.
  static const lensNew = '/lenses/new';
  static String lens(String id) => '/lenses/$id';
  static String lensEdit(String id) => '/lenses/$id/edit';

  // Film stocks.
  static const stockNew = '/stocks/new';
  static String stock(String id) => '/stocks/$id';
  static String stockEdit(String id) => '/stocks/$id/edit';

  // Rolls.
  static String rollNew({String? stockId}) =>
      stockId == null ? '/rolls/new' : '/rolls/new?stockId=$stockId';
  static String roll(String id) => '/rolls/$id';
  static String rollEdit(String id) => '/rolls/$id/edit';
  static String rollLoad(String id) => '/rolls/$id/load';
  static String rollLenses(String id) => '/rolls/$id/lenses';
  static String rollSend(String id, {bool resend = false}) =>
      resend ? '/rolls/$id/send?resend=true' : '/rolls/$id/send';
  static String frame(String rollId, int number) =>
      '/rolls/$rollId/frames/$number';

  // Processing jobs and their scans.
  static String processing(String id) => '/processing/$id';
  static String importScans(String id) => '/processing/$id/import';
  static String scanViewer(String id, Scanner scanner, int index) =>
      '/processing/$id/scans/${scanner.name}/$index';
  static String compare(String id, int frameNumber) =>
      '/processing/$id/frames/$frameNumber/compare';
}
