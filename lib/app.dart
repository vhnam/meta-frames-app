import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'routing/router.dart';
import 'ui/core/theme.dart';
import 'ui/sync/view_models/prefetch.dart';
import 'ui/sync/view_models/sync_actions.dart';

/// Same scroll feel on every platform: no iOS bounce, no platform scrollbar swap.
class _UniversalScroll extends MaterialScrollBehavior {
  const _UniversalScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class MetaFramesApp extends ConsumerStatefulWidget {
  const MetaFramesApp({super.key});

  @override
  ConsumerState<MetaFramesApp> createState() => _MetaFramesAppState();
}

class _MetaFramesAppState extends ConsumerState<MetaFramesApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the foreground: send what waited, and refresh what is kept.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(ref.read(partitionControllerProvider).sync());
    ref.invalidate(prefetchOnOpenProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(syncRefresherProvider)
      ..watch(prefetchOnOpenProvider);
    return MaterialApp.router(
      title: 'MetaFrames',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      scrollBehavior: const _UniversalScroll(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
