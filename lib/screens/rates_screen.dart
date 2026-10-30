import 'package:flutter/material.dart';

import '../currency.dart';
import '../store.dart';
import '../widgets/currency_picker.dart';

/// Settings: the rate between each currency and the DZD.
class RatesScreen extends StatelessWidget {
  final TripStore store;
  const RatesScreen({super.key, required this.store});

  Future<void> _remove(BuildContext context, String code) async {
    if (store.isCurrencyInUse(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$code is used by a trip, so it stays.')),
      );
      return;
    }
    await store.removeCurrency(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exchange rates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRateDialog(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Add currency'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final cs = Theme.of(context).colorScheme;
          final codes = store.rates.codes
              .where((c) => c != homeCurrency)
              .toList();
          final missing = codes.where((c) => !store.rates.hasRate(c)).length;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'All budgets and costs are converted to DZD using these rates, '
                  'in every row and on the dashboard. Tap a currency to change its rate.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (missing > 0)
                Card(
                  color: cs.errorContainer,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber,
                      color: cs.onErrorContainer,
                    ),
                    title: Text(
                      '$missing currenc${missing == 1 ? 'y has' : 'ies have'} no rate yet',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    subtitle: Text(
                      'Their amounts are left out of the DZD totals.',
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ),
              ListTile(
                leading: const CircleAvatar(child: Text('DA')),
                title: const Text(homeCurrency),
                subtitle: const Text(
                  'Base currency, everything is converted to it',
                ),
              ),
              const Divider(height: 1),
              if (codes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No other currencies yet. Add one, or pick it while editing a time block.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final code in codes)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: store.rates.hasRate(code)
                        ? null
                        : cs.errorContainer,
                    child: Text(
                      code.substring(0, 2),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  title: Text(code),
                  subtitle: Text(
                    rateLabel(store.rates, code),
                    style: TextStyle(
                      color: store.rates.hasRate(code) ? null : cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => showRateDialog(context, store, code: code),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(context, code),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
