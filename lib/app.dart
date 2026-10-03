import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/router.dart';
import 'ui/core/theme.dart';

/// Same scroll feel on every platform: no iOS bounce, no platform scrollbar swap.
class _UniversalScroll extends MaterialScrollBehavior {
  const _UniversalScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class MetaFramesApp extends ConsumerWidget {
  const MetaFramesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'MetaFrames',
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    scrollBehavior: const _UniversalScroll(),
    routerConfig: ref.watch(routerProvider),
  );
}
