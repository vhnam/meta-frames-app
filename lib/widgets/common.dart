import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../features/more/settings_screen.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _vndFmt = NumberFormat.decimalPattern('en_US');

String fmtDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d);
String fmtVnd(int? v) => v == null ? '—' : '${_vndFmt.format(v)} ₫';

void toast(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg)));

/// Run [action]. On failure show a toast; if the server cannot be reached,
/// show an alert that offers Retry. Returns true on success.
Future<bool> guard(BuildContext context, Future<void> Function() action) async {
  while (true) {
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      if (!e.isNetwork || !context.mounted) {
        if (context.mounted) toast(context, e.message);
        return false;
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.cloud_off),
          title: const Text('Cannot connect'),
          content: Text(
            '${e.message}\nCheck that the server is running and the URL is correct.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Text('Settings'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      if (retry != true || !context.mounted) return false;
    } catch (e) {
      if (context.mounted) toast(context, e.toString());
      return false;
    }
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String ok = 'Confirm',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial) =>
    showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );

/// Renders an [AsyncValue] with loading, error + retry and pull to refresh.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    required this.onRefresh,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: true,
    data: (d) => RefreshIndicator(onRefresh: onRefresh, child: builder(d)),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => _ErrorView(error: e, onRetry: onRefresh),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final network = error is ApiException && (error as ApiException).isNetwork;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              network ? Icons.cloud_off : Icons.error_outline,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 12),
            Text(
              network ? 'Cannot connect to server' : 'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                if (network)
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: const Text('Server settings'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      ),
    ],
  );
}

/// Header shared by the Home, Gear and Rolls tabs: mono kicker, heading title,
/// optional trailing actions, then the sprocket rule.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.trailing,
  });
  final String kicker, title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, trailing == null ? 16 : 8, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kicker.toUpperCase(),
                      style: monoStyle(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: headingStyle(
                        fontSize: 28,
                        letterSpacing: -0.6,
                        height: 1.3,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const SprocketRow(),
      ],
    );
  }
}

/// 35mm film edge: a row of sprocket holes used as a rule under headers.
class SprocketRow extends StatelessWidget {
  const SprocketRow({super.key, this.height = 10});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _SprocketPainter(Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

class _SprocketPainter extends CustomPainter {
  _SprocketPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const w = 7.0, step = 16.0;
    final h = size.height * 0.6;
    final top = (size.height - h) / 2;
    for (var x = 0.0; x + w <= size.width; x += step) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, w, h),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SprocketPainter old) => old.color != color;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: monoStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        Expanded(child: Text(value == null || value!.isEmpty ? '—' : value!)),
      ],
    ),
  );
}

/// Colour for a roll status, readable on both light and dark surfaces.
Color statusTone(BuildContext context, RollStatus status) {
  final cs = Theme.of(context).colorScheme;
  final dark = cs.brightness == Brightness.dark;
  Color tone(MaterialColor c) => dark ? c.shade300 : c.shade800;
  return switch (status) {
    RollStatus.inStock => cs.onSurfaceVariant,
    RollStatus.inCamera => cs.onPrimaryContainer,
    RollStatus.doneShooting => cs.tertiary,
    RollStatus.atLab => tone(Colors.orange),
    RollStatus.developed => tone(Colors.teal),
    RollStatus.scanned => tone(Colors.green),
  };
}

/// Small bordered stamp: mono uppercase text on a faint tint of [color].
class StampBadge extends StatelessWidget {
  const StampBadge(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(kStampRadius),
      border: Border.all(color: color.withValues(alpha: 0.6), width: kHairline),
    ),
    child: Text(
      text.toUpperCase(),
      style: monoStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: color,
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final RollStatus status;
  @override
  Widget build(BuildContext context) =>
      StampBadge(status.label, color: statusTone(context, status));
}

/// Film process stamp (C-41, E-6, ECN-2, B&W).
class ProcessBadge extends StatelessWidget {
  const ProcessBadge(this.process, {super.key});
  final Process process;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = switch (process) {
      Process.c41 => dark ? const Color(0xFFFFB1C8) : const Color(0xFF8A2D4E),
      Process.e6 => dark ? const Color(0xFFFFE08A) : const Color(0xFF6B5200),
      Process.ecn2 => dark ? const Color(0xFF9CCBFF) : const Color(0xFF1D4F7C),
      Process.bw => dark ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46),
    };
    return StampBadge(process == Process.bw ? 'B&W' : process.wire, color: fg);
  }
}

class WarningBanner extends StatelessWidget {
  const WarningBanner(this.messages, {super.key});
  final List<String> messages;
  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: kCorners,
        side: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: kHairline,
        ),
      ),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in messages)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Date text-field that opens a picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final d = await pickDate(context, value);
      if (d != null) onChanged(d);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: clearable && value != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today, size: 18),
      ),
      child: Text(fmtDate(value)),
    ),
  );
}

/// Generic searchable single-choice bottom sheet.
Future<T?> pickOne<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? subtitle,
  Widget? footer,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => _PickSheet<T>(
    title: title,
    items: items,
    label: label,
    subtitle: subtitle,
    footer: footer,
  ),
);

class _PickSheet<T> extends StatefulWidget {
  const _PickSheet({
    required this.title,
    required this.items,
    required this.label,
    this.subtitle,
    this.footer,
  });
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? subtitle;
  final Widget? footer;
  @override
  State<_PickSheet<T>> createState() => _PickSheetState<T>();
}

class _PickSheetState<T> extends State<_PickSheet<T>> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final shown = widget.items
        .where((e) => widget.label(e).toLowerCase().contains(q.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => q = v),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const Center(child: Text('Nothing found'))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (c, i) => ListTile(
                        title: Text(widget.label(shown[i])),
                        subtitle: widget.subtitle == null
                            ? null
                            : Text(widget.subtitle!(shown[i])),
                        onTap: () => Navigator.pop(c, shown[i]),
                      ),
                    ),
            ),
            ?widget.footer,
          ],
        ),
      ),
    );
  }
}

/// Tappable form field showing a picked value.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: onClear != null && value != null
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : const Icon(Icons.arrow_drop_down),
      ),
      child: Text(value ?? 'Select'),
    ),
  );
}

const gap = SizedBox(height: 16);

InputDecoration deco(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  border: const OutlineInputBorder(),
);
