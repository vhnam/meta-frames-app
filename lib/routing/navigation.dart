import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

extension AppNavigation on BuildContext {
  /// Closes the current screen, passing [result] to whoever pushed it. A screen
  /// opened directly from a link has nothing under it, so go Home instead of
  /// failing.
  void closeScreen<T extends Object?>([T? result]) {
    if (canPop()) {
      pop(result);
    } else {
      go(Routes.home);
    }
  }
}
