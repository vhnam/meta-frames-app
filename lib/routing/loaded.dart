import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Builds a screen from data loaded by [provider], so a route needs only an id
/// in its path. Shows a back-able placeholder while loading or on error.
Widget routeData<T>(
  ProviderListenable<AsyncValue<T>> provider,
  Widget Function(T data) builder,
) => Consumer(
  builder: (context, ref, _) {
    final value = ref.watch(provider);
    // Keep showing the screen while a refresh runs: a form must not lose its
    // state when the data it was opened with is reloaded after a save.
    if (value.hasValue) return builder(value.requireValue);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: value.hasError
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${value.error}', textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      ),
    );
  },
);
