import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/more/widgets/more_tab.dart';
import 'package:meta_frames/ui/more/widgets/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../testing/local.dart';

const picture = 'https://lh3.googleusercontent.com/a/profile?size=80';

class _PendingImage extends ImageProvider<_PendingImage> {
  final frame = Completer<ImageInfo>();

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(frame.future);
}

void main() {
  final profile = {
    'id': 'first',
    'name': 'Ansel',
    'email': 'ansel@example.com',
  };
  test('the profile parser keeps only valid HTTPS picture URLs', () {
    expect(User.fromJson(profile).avatarUrl, isNull);
    expect(
      User.fromJson({...profile, 'avatarUrl': picture}).avatarUrl,
      picture,
    );
    for (final invalid in <Object?>[
      null,
      '',
      '   ',
      'https://[broken',
      42,
      '/a/profile',
      'http://example.com/image',
      'https:///image',
      'https://user:secret@example.com/image',
    ]) {
      expect(
        User.fromJson({...profile, 'avatarUrl': invalid}).avatarUrl,
        isNull,
        reason: 'avatarUrl = $invalid',
      );
    }
  });

  test('a malformed picture host does not enter the image loader', () {
    expect(
      User.fromJson({...profile, 'avatarUrl': 'https://bad host/image'})
          .avatarUrl,
      isNull,
    );
  });

  test('the public avatar uses the exact URL without API credentials', () {
    final container = ProviderContainer.test(
      overrides: [
        httpClientProvider.overrideWith(
          (_) => throw StateError('API client read'),
        ),
      ],
    );
    final image = container.read(avatarImageProvider)(picture) as NetworkImage;
    expect(image.url, picture);
    expect(image.headers, isNull);
  });

  for (final screen in [const MoreTab(), const SettingsScreen()]) {
    testWidgets(
      '${screen.runtimeType} keeps the profile through image loading and failure',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final session = await boundSession();
        addTearDown(session.dispose);
        final pending = _PendingImage();
        final broken = _PendingImage();
        var url = picture;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              prefsProvider.overrideWithValue(prefs),
              sessionStoreProvider.overrideWithValue(session),
              localStoreProvider.overrideWithValue(null),
              currentUserProvider.overrideWith(
                (_) async => User.fromJson({...profile, 'avatarUrl': url}),
              ),
              avatarImageProvider.overrideWithValue(
                (address) => address == picture ? pending : broken,
              ),
            ],
            child: MaterialApp(home: screen),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byType(AccountCard);
        final icon = find.descendant(
          of: card,
          matching: find.byIcon(Icons.person_outline),
        );
        final pixels = find.descendant(
          of: card,
          matching: find.byType(RawImage),
        );
        void checkIdentity() {
          for (final field in ['name', 'email']) {
            expect(
              find.descendant(of: card, matching: find.text(profile[field]!)),
              findsOneWidget,
            );
          }
        }

        checkIdentity();
        expect(icon, findsOneWidget);
        final decoded = await tester.runAsync(() => createTestImage());
        pending.frame.complete(ImageInfo(image: decoded!));
        await tester.pumpAndSettle();
        expect(
          tester.widget<RawImage>(pixels).image!.isCloneOf(decoded),
          isTrue,
        );
        checkIdentity();
        url = '$picture&updated=1';
        ProviderScope.containerOf(tester.element(card))
            .invalidate(currentUserProvider);
        await tester.pumpAndSettle();
        expect(icon, findsOneWidget);
        expect(pixels, findsNothing);
        broken.frame.completeError(StateError('image unavailable'));
        await tester.pumpAndSettle();
        expect(icon, findsOneWidget);
        checkIdentity();
      },
    );
  }

  testWidgets('an old request cannot replace the next account picture', (
    tester,
  ) async {
    final old = _PendingImage();
    final current = _PendingImage();
    final user = ValueNotifier(
      User.fromJson({...profile, 'avatarUrl': picture}),
    );
    addTearDown(user.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarImageProvider.overrideWithValue(
            (url) => url == picture ? old : current,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: user,
              builder: (_, account, _) => AccountCard(account),
            ),
          ),
        ),
      ),
    );
    user.value = User.fromJson({
      'id': 'second',
      'email': 'second@example.com',
      'avatarUrl': '$picture&user=2',
    });
    await tester.pump();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    final decoded = await tester.runAsync(() => createTestImage(width: 2));
    current.frame.complete(ImageInfo(image: decoded!));
    await tester.pumpAndSettle();
    final stale = await tester.runAsync(() => createTestImage(width: 3));
    old.frame.complete(ImageInfo(image: stale!));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RawImage>(find.byType(RawImage)).image!.isCloneOf(decoded),
      isTrue,
    );
  });
}
