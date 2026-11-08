import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../domain/utils.dart';
import '../../../providers.dart';
import '../../../routing/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../view_models/processing_actions.dart';
import 'lab_dialog.dart';
import '../../../data/local/local_store.dart';
import '../../sync/view_models/drafts.dart' show draftsOf;
import '../../sync/widgets/create_footer.dart';
import 'scan_order_picker.dart';

/// Stand-in for working at home: the API takes no lab id then.
const _self = 'self';

/// M-27 send a roll for processing, or record work done at home; M-31 scan a
/// processed roll again. Follows the dashboard's Send to Lab dialog.
class SendRollScreen extends ConsumerStatefulWidget {
  const SendRollScreen({
    super.key,
    required this.roll,
    required this.stock,
    required this.types,
    this.rescan = false,
  });
  final RollSummary roll;
  final FilmStock stock;

  /// Services offered for this job.
  final List<ProcessingType> types;
  final bool rescan;
  @override
  ConsumerState<SendRollScreen> createState() => _State();
}

class _State extends ConsumerState<SendRollScreen> {
  final _key = GlobalKey<FormState>();

  /// Kept across retries, so saving again cannot create a second job.
  late final _jobId = newId();
  final _notes = TextEditingController();

  // A new job starts at home, where the work is done by the time it is recorded.
  String _labId = _self;
  late ProcessingType _type = widget.types.first;
  late Process _process = widget.stock.process;
  DateTime? _sent;
  DateTime? _scansExpected;
  DateTime? _negativesExpected;
  DateTime? _scansReceived = _today();
  DateTime? _negativesReturned = _today();

  /// Null until picked by hand: the job follows the lab's default scanner.
  List<ScanOrder>? _pickedOrders;
  String? _scanError;
  bool _busy = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _atHome => _labId == _self;

  /// Receipt dates are asked for work done at home.
  bool get _showReceipts => _atHome;
  bool get _needsScanners => _type.hasScans;

  /// A lab that develops the film returns the negatives.
  bool get _expectsNegatives => _type.developsFilm && !_atHome;
  bool get _recordsNegatives => _type.recordsNegativesReturned(atLab: !_atHome);

  String get _selfLabel => switch (_type) {
    ProcessingType.develop || ProcessingType.developScan => 'Self-develop',
    ProcessingType.scan => 'Self-scan (at home)',
    ProcessingType.print => 'Self-print (at home)',
  };

  /// A lab scans on its default scanner, or the Noritsu when it names none; at
  /// home on your own scanner, when you have one.
  List<ScanOrder> _defaultOrders(
    List<Lab> labs,
    List<ScannerDevice> scanners,
    List<ScannerKindOptions> kinds,
  ) {
    String? id;
    if (_atHome) {
      for (final s in scanners) {
        if (!s.builtIn) {
          id = s.id;
          break;
        }
      }
    } else {
      final lab = labs.where((l) => l.id == _labId).firstOrNull;
      id = lab != null && lab.scannerIds.isNotEmpty
          ? lab.defaultScannerId
          : kNoritsuHs1800;
    }
    final s = scanners.where((e) => e.id == id).firstOrNull;
    return s == null
        ? const []
        : [ScanOrder(scannerId: s.id, settings: startingSettings(kinds, s))];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labs = ref.watch(labsProvider).value ?? const <Lab>[];
    final scanners = ref.watch(scannersProvider);
    final kinds = ref.watch(scannerKindsProvider);
    // Orders start from the scanner's settings, so saving waits for both.
    final scansReady = scanners.hasValue && kinds.hasValue;
    final orders = !scansReady
        ? const <ScanOrder>[]
        : _pickedOrders ??
              _defaultOrders(labs, scanners.requireValue, kinds.requireValue);

    final String title, description, submit;
    if (widget.rescan) {
      title = 'Re-scan Roll';
      description = 'Scan the negatives again, at another lab or yourself. Earlier jobs and scans stay';
      submit = 'Add re-scan';
    } else if (_atHome) {
      title = 'Send to Lab';
      description = 'Record work done at home, with the days the negatives and scans were ready';
      submit = 'Record processing';
    } else {
      title = 'Send to Lab';
      description =
          'The roll becomes At Lab and shows under In Progress in the Lab tab';
      submit = 'Send to lab';
    }

    var section = 0;
    String next() => '${++section}'.padLeft(2, '0');

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: formAppBar(context, title),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                description,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            FormSectionHeader(number: next(), title: 'Roll'),
            _rollCard(cs),
            const SizedBox(height: 16),
            FormSectionHeader(
              number: next(),
              title: 'Lab & service',
              note: '* Required attributes',
            ),
            LabeledField(
              label: 'Lab *',
              child: SelectField(
                hint: 'Select a lab',
                value: _atHome
                    ? _selfLabel
                    : labs.where((l) => l.id == _labId).firstOrNull?.name,
                onTap: _pickLab,
              ),
            ),
            LabeledField(
              label: 'Service *',
              child: DropdownButtonFormField<ProcessingType>(
                initialValue: _type,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: formInputDecoration('', cs),
                borderRadius: kCorners,
                items: [
                  for (final t in widget.types)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() {
                  _type = v!;
                  _scanError = null;
                  if (_pickedOrders?.isEmpty ?? false) _pickedOrders = null;
                }),
              ),
            ),
            LabeledField(
              label: 'Process *',
              gapAfter: _process == widget.stock.process ? 16 : 6,
              child: DropdownButtonFormField<Process>(
                initialValue: _process,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: formInputDecoration('', cs),
                borderRadius: kCorners,
                items: [
                  for (final p in Process.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _process = v!),
              ),
            ),
            if (_process != widget.stock.process)
              FormNote(
                'Cross-processing: stock is ${widget.stock.process.label}',
              ),
            if (_needsScanners) ...[
              FormSectionHeader(
                number: next(),
                title: 'Scans',
                note: 'One order per scanner',
              ),
              if (scanners.hasError || kinds.hasError)
                Text('${scanners.error ?? kinds.error}')
              else if (!scansReady)
                const LinearProgressIndicator()
              else
                ScanOrderPicker(
                  orders: orders,
                  onChanged: (v) => setState(() {
                    _pickedOrders = v;
                    _scanError = null;
                  }),
                  scanners: scanners.requireValue,
                  kinds: kinds.requireValue,
                  offered:
                      labs
                          .where((l) => l.id == _labId)
                          .firstOrNull
                          ?.scannerIds ??
                      const [],
                  error: _scanError,
                ),
              const SizedBox(height: 16),
            ],
            FormSectionHeader(
              number: next(),
              title: 'Dates',
              note: 'Leave blank when not known yet',
            ),
            _date(
              _atHome ? 'Date started' : 'Date sent',
              _sent,
              (d) => _sent = d,
            ),
            if (_needsScanners && !_atHome)
              _date(
                'Scans expected back',
                _scansExpected,
                (d) => _scansExpected = d,
              ),
            if (_expectsNegatives)
              _date(
                'Negatives expected back',
                _negativesExpected,
                (d) => _negativesExpected = d,
              ),
            // Work done at home is finished when it is recorded.
            if (_showReceipts && _recordsNegatives)
              _date(
                !_atHome
                    ? 'Negatives received'
                    : _type == ProcessingType.print
                    ? 'Printed'
                    : 'Negatives developed',
                _negativesReturned,
                (d) => _negativesReturned = d,
              ),
            if (_showReceipts && _needsScanners)
              _date(
                _atHome ? 'Scanned' : 'Scans received',
                _scansReceived,
                (d) => _scansReceived = d,
              ),
            FormSectionHeader(number: next(), title: 'Notes'),
            LabeledField(
              label: 'Notes (optional)',
              gapAfter: 24,
              child: TextFormField(
                controller: _notes,
                decoration: formInputDecoration(
                  'Push/pull, scan resolution, tracking number…',
                  cs,
                ),
                minLines: 4,
                maxLines: 4,
              ),
            ),
            FormSaveBar(
              label: submit,
              busy: _busy,
              onPressed: _needsScanners && !scansReady
                  ? null
                  : () => _save(orders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rollCard(ColorScheme cs) {
    final r = widget.roll;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: kCorners,
        border: Border.all(color: cs.outlineVariant, width: kHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(r.stockLabel, style: headingStyle(fontSize: 18)),
          Text(
            [
              '${r.format}',
              '${r.exposures} exp',
              if (r.finishedAt != null) 'finished ${fmtDate(r.finishedAt)}',
            ].join(' · '),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _date(String label, DateTime? value, ValueChanged<DateTime?> set) =>
      LabeledField(
        label: '$label (optional)',
        child: SelectField(
          hint: 'Select a date',
          value: value == null ? null : fmtDate(value),
          icon: Icons.calendar_today,
          onTap: () async {
            final d = await pickDate(context, value);
            if (d != null) setState(() => set(d));
          },
          onClear: value == null ? null : () => setState(() => set(null)),
        ),
      );

  Future<void> _pickLab() async {
    final labs = await ref.read(labsProvider.future);
    final drafts = await draftsOf(ref, DraftKind.lab);
    if (!mounted) return;
    final names = {for (final l in labs) l.id: l};
    final id = await pickOne<String>(
      context,
      title: 'Lab',
      items: [_self, ...names.keys],
      label: (i) => i == _self ? _selfLabel : names[i]!.name,
      subtitle: (i) => names[i]?.address ?? '',
      footer: CreateFooter<String>(
        label: 'New lab',
        drafts: drafts,
        create: (c) async => (await editLab(c))?.id,
        resume: (c, d) async => (await editLab(c, d))?.id,
      ),
    );
    if (id != null) {
      setState(() {
        _labId = id;
        if (_pickedOrders?.isEmpty ?? false) _pickedOrders = null;
      });
    }
  }

  Future<void> _save(List<ScanOrder> orders) async {
    final valid = _key.currentState!.validate();
    final missing = _needsScanners && orders.isEmpty;
    setState(() => _scanError = missing ? 'Pick at least one scanner.' : null);
    if (!valid || missing) return;
    setState(() => _busy = true);
    final job = NewProcessing(
      id: _jobId,
      labId: _atHome ? null : _labId,
      type: _type,
      process: _process,
      sentAt: _sent,
      // Scans are only expected from a scanning job; negatives from a lab.
      scansExpectedAt: _needsScanners && !_atHome ? _scansExpected : null,
      negativesExpectedAt: _expectsNegatives ? _negativesExpected : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      scanOrders: _needsScanners ? orders : const [],
    );
    final ok = await guard(
      context,
      () => ref
          .read(processingActionsProvider)
          .send(
            widget.roll.id,
            job,
            scansReceivedAt: _showReceipts && _needsScanners
                ? _scansReceived
                : null,
            negativesReturnedAt: _showReceipts && _recordsNegatives
                ? _negativesReturned
                : null,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.closeScreen();
  }
}
