import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/gear/gear_tab.dart';
import 'features/home/home_tab.dart';
import 'features/rolls/rolls_tab.dart';

/// Same scroll feel on every platform: no iOS bounce, no platform scrollbar swap.
class _UniversalScroll extends MaterialScrollBehavior {
  const _UniversalScroll();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class MetaFramesApp extends StatelessWidget {
  const MetaFramesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MetaFrames',
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    scrollBehavior: const _UniversalScroll(),
    home: const _Shell(),
  );
}

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: const [HomeTab(), GearTab(), RollsTab()],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Gear',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Rolls',
          ),
        ],
      ),
    ),
  );
}
