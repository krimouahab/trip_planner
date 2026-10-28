import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      expect(trip.totalBudget, 15);
      expect(trip.totalCost, 12);
      // 09-11 (union) + 22-07 = 2h + 9h
      expect(trip.plannedMinutes, 11 * 60);
      expect(trip.freeMinutes, 28 * 60 - 11 * 60);
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
    expect(find.text('Train to Paris'), findsOneWidget);
    expect(find.textContaining('DAY 1'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
