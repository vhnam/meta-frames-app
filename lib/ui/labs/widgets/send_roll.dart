import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/lab_requests.dart';
import '../../../domain/models/models.dart';
import '../../../domain/utils.dart';
import '../../../providers.dart';
import '../../../routing/navigation.dart';
import '../../core/theme.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_kit.dart';
import '../../rolls/widgets/roll_form_kit.dart';
import '../view_models/processing_actions.dart';
import 'lab_dialog.dart';
import 'scan_order_picker.dart';

/// Stand-in for working at home: the API takes no lab id then.
const _self = 'self';

/// M-27 send a roll for processing, or record work done at home; M-31 scan a
/// processed roll again; or edit a [job] already recorded. Follows the
/// dashboard's Send to Lab dialog.
class SendRollScreen extends ConsumerStatefulWidget {
  const SendRollScreen({
    super.key,
    required this.roll,
    required this.stock,
    required this.types,
    this.rescan = false,
    this.job,
  });
  final RollSummary roll;
  final FilmStock stock;

  /// Services offered for this job.
  final List<ProcessingType> types;
  final bool rescan;

  /// Edit this job instead of sending the roll. Its lab and service stay fixed:
  /// the server refuses a change of service.
  final Processing? job;
  @override
  ConsumerState<SendRollScreen> createState() => _State();
}

class _State extends ConsumerState<SendRollScreen> {
  final _key = GlobalKey<FormState>();

  /// Kept across retries, so saving again cannot create a second job.
  late final _jobId = widget.job?.id ?? newId();
  late final _price = TextEditingController(
    text: widget.job?.price?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.job?.notes ?? '');

  // A new job starts at home, where the work is done by the time it is recorded.
  late String _labId = widget.job?.labId ?? _self;
  late ProcessingType _type = widget.job?.type ?? widget.types.first;
  late Process _process = widget.job?.process ?? widget.stock.process;
  late DateTime? _sent = widget.job?.sentAt;
  late DateTime? _scansExpected = widget.job?.scansExpectedAt;
  late DateTime? _negativesExpected = widget.job?.negativesExpectedAt;
  late DateTime? _scansReceived = widget.job == null
      ? _today()
      : widget.job!.scansReceivedAt;
  late DateTime? _negativesReturned = widget.job == null
      ? _today()
      : widget.job!.negativesReturnedAt;

  /// Null until picked by hand: the job follows the lab's default scanner.
  late List<ScanOrder>? _pickedOrders = _ordersOfJob();
  String? _scanError;
  bool _busy = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<JobScanOrder> get _jobOrders => widget.job?.scanOrders ?? const [];

  /// Null for a job without scanners, so it gets the default if it needs one.
  List<ScanOrder>? _ordersOfJob() => _jobOrders.isEmpty
      ? null
      : [
          for (final o in _jobOrders)
            ScanOrder(scannerId: o.scannerId, settings: o.settings),
        ];

  bool get _atHome => _labId == _self;
  bool get _editing => widget.job != null;

  /// Receipt dates are asked for when editing a job, and for work done at home.
  bool get _showReceipts => _editing || _atHome;
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
    if (_editing) {
      title = 'Edit Processing Job';
      description = 'Update the process, price, scanners and dates of this job';
      submit = 'Save changes';
    } else if (widget.rescan) {
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
              label: _editing ? 'Lab (locked)' : 'Lab *',
              child: SelectField(
                hint: 'Select a lab',
                value: _atHome
                    ? _selfLabel
                    : labs.where((l) => l.id == _labId).firstOrNull?.name ??
                          widget.job?.labName,
                onTap: _editing ? null : _pickLab,
              ),
            ),
            if (_editing) ...[
              LabeledField(
                label: 'Service (locked)',
                gapAfter: 6,
                child: SelectField(
                  hint: 'Service',
                  value: _type.label,
                  onTap: null,
                ),
              ),
              const FormNote(
                'The lab and service cannot be changed once the job is recorded.',
              ),
            ] else
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
            LabeledField(
              label: 'Price (optional)',
              child: TextFormField(
                controller: _price,
                decoration: formInputDecoration(
                  'e.g. 280000',
                  cs,
                ).copyWith(suffixText: '₫'),
                keyboardType: TextInputType.number,
                validator: validPrice,
              ),
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
                  locked: {
                    for (final o in _jobOrders)
                      if (o.scanCount > 0) o.scannerId,
                  },
                  names: {
                    for (final o in _jobOrders) o.scannerId: o.scannerName,
                  },
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
              // Without a date the server would move the job to today.
              required: _editing,
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
            // Work done at home is finished when it is recorded. The API cannot
            // clear a receipt date once it is recorded.
            if (_showReceipts && _recordsNegatives)
              _date(
                !_atHome
                    ? 'Negatives received'
                    : _type == ProcessingType.print
                    ? 'Printed'
                    : 'Negatives developed',
                _negativesReturned,
                (d) => _negativesReturned = d,
                clearable: widget.job?.negativesReturnedAt == null,
              ),
            if (_showReceipts && _needsScanners)
              _date(
                _atHome ? 'Scanned' : 'Scans received',
                _scansReceived,
                (d) => _scansReceived = d,
                clearable: widget.job?.scansReceivedAt == null,
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
            // The server refuses to delete a job with imported scans.
            if (_editing && !widget.job!.hasScans) ...[
              const SizedBox(height: 20),
              CardList(
                children: [
                  DetailActionRow(
                    label: 'Delete job',
                    color: cs.error,
                    onTap: _delete,
                  ),
                ],
              ),
            ],
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

  Widget _date(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> set, {
    bool required = false,
    bool clearable = true,
  }) => LabeledField(
    label: required ? '$label *' : '$label (optional)',
    child: SelectField(
      hint: 'Select a date',
      value: value == null ? null : fmtDate(value),
      icon: Icons.calendar_today,
      onTap: () async {
        final d = await pickDate(context, value);
        if (d != null) setState(() => set(d));
      },
      onClear: value == null || required || !clearable
          ? null
          : () => setState(() => set(null)),
    ),
  );

  Future<void> _pickLab() async {
    final labs = await ref.read(labsProvider.future);
    if (!mounted) return;
    final names = {for (final l in labs) l.id: l};
    final id = await pickOne<String>(
      context,
      title: 'Lab',
      items: [_self, ...names.keys],
      label: (i) => i == _self ? _selfLabel : names[i]!.name,
      subtitle: (i) => names[i]?.address ?? '',
      footer: Builder(
        builder: (c) => Padding(
          padding: const EdgeInsets.all(8),
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New lab'),
            onPressed: () async {
              final l = await editLab(c);
              if (l != null && c.mounted) Navigator.pop(c, l.id);
            },
          ),
        ),
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
      price: _price.text.isEmpty ? null : int.parse(_price.text),
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
                ? _ifChanged(_scansReceived, widget.job?.scansReceivedAt)
                : null,
            negativesReturnedAt: _showReceipts && _recordsNegatives
                ? _ifChanged(
                    _negativesReturned,
                    widget.job?.negativesReturnedAt,
                  )
                : null,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.closeScreen();
  }

  /// Tells the screen that opened this form, whose job is gone. Edit Roll stays
  /// open, because the roll still exists.
  Future<void> _delete() async {
    if (_busy) return;
    if (!await confirm(
      context,
      'Delete job?',
      'The roll goes back to the status its other jobs give it.',
      ok: 'Delete',
    )) {
      return;
    }
    if (!mounted) return;
    final job = widget.job!;
    final ok = await guard(
      context,
      () => ref.read(processingActionsProvider).delete(job.id, job.rollId),
    );
    if (ok && mounted) context.closeScreen(true);
  }

  /// A receipt date already on the job is not sent again.
  DateTime? _ifChanged(DateTime? date, DateTime? recorded) =>
      date != null && recorded != null && ymd(date) == ymd(recorded)
      ? null
      : date;
}
