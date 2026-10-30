import 'package:flutter/material.dart';

import '../currency.dart';
import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import 'rates_screen.dart';
import 'trip_dashboard_screen.dart';
import 'trip_editor_screen.dart';

/// Home: the list of all trips.
class TripsScreen extends StatelessWidget {
  final TripStore store;
  const TripsScreen({super.key, required this.store});

  void _open(BuildContext context, Trip trip) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TripDashboardScreen(store: store, tripId: trip.id),
    ),
  );

  Future<void> _create(BuildContext context) async {
    final trip = await Navigator.push<Trip>(
      context,
      MaterialPageRoute(builder: (_) => TripEditorScreen(store: store)),
    );
    if (trip != null && context.mounted) _open(context, trip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My trips'),
        actions: [
          IconButton(
            tooltip: 'Exchange rates',
            icon: const Icon(Icons.currency_exchange),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RatesScreen(store: store)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New trip'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = store.trips;
          if (trips.isEmpty) return _Empty(store: store, onOpen: _open);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: trips.length,
            itemBuilder: (context, i) => _TripCard(
              trip: trips[i],
              rates: store.rates,
              onTap: () => _open(context, trips[i]),
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final TripStore store;
  final void Function(BuildContext, Trip) onOpen;
  const _Empty({required this.store, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No trips yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Create a trip with its start and end, then plan every block of time with its budget and cost.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final trip = await store.addSampleTrip();
                if (context.mounted) onOpen(context, trip);
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Try a sample trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final Rates rates;
  final VoidCallback onTap;
  const _TripCard({
    required this.trip,
    required this.rates,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = trip.duration.inMinutes;
    final planned = total <= 0 ? 0.0 : trip.plannedMinutes / total;
    final budget = trip.totalBudget(rates);
    final cost = trip.totalCost(rates);
    final over = cost.value > budget.value;
    final now = DateTime.now();
    final status = now.isBefore(trip.start)
        ? 'Starts in ${fmt.duration(trip.start.difference(now))}'
        : now.isBefore(trip.end)
        ? 'Happening now'
        : 'Finished';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(status, style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${fmt.dateTime(trip.start)}  →  ${fmt.dateTime(trip.end)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Mini('Budget', fmt.money(budget.value, homeCurrency)),
                  _Mini(
                    'Spent',
                    fmt.money(cost.value, homeCurrency),
                    color: over ? theme.colorScheme.error : null,
                  ),
                  _Mini('Blocks', '${trip.blocks.length}'),
                ],
              ),
              if (!budget.complete || !cost.complete)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Missing rate for ${{...budget.missingCodes, ...cost.missingCodes}.join(', ')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: planned, minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text(
                '${(planned * 100).round()}% of the time planned · '
                '${fmt.duration(Duration(minutes: trip.freeMinutes))} free',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Mini(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
