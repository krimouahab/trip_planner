import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../currency.dart';
import '../format.dart' as fmt;
import '../store.dart';

double? _parseRate(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  return v == null || v <= 0 ? null : v;
}

/// Add a currency or change its rate to DZD. Returns the code, or null if
/// cancelled.
Future<String?> showRateDialog(
  BuildContext context,
  TripStore store, {
  String? code,
}) {
  final isNew = code == null;
  final codeCtrl = TextEditingController(text: code ?? '');
  final current = code == null ? null : store.rates.rate(code);
  final rateCtrl = TextEditingController(
    text: current == null ? '' : fmt.rate(current).replaceAll(',', ''),
  );
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        final typed = codeCtrl.text.trim().toUpperCase();
        return AlertDialog(
          title: Text(isNew ? 'Add currency' : 'Rate for $code'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNew) ...[
                  TextFormField(
                    controller: codeCtrl,
                    autofocus: true,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                      TextInputFormatter.withFunction(
                        (_, v) => v.copyWith(text: v.text.toUpperCase()),
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Currency code',
                      hintText: 'EUR, USD, TND, MAD…',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim().toUpperCase();
                      if (!isCurrencyCode(s)) return 'Use a 3-letter code';
                      if (s == homeCurrency) return 'DZD is the base currency';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: rateCtrl,
                  autofocus: !isNew,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText:
                        '1 ${isNew ? (typed.isEmpty ? '…' : typed) : code} = ? DZD',
                    hintText: 'Leave empty to set it later',
                    suffixText: 'DZD',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    return _parseRate(v!) == null
                        ? 'Enter a number above 0'
                        : null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final finalCode = isNew ? typed : code;
                await store.setRate(finalCode, _parseRate(rateCtrl.text));
                if (c.mounted) Navigator.pop(c, finalCode);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

/// Text such as "1 EUR = 250 DZD", or "No rate yet".
String rateLabel(Rates rates, String code) {
  if (code == homeCurrency) return 'Base currency';
  final r = rates.rate(code);
  return r == null ? 'No rate yet' : '1 $code = ${fmt.rate(r)} DZD';
}

/// Lets the user pick one of their currencies, or add a new one.
Future<String?> pickCurrency(
  BuildContext context,
  TripStore store,
  String selected,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final codes = store.rates.codes;
      final cs = Theme.of(c).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(c).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Currency',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final code in codes)
                ListTile(
                  leading: Icon(
                    code == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: code == selected ? cs.primary : null,
                  ),
                  title: Text(code),
                  subtitle: Text(
                    rateLabel(store.rates, code),
                    style: TextStyle(
                      color: store.rates.hasRate(code) ? null : cs.error,
                    ),
                  ),
                  onTap: () => Navigator.pop(c, code),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add currency'),
                onTap: () async {
                  final code = await showRateDialog(c, store);
                  if (code != null && c.mounted) Navigator.pop(c, code);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A small button showing a currency code; tap to change it.
class CurrencyButton extends StatelessWidget {
  final TripStore store;
  final String code;
  final ValueChanged<String> onChanged;

  const CurrencyButton({
    super.key,
    required this.store,
    required this.code,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final missing = !store.rates.hasRate(code);
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 56),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: missing ? cs.error : cs.outline),
      ),
      onPressed: () async {
        final picked = await pickCurrency(context, store, code);
        if (picked != null) onChanged(picked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
