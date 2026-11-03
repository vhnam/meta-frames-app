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

  /// Closes an edit screen and the details screen under it, once the object
  /// they show is deleted. Without a screen left to return to, goes Home.
  void closeDeleted() {
    final router = GoRouter.of(this);
    for (var i = 0; i < 2; i++) {
      if (!router.canPop()) {
        router.go(Routes.home);
        return;
      }
      router.pop();
    }
  }
}
