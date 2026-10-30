import 'package:flutter/material.dart';

import '../currency.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/currency_picker.dart';
import '../widgets/date_time_field.dart';

/// Create a trip or change its name, currency, start and end.
class TripEditorScreen extends StatefulWidget {
  final TripStore store;
  final Trip? trip;

  const TripEditorScreen({super.key, required this.store, this.trip});

  @override
  State<TripEditorScreen> createState() => _TripEditorScreenState();
}

class _TripEditorScreenState extends State<TripEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _currency;
  late DateTime _start;
  late DateTime _end;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    final now = DateTime.now();
    _name = TextEditingController(text: t?.name ?? '');
    _currency = t?.currency ?? homeCurrency;
    _start = t?.start ?? DateTime(now.year, now.month, now.day + 1, 8);
    _end = t?.end ?? DateTime(now.year, now.month, now.day + 3, 20);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(
      () => _rangeError = _end.isAfter(_start)
          ? null
          : 'End must be after the start',
    );
    if (!_form.currentState!.validate() || _rangeError != null) return;

    final existing = widget.trip;
    final trip = existing ?? Trip(name: '', start: _start, end: _end);
    trip
      ..name = _name.text.trim()
      ..currency = _currency
      ..start = _start
      ..end = _end;
    await widget.store.upsertTrip(trip);
    if (mounted) Navigator.pop(context, trip);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.trip != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit trip' : 'New trip'),
        actions: [TextButton(onPressed: _save, child: const Text('SAVE'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Trip name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.luggage),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Give the trip a name'
                  : null,
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Trip begins',
              value: _start,
              onChanged: (v) => setState(() {
                final length = _end.difference(_start);
                _start = v;
                if (!_end.isAfter(_start)) _end = _start.add(length);
              }),
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Trip ends',
              value: _end,
              firstDate: _start,
              errorText: _rangeError,
              onChanged: (v) => setState(() => _end = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Default currency for new blocks'),
                      Text(
                        'Each budget and cost can still use any currency. '
                        'Totals are always shown in DZD.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CurrencyButton(
                  store: widget.store,
                  code: _currency,
                  onChanged: (c) => setState(() => _currency = c),
                ),
              ],
            ),
            if (editing && widget.trip!.blocks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Time blocks outside the new dates are kept and marked with a warning.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
