import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_planner/currency.dart';
import 'package:trip_planner/main.dart';
import 'package:trip_planner/models.dart';
import 'package:trip_planner/store.dart';

void main() {
  group('buildTableRows', () {
    final trip = Trip(
      name: 'T',
      start: DateTime(2026, 11, 1, 8),
      end: DateTime(2026, 11, 2, 12),
      blocks: [
        TimeBlock(
          start: DateTime(2026, 11, 1, 9),
          end: DateTime(2026, 11, 1, 10),
          activity: 'A',
          budget: 10,
          cost: 12,
        ),
        TimeBlock(
          start: DateTime(2026, 11, 1, 9, 30),
          end: DateTime(2026, 11, 1, 11),
          activity: 'B',
          budget: 5,
        ),
        TimeBlock(
          start: DateTime(2026, 11, 1, 22),
          end: DateTime(2026, 11, 2, 7),
          activity: 'Sleep',
        ),
      ],
    );

    test('days, gaps and overlaps', () {
      final rows = buildTableRows(trip);
      final days = rows.whereType<DayHeaderRow>().toList();
      expect(days.length, 2);
      final blocks = rows.whereType<BlockRow>().toList();
      expect(blocks.map((b) => b.block.activity), ['A', 'B', 'Sleep']);
      expect(blocks[1].overlaps, isTrue);
      final gaps = rows.whereType<GapRow>().toList();
      // 08-09, 11-22, then day 2: 07-12
      expect(gaps.map((g) => g.duration.inMinutes), [60, 660, 300]);
    });

    test('totals', () {
      final rates = Rates();
      expect(trip.totalBudget(rates).value, 15);
      expect(trip.totalCost(rates).value, 12);
      // 09-11 (union) + 22-07 = 2h + 9h
      expect(trip.plannedMinutes, 11 * 60);
      expect(trip.freeMinutes, 28 * 60 - 11 * 60);
    });
  });

  group('currencies', () {
    final block = TimeBlock(
      start: DateTime(2026, 11, 1, 9),
      end: DateTime(2026, 11, 1, 10),
      activity: 'Museum',
      budget: 20,
      budgetCurrency: 'EUR',
      cost: 3000,
      costCurrency: 'DZD',
    );

    test('converts each amount to DZD with its own rate', () {
      final rates = Rates({'EUR': 150});
      expect(block.budgetHome(rates), 3000);
      expect(block.costHome(rates), 3000);
      expect(block.remainingHome(rates), 0);
      expect(block.overBudget(rates), isFalse);
      expect(block.overBudget(Rates({'EUR': 100})), isTrue);
    });

    test('missing rates are counted, not guessed', () {
      final trip = Trip(
        name: 'T',
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 2),
        blocks: [block],
      );
      final rates = Rates({'EUR': null});
      final budget = trip.totalBudget(rates);
      expect(budget.value, 0);
      expect(budget.missing, 1);
      expect(budget.missingCodes, {'EUR'});
      expect(trip.totalCost(rates).complete, isTrue);
      expect(block.remainingHome(rates), isNull);
      expect(trip.totalsByCurrency()['EUR'], (20.0, 0.0));
    });

    test('old trips saved with symbols are migrated to codes', () {
      final t = Trip.fromJson({
        'id': 'x',
        'name': 'Old',
        'start': '2026-11-01T08:00:00.000',
        'end': '2026-11-02T08:00:00.000',
        'currency': '€',
        'blocks': [
          {
            'id': 'b',
            'start': '2026-11-01T09:00:00.000',
            'end': '2026-11-01T10:00:00.000',
            'activity': 'A',
            'budget': 5,
            'cost': 4,
          },
        ],
      });
      expect(t.currency, 'EUR');
      expect(t.blocks.single.budgetCurrency, 'EUR');
      expect(t.blocks.single.costCurrency, 'EUR');
    });
  });

  testWidgets('sample trip opens the dashboard table', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = TripStore();
    await store.load();
    await tester.pumpWidget(TripPlannerApp(store: store));
    expect(find.text('No trips yet'), findsOneWidget);
    await tester.tap(find.text('Try a sample trip'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Flight Algiers → Paris'), findsOneWidget);
    expect(find.textContaining('No rate for EUR'), findsOneWidget);
    expect(find.textContaining('DAY 1'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
