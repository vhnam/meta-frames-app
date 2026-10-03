import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/domain/models/models.dart';
import 'package:meta_frames/providers.dart';
import 'package:meta_frames/ui/scans/view_models/import_scans_view_model.dart';

import '../../testing/fakes.dart';

void main() {
  late FakeScanRepository scans;
  late ProviderContainer container;
  late ImportScansViewModel vm;
  late NotifierProvider<ImportScansViewModel, ImportScansState> state;

  setUp(() {
    scans = FakeScanRepository();
    container = ProviderContainer(
      overrides: [scanRepositoryProvider.overrideWithValue(scans)],
    );
    addTearDown(container.dispose);
    final provider = importScansViewModelProvider('p1');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    vm = container.read(provider.notifier);
    state = provider;
  });

  const files = [
    (name: 'b.jpg', path: '/tmp/b.jpg'),
    (name: 'a.jpg', path: '/tmp/a.jpg'),
  ];

  test('picked files are sorted by name and numbered by the server', () async {
    await vm.setFiles(files, startFrame: 3);
    final items = container.read(state).items;
    expect(items.map((i) => i.name), ['a.jpg', 'b.jpg']);
    expect(items.map((i) => i.frame), [3, 4]);
  });

  test('files the server cannot number are not importable', () async {
    scans.unnumberable['a.jpg'] = 'no frame number in name';
    await vm.setFiles(files);
    final st = container.read(state);
    expect(st.items.first.error, 'no frame number in name');
    expect(st.items.where((i) => i.ready).map((i) => i.name), ['b.jpg']);
  });

  test(
    'a manual frame number clears the error and makes the file ready',
    () async {
      scans.unnumberable['a.jpg'] = 'bad';
      await vm.setFiles(files);
      vm.setFrame('a.jpg', 7);
      final a = container
          .read(state)
          .items
          .firstWhere((i) => i.name == 'a.jpg');
      expect(a.ready, isTrue);
      expect(a.frame, 7);
      expect(a.error, isNull);
    },
  );

  test('a clean import uploads everything and clears the selection', () async {
    await vm.setFiles(files);
    final summary = await vm.import();
    expect(scans.uploaded, ['a.jpg@1', 'b.jpg@2']);
    expect(summary.complete, isTrue);
    expect(summary.message, '2 imported');
    final st = container.read(state);
    expect(st.items, isEmpty);
    expect(st.busy, isFalse);
  });

  test('failed uploads stay selected for a retry', () async {
    await vm.setFiles(files);
    scans.uploadFails.add('b.jpg');

    final summary = await vm.import();

    expect(summary.complete, isFalse);
    expect(summary.message, '1 imported, 1 failed');
    final st = container.read(state);
    expect(st.items.map((i) => i.name), ['b.jpg']);
    expect(st.failures.single.fileName, 'b.jpg');
    expect(st.failures.single.reason, 'disk full');
  });

  test('scanner and replace options are kept', () {
    vm
      ..setScanner(Scanner.frontier)
      ..setReplace(true);
    expect(container.read(state).scanner, Scanner.frontier);
    expect(container.read(state).replace, isTrue);
  });
}
