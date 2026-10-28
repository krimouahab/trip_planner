import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../widgets/date_time_field.dart';
import '../widgets/linkified_text.dart';

/// Add or edit one time block of a trip.
class BlockEditorScreen extends StatefulWidget {
  final TripStore store;
  final Trip trip;
  final TimeBlock? block;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const BlockEditorScreen({
    super.key,
    required this.store,
    required this.trip,
    this.block,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends State<BlockEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _activity;
  late final TextEditingController _budget;
  late final TextEditingController _cost;
  late final TextEditingController _description;
  late DateTime _start;
  late DateTime _end;
  String? _startError;
  String? _endError;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    final trip = widget.trip;
    _activity = TextEditingController(text: b?.activity ?? '');
    _budget = TextEditingController(text: _num(b?.budget));
    _cost = TextEditingController(text: _num(b?.cost));
    _description = TextEditingController(text: b?.description ?? '');
    _description.addListener(() => setState(() {}));

    if (b != null) {
      _start = b.start;
      _end = b.end;
    } else {
      // Default: start where the last block ends, last one hour.
      final blocks = trip.sortedBlocks;
      var start =
          widget.initialStart ??
          (blocks.isEmpty
              ? trip.start
              : blocks
                    .map((b) => b.end)
                    .reduce((a, c) => a.isAfter(c) ? a : c));
      if (!start.isBefore(trip.end)) {
        start = trip.end.subtract(const Duration(hours: 1));
      }
      _start = start;
      var end = widget.initialEnd ?? start.add(const Duration(hours: 1));
      if (end.isAfter(trip.end)) end = trip.end;
      _end = end;
    }
  }

  static String _num(double? v) {
    if (v == null || v == 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static double _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    _activity.dispose();
    _budget.dispose();
    _cost.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setDuration(Duration d) => setState(() {
    _end = _start.add(d);
    _endError = null;
  });

  bool _validateTimes() {
    final trip = widget.trip;
    _startError = _start.isBefore(trip.start)
        ? 'Before the trip starts (${fmt.dateTime(trip.start)})'
        : null;
    _endError = !_end.isAfter(_start)
        ? 'End must be after the start'
        : _end.isAfter(trip.end)
        ? 'After the trip ends (${fmt.dateTime(trip.end)})'
        : null;
    setState(() {});
    return _startError == null && _endError == null;
  }

  Future<void> _save() async {
    final formOk = _form.currentState!.validate();
    if (!_validateTimes() || !formOk) return;
    final block = TimeBlock(
      id: widget.block?.id,
      start: _start,
      end: _end,
      activity: _activity.text.trim(),
      description: _description.text.trim(),
      budget: _parse(_budget.text),
      cost: _parse(_cost.text),
    );
    await widget.store.upsertBlock(widget.trip, block);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this block?'),
        content: Text(widget.block!.activity),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.deleteBlock(widget.trip, widget.block!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final theme = Theme.of(context);
    final moneyFormatter = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];
    final budget = _parse(_budget.text);
    final cost = _parse(_cost.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.block == null ? 'New time block' : 'Edit time block',
        ),
        actions: [
          if (widget.block != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _activity,
              autofocus: widget.block == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Activity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_activity_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'What are you doing?'
                  : null,
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Start',
              value: _start,
              firstDate: trip.start,
              lastDate: trip.end,
              errorText: _startError,
              onChanged: (v) => setState(() {
                final length = _end.difference(_start);
                _start = v;
                _end = v.add(
                  length.isNegative ? const Duration(hours: 1) : length,
                );
                _startError = null;
                _endError = null;
              }),
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'End',
              value: _end,
              firstDate: _start,
              lastDate: trip.end,
              errorText: _endError,
              onChanged: (v) => setState(() {
                _end = v;
                _endError = null;
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Duration: ${fmt.duration(_end.difference(_start))}',
                  style: theme.textTheme.bodyMedium,
                ),
                for (final m in const [15, 30, 60, 90, 120, 180])
                  ActionChip(
                    label: Text(
                      m < 60 ? '${m}m' : fmt.duration(Duration(minutes: m)),
                    ),
                    onPressed: () => _setDuration(Duration(minutes: m)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _budget,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: moneyFormatter,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Budget',
                      prefixText: '${trip.currency} ',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: moneyFormatter,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Actual cost',
                      prefixText: '${trip.currency} ',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (budget > 0 || cost > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  cost > budget
                      ? 'Over budget by ${fmt.money(cost - budget, trip.currency)}'
                      : 'Remaining: ${fmt.money(budget - cost, trip.currency)}',
                  style: TextStyle(
                    color: cost > budget
                        ? theme.colorScheme.error
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Notes, addresses, booking refs…\nLinks like https://… become clickable',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_description.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Preview', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LinkifiedText(_description.text.trim()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
