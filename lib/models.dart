import 'package:uuid/uuid.dart';

import 'currency.dart';

const _uuid = Uuid();

/// One scheduled slot of the trip: a time range with an activity, a budget
/// (what you planned to spend) and a cost (what you actually spent). Budget
/// and cost each carry their own currency code.
class TimeBlock {
  final String id;
  DateTime start;
  DateTime end;
  String activity;
  String description;
  double budget;
  String budgetCurrency;
  double cost;
  String costCurrency;

  TimeBlock({
    String? id,
    required this.start,
    required this.end,
    required this.activity,
    this.description = '',
    this.budget = 0,
    this.budgetCurrency = homeCurrency,
    this.cost = 0,
    this.costCurrency = homeCurrency,
  }) : id = id ?? _uuid.v4();

  Duration get duration => end.difference(start);

  double? budgetHome(Rates r) => r.toHome(budget, budgetCurrency);
  double? costHome(Rates r) => r.toHome(cost, costCurrency);

  /// Budget minus cost in DZD, or null if either has no rate.
  double? remainingHome(Rates r) {
    final b = budgetHome(r);
    final c = costHome(r);
    return b == null || c == null ? null : b - c;
  }

  bool overBudget(Rates r) {
    if (budgetCurrency == costCurrency) return cost > budget;
    final left = remainingHome(r);
    return left != null && left < 0;
  }

  bool isActiveAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'activity': activity,
    'description': description,
    'budget': budget,
    'budgetCurrency': budgetCurrency,
    'cost': cost,
    'costCurrency': costCurrency,
  };

  factory TimeBlock.fromJson(
    Map<String, dynamic> j, {
    String defaultCurrency = homeCurrency,
  }) => TimeBlock(
    id: j['id'] as String,
    start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String),
    activity: j['activity'] as String? ?? '',
    description: j['description'] as String? ?? '',
    budget: (j['budget'] as num?)?.toDouble() ?? 0,
    budgetCurrency: normalizeCurrency(
      j['budgetCurrency'] as String? ?? defaultCurrency,
    ),
    cost: (j['cost'] as num?)?.toDouble() ?? 0,
    costCurrency: normalizeCurrency(
      j['costCurrency'] as String? ?? defaultCurrency,
    ),
  );
}

class Trip {
  final String id;
  String name;
  DateTime start;
  DateTime end;

  /// Currency code pre-selected for new blocks.
  String currency;
  List<TimeBlock> blocks;

  Trip({
    String? id,
    required this.name,
    required this.start,
    required this.end,
    this.currency = homeCurrency,
    List<TimeBlock>? blocks,
  }) : id = id ?? _uuid.v4(),
       blocks = blocks ?? [];

  Duration get duration => end.difference(start);

  List<TimeBlock> get sortedBlocks =>
      [...blocks]..sort((a, b) => a.start.compareTo(b.start));

  HomeTotal totalBudget(Rates r) => budgetOf(blocks, r);
  HomeTotal totalCost(Rates r) => costOf(blocks, r);

  /// Every currency code used by this trip.
  Set<String> get currenciesUsed => {
    currency,
    for (final b in blocks) ...[
      if (b.budget != 0) b.budgetCurrency,
      if (b.cost != 0) b.costCurrency,
    ],
  };

  /// Raw (unconverted) budget and cost totals per currency code.
  Map<String, (double, double)> totalsByCurrency() {
    final m = <String, (double, double)>{};
    for (final b in blocks) {
      if (b.budget != 0) {
        final (bu, co) = m[b.budgetCurrency] ?? (0.0, 0.0);
        m[b.budgetCurrency] = (bu + b.budget, co);
      }
      if (b.cost != 0) {
        final (bu, co) = m[b.costCurrency] ?? (0.0, 0.0);
        m[b.costCurrency] = (bu, co + b.cost);
      }
    }
    return m;
  }

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
    currency: normalizeCurrency(j['currency'] as String?),
    blocks: (j['blocks'] as List? ?? [])
        .map(
          (e) => TimeBlock.fromJson(
            e as Map<String, dynamic>,
            defaultCurrency: normalizeCurrency(j['currency'] as String?),
          ),
        )
        .toList(),
  );
}

HomeTotal budgetOf(Iterable<TimeBlock> blocks, Rates r) =>
    HomeTotal.sum(blocks.map((b) => (b.budget, b.budgetCurrency)), r);

HomeTotal costOf(Iterable<TimeBlock> blocks, Rates r) =>
    HomeTotal.sum(blocks.map((b) => (b.cost, b.costCurrency)), r);

/// A row in the dashboard table.
sealed class TableRowItem {}

class DayHeaderRow extends TableRowItem {
  final int dayNumber;
  final DateTime day;
  final List<TimeBlock> blocks;
  final Duration planned;
  DayHeaderRow(this.dayNumber, this.day, this.blocks, this.planned);
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
        dayBlocks,
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
