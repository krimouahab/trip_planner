import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One scheduled slot of the trip: a time range with an activity, a budget
/// (what you planned to spend) and a cost (what you actually spent).
class TimeBlock {
  final String id;
  DateTime start;
  DateTime end;
  String activity;
  String description;
  double budget;
  double cost;

  TimeBlock({
    String? id,
    required this.start,
    required this.end,
    required this.activity,
    this.description = '',
    this.budget = 0,
    this.cost = 0,
  }) : id = id ?? _uuid.v4();

  Duration get duration => end.difference(start);
  double get remaining => budget - cost;
  bool get overBudget => cost > budget;

  bool isActiveAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'activity': activity,
    'description': description,
    'budget': budget,
    'cost': cost,
  };

  factory TimeBlock.fromJson(Map<String, dynamic> j) => TimeBlock(
    id: j['id'] as String,
    start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String),
    activity: j['activity'] as String? ?? '',
    description: j['description'] as String? ?? '',
    budget: (j['budget'] as num?)?.toDouble() ?? 0,
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
  );
}

class Trip {
  final String id;
  String name;
  DateTime start;
  DateTime end;
  String currency;
  List<TimeBlock> blocks;

  Trip({
    String? id,
    required this.name,
    required this.start,
    required this.end,
    this.currency = '\$',
    List<TimeBlock>? blocks,
  }) : id = id ?? _uuid.v4(),
       blocks = blocks ?? [];

  Duration get duration => end.difference(start);

  List<TimeBlock> get sortedBlocks =>
      [...blocks]..sort((a, b) => a.start.compareTo(b.start));

  double get totalBudget => blocks.fold(0, (s, b) => s + b.budget);
  double get totalCost => blocks.fold(0, (s, b) => s + b.cost);
  double get remaining => totalBudget - totalCost;

  /// Minutes of the trip covered by at least one block (overlaps counted once,
  /// anything outside the trip window ignored).
  int get plannedMinutes {
    var total = 0;
    DateTime? cursor;
    for (final b in sortedBlocks) {
      var s = b.start.isBefore(start) ? start : b.start;
      final e = b.end.isAfter(end) ? end : b.end;
      if (cursor != null && s.isBefore(cursor)) s = cursor;
      if (e.isAfter(s)) {
        total += e.difference(s).inMinutes;
        cursor = e;
      }
    }
    return total;
  }

  int get freeMinutes => duration.inMinutes - plannedMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'currency': currency,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String),
    currency: j['currency'] as String? ?? '\$',
    blocks: (j['blocks'] as List? ?? [])
        .map((e) => TimeBlock.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A row in the dashboard table.
sealed class TableRowItem {}

class DayHeaderRow extends TableRowItem {
  final int dayNumber;
  final DateTime day;
  final double budget;
  final double cost;
  final Duration planned;
  DayHeaderRow(this.dayNumber, this.day, this.budget, this.cost, this.planned);
}

class BlockRow extends TableRowItem {
  final int index;
  final TimeBlock block;
  final bool overlaps;
  final bool outsideTrip;
  BlockRow(
    this.index,
    this.block, {
    this.overlaps = false,
    this.outsideTrip = false,
  });
}

class GapRow extends TableRowItem {
  final DateTime start;
  final DateTime end;
  GapRow(this.start, this.end);
  Duration get duration => end.difference(start);
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Builds the table: one header per day, the blocks that start that day, and
/// "free time" rows for every unplanned minute inside the trip window.
List<TableRowItem> buildTableRows(Trip trip, {bool includeGaps = true}) {
  final blocks = trip.sortedBlocks;
  final rows = <TableRowItem>[];

  var first = _dayOf(trip.start);
  var last = _dayOf(trip.end.subtract(const Duration(microseconds: 1)));
  if (blocks.isNotEmpty) {
    final fb = _dayOf(blocks.first.start);
    final lb = _dayOf(blocks.last.start);
    if (fb.isBefore(first)) first = fb;
    if (lb.isAfter(last)) last = lb;
  }

  DateTime? prevEnd;
  var index = 0;
  var dayNumber = 0;
  for (
    var d = first;
    !d.isAfter(last);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    dayNumber++;
    final next = DateTime(d.year, d.month, d.day + 1);
    final dayBlocks = blocks
        .where((b) => !b.start.isBefore(d) && b.start.isBefore(next))
        .toList();

    rows.add(
      DayHeaderRow(
        dayNumber,
        d,
        dayBlocks.fold(0.0, (s, b) => s + b.budget),
        dayBlocks.fold(0.0, (s, b) => s + b.cost),
        dayBlocks.fold(Duration.zero, (s, b) => s + b.duration),
      ),
    );

    // Free time is only measured inside the trip window and inside this day.
    final winStart = d.isBefore(trip.start) ? trip.start : d;
    final winEnd = next.isAfter(trip.end) ? trip.end : next;

    void addGap(DateTime from, DateTime to) {
      if (!includeGaps) return;
      final s = from.isBefore(winStart) ? winStart : from;
      final e = to.isAfter(winEnd) ? winEnd : to;
      if (e.difference(s).inMinutes >= 1) rows.add(GapRow(s, e));
    }

    for (final b in dayBlocks) {
      addGap(prevEnd ?? trip.start, b.start);
      index++;
      rows.add(
        BlockRow(
          index,
          b,
          overlaps: prevEnd != null && b.start.isBefore(prevEnd),
          outsideTrip: b.start.isBefore(trip.start) || b.end.isAfter(trip.end),
        ),
      );
      if (prevEnd == null || b.end.isAfter(prevEnd)) prevEnd = b.end;
    }
    addGap(prevEnd ?? trip.start, winEnd);
  }
  return rows;
}
