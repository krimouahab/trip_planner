import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../currency.dart';
import '../format.dart' as fmt;
import '../models.dart';
import '../store.dart';
import '../widgets/linkified_text.dart';
import 'block_editor_screen.dart';
import 'rates_screen.dart';
import 'trip_editor_screen.dart';

class TripDashboardScreen extends StatefulWidget {
  final TripStore store;
  final String tripId;
  const TripDashboardScreen({
    super.key,
    required this.store,
    required this.tripId,
  });

  @override
  State<TripDashboardScreen> createState() => _TripDashboardScreenState();
}

class _TripDashboardScreenState extends State<TripDashboardScreen> {
  bool _showFreeTime = true;
  bool _showSummary = true;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    // Keep the "now" highlight current.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  TripStore get store => widget.store;

  Future<void> _editBlock(
    Trip trip, {
    TimeBlock? block,
    DateTime? start,
    DateTime? end,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockEditorScreen(
          store: store,
          trip: trip,
          block: block,
          initialStart: start,
          initialEnd: end,
        ),
      ),
    );
  }

  Future<void> _blockMenu(Trip trip, TimeBlock block) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                block.activity,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${fmt.dateTime(block.start)} – ${fmt.endTime(block.start, block.end)}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate right after'),
              onTap: () => Navigator.pop(c, 'dup'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'edit':
        await _editBlock(trip, block: block);
      case 'dup':
        await store.upsertBlock(
          trip,
          TimeBlock(
            start: block.end,
            end: block.end.add(block.duration),
            activity: block.activity,
            description: block.description,
            budget: block.budget,
          ),
        );
      case 'delete':
        await store.deleteBlock(trip, block.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${block.activity}"'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => store.upsertBlock(trip, block),
            ),
          ),
        );
    }
  }

  Future<void> _openRates() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => RatesScreen(store: store)),
  );

  Future<void> _tripMenu(Trip trip, String action) async {
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripEditorScreen(store: store, trip: trip),
          ),
        );
      case 'rates':
        await _openRates();
      case 'csv':
        await Clipboard.setData(ClipboardData(text: _toCsv(trip)));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table copied — paste it into Excel or Sheets'),
          ),
        );
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete trip?'),
            content: Text(
              '"${trip.name}" and its ${trip.blocks.length} time blocks will be removed.',
            ),
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
        if (ok == true) {
          await store.deleteTrip(trip.id);
          if (mounted) Navigator.pop(context);
        }
    }
  }

  String _toCsv(Trip trip) {
    final rates = store.rates;
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final lines = <String>[
      'Date,Start,End,Duration (min),Activity,Budget,Budget currency,Budget DZD,'
          'Cost,Cost currency,Cost DZD,Remaining DZD,Description',
      for (final b in trip.sortedBlocks)
        [
          fmt.shortDay(b.start),
          fmt.time(b.start),
          fmt.endTime(b.start, b.end),
          b.duration.inMinutes,
          q(b.activity),
          b.budget.toStringAsFixed(2),
          b.budgetCurrency,
          b.budgetHome(rates)?.toStringAsFixed(2) ?? '',
          b.cost.toStringAsFixed(2),
          b.costCurrency,
          b.costHome(rates)?.toStringAsFixed(2) ?? '',
          b.remainingHome(rates)?.toStringAsFixed(2) ?? '',
          q(b.description),
        ].join(','),
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.byId(widget.tripId);
        if (trip == null) return const Scaffold();
        final rows = buildTableRows(trip, includeGaps: _showFreeTime);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.name, overflow: TextOverflow.ellipsis),
                Text(
                  '${fmt.dateTime(trip.start)} → ${fmt.dateTime(trip.end)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: _showFreeTime ? 'Hide free time' : 'Show free time',
                icon: Icon(
                  _showFreeTime
                      ? Icons.hourglass_bottom
                      : Icons.hourglass_disabled_outlined,
                ),
                onPressed: () => setState(() => _showFreeTime = !_showFreeTime),
              ),
              PopupMenuButton<String>(
                onSelected: (a) => _tripMenu(trip, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_calendar),
                      title: Text('Edit trip dates'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rates',
                    child: ListTile(
                      leading: Icon(Icons.currency_exchange),
                      title: Text('Exchange rates'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: ListTile(
                      leading: Icon(Icons.table_view),
                      title: Text('Copy table (CSV)'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete trip'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add time block',
            onPressed: () => _editBlock(trip),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              _SummaryPanel(
                trip: trip,
                rates: store.rates,
                onOpenRates: _openRates,
                expanded: _showSummary,
                onToggle: () => setState(() => _showSummary = !_showSummary),
              ),
              Expanded(
                child: _TripTable(
                  trip: trip,
                  rates: store.rates,
                  rows: rows,
                  onBlockTap: (b) => _editBlock(trip, block: b),
                  onBlockLongPress: (b) => _blockMenu(trip, b),
                  onGapTap: (g) => _editBlock(trip, start: g.start, end: g.end),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────── Summary ─────────────────────────────

class _SummaryPanel extends StatelessWidget {
  final Trip trip;
  final Rates rates;
  final VoidCallback onOpenRates;
  final bool expanded;
  final VoidCallback onToggle;
  const _SummaryPanel({
    required this.trip,
    required this.rates,
    required this.onOpenRates,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const cur = homeCurrency;
    final total = trip.duration.inMinutes;
    final planned = trip.plannedMinutes;
    final ratio = total <= 0 ? 0.0 : planned / total;
    final budget = trip.totalBudget(rates);
    final cost = trip.totalCost(rates);
    final remaining = budget.value - cost.value;
    final overCount = trip.blocks.where((b) => b.overBudget(rates)).length;
    final spentRatio = budget.value <= 0 ? 0.0 : cost.value / budget.value;
    final missingCodes = {...budget.missingCodes, ...cost.missingCodes};
    final byCurrency = trip.totalsByCurrency()..remove(homeCurrency);

    final now = DateTime.now();
    String? nowText;
    if (!now.isBefore(trip.start) && now.isBefore(trip.end)) {
      final current = trip.sortedBlocks.where((b) => b.isActiveAt(now));
      if (current.isNotEmpty) {
        final b = current.first;
        nowText =
            'Now: ${b.activity} · ${fmt.duration(b.end.difference(now))} left';
      } else {
        final next = trip.sortedBlocks.where((b) => b.start.isAfter(now));
        nowText = next.isEmpty
            ? 'Now: free time until the end of the trip'
            : 'Now: free · next "${next.first.activity}" in ${fmt.duration(next.first.start.difference(now))}';
      }
    } else if (now.isBefore(trip.start)) {
      nowText = 'Trip starts in ${fmt.duration(trip.start.difference(now))}';
    }

    return Material(
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      nowText ??
                          '${fmt.duration(trip.duration)} trip · ${trip.blocks.length} blocks',
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!expanded)
                    Text(
                      '${fmt.amount(cost.value)} / ${fmt.money(budget.value, cur)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: remaining < 0 ? cs.error : null,
                      ),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final perRow = c.maxWidth > 600 ? 4 : 2;
                  final w = (c.maxWidth - 8 * (perRow - 1)) / perRow;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Stat(
                            width: w,
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Budget (DZD)',
                            value: fmt.money(budget.value, cur),
                          ),
                          _Stat(
                            width: w,
                            icon: Icons.receipt_long_outlined,
                            label: 'Spent (DZD)',
                            value: fmt.money(cost.value, cur),
                            progress: spentRatio,
                            color: spentRatio > 1 ? cs.error : null,
                          ),
                          _Stat(
                            width: w,
                            icon: remaining < 0
                                ? Icons.trending_down
                                : Icons.savings_outlined,
                            label: remaining < 0
                                ? 'Over budget (DZD)'
                                : 'Remaining (DZD)',
                            value: fmt.money(remaining.abs(), cur),
                            color: remaining < 0
                                ? cs.error
                                : Colors.green.shade700,
                            noteColor: overCount > 0 ? cs.error : null,
                            note: overCount > 0
                                ? '$overCount block${overCount == 1 ? '' : 's'} over'
                                : null,
                          ),
                          _Stat(
                            width: w,
                            icon: Icons.schedule,
                            label: 'Time planned',
                            value: '${(ratio * 100).round()}%',
                            progress: ratio,
                            note:
                                '${fmt.duration(Duration(minutes: planned))} of ${fmt.duration(trip.duration)} · '
                                '${fmt.duration(Duration(minutes: trip.freeMinutes))} free',
                          ),
                        ],
                      ),
                      if (missingCodes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Material(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onOpenRates,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    size: 18,
                                    color: cs.onErrorContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No rate for ${missingCodes.join(', ')}. '
                                      '${budget.missing + cost.missing} amount(s) left out of the DZD totals. Tap to set rates.',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: cs.onErrorContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (byCurrency.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final e in byCurrency.entries)
                          InkWell(
                            onTap: onOpenRates,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text.rich(
                                TextSpan(
                                  style: theme.textTheme.labelMedium,
                                  children: [
                                    TextSpan(
                                      text: '${e.key}  ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          'budget ${fmt.amount(e.value.$1)} · '
                                          'spent ${fmt.amount(e.value.$2)}   ',
                                    ),
                                    TextSpan(
                                      text: rates.hasRate(e.key)
                                          ? '1 ${e.key} = ${fmt.rate(rates.rate(e.key)!)} DZD'
                                          : 'no rate',
                                      style: TextStyle(
                                        color: rates.hasRate(e.key)
                                            ? cs.primary
                                            : cs.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final double? progress;
  final Color? color;
  final Color? noteColor;

  const _Stat({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.note,
    this.progress,
    this.color,
    this.noteColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1).toDouble(),
                minHeight: 5,
                color: color,
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: noteColor ?? color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Table ─────────────────────────────

/// Column widths of the spreadsheet-style table. On phones the Start, End and
/// Time columns are merged into one so Budget and Cost fit on screen.
class _Cols {
  final bool compact;
  final double num;
  final double start;
  final double end;
  final double dur;
  final double time;
  final double activity;
  final double money;
  final double desc;

  const _Cols._({
    required this.compact,
    required this.num,
    this.start = 0,
    this.end = 0,
    this.dur = 0,
    this.time = 0,
    required this.activity,
    required this.money,
    required this.desc,
  });

  factory _Cols.forWidth(double w) {
    if (w < 600) {
      const fixed = 28.0 + 60 + 104 + 96 * 3;
      return _Cols._(
        compact: true,
        num: 28,
        time: 60,
        activity: 104,
        money: 96,
        desc: math.max(240, w - fixed),
      );
    }
    const fixed = 40.0 + 58 + 66 + 72 + 180 + 130 * 3;
    return _Cols._(
      compact: false,
      num: 40,
      start: 58,
      end: 66,
      dur: 72,
      activity: 180,
      money: 130,
      desc: math.max(280, w - fixed),
    );
  }

  /// Width of everything left of the Budget column.
  double get lead => num + (compact ? time : start + end + dur) + activity;
  double get total => lead + money * 3 + desc;
  EdgeInsets get padding => compact
      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8)
      : const EdgeInsets.symmetric(horizontal: 8, vertical: 8);

  /// The time cells of a row: one stacked cell (compact) or three cells.
  List<Widget> timeCells(DateTime s, DateTime e, TextStyle style) {
    final d = fmt.duration(e.difference(s));
    if (compact) {
      return [
        _Cell(
          this,
          time,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmt.time(s),
                style: style.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(fmt.endTime(s, e), style: style),
              Text(
                d,
                style: style.copyWith(
                  fontSize: 11,
                  color: style.color?.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      _Cell(this, start, Text(fmt.time(s), style: style)),
      _Cell(this, end, Text(fmt.endTime(s, e), style: style)),
      _Cell(this, dur, Text(d, style: style)),
    ];
  }
}

class _TripTable extends StatelessWidget {
  final Trip trip;
  final Rates rates;
  final List<TableRowItem> rows;
  final ValueChanged<TimeBlock> onBlockTap;
  final ValueChanged<TimeBlock> onBlockLongPress;
  final ValueChanged<GapRow> onGapTap;

  const _TripTable({
    required this.trip,
    required this.rates,
    required this.rows,
    required this.onBlockTap,
    required this.onBlockLongPress,
    required this.onGapTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = _Cols.forWidth(c.maxWidth);
        final now = DateTime.now();

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: cols.total,
              child: Column(
                children: [
                  _HeaderRow(cols: cols),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: rows.length + 1,
                      itemBuilder: (context, i) {
                        if (i == rows.length) {
                          return _TotalRow(
                            trip: trip,
                            rates: rates,
                            cols: cols,
                          );
                        }
                        return switch (rows[i]) {
                          DayHeaderRow r => _DayRow(
                            row: r,
                            rates: rates,
                            cols: cols,
                          ),
                          BlockRow r => _BlockRowView(
                            row: r,
                            rates: rates,
                            cols: cols,
                            isNow: r.block.isActiveAt(now),
                            onTap: () => onBlockTap(r.block),
                            onLongPress: () => onBlockLongPress(r.block),
                          ),
                          GapRow r => _GapRowView(
                            row: r,
                            cols: cols,
                            isNow:
                                !now.isBefore(r.start) && now.isBefore(r.end),
                            onTap: () => onGapTap(r),
                          ),
                        };
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One spreadsheet cell with right/bottom grid lines.
class _Cell extends StatelessWidget {
  final _Cols cols;
  final double width;
  final Widget child;
  final Alignment alignment;
  final Color? color;

  const _Cell(
    this.cols,
    this.width,
    this.child, {
    this.alignment = Alignment.centerLeft,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      width: width,
      padding: cols.padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          right: BorderSide(color: line, width: 0.5),
          bottom: BorderSide(color: line, width: 0.5),
        ),
      ),
      child: child,
    );
  }
}

Widget _gridRow(List<Widget> cells, {Color? color}) => Container(
  color: color,
  child: IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
  ),
);

/// Keeps a money amount on one line, shrinking it if the column is narrow.
Widget _oneLine(Widget text) => FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerRight,
  child: text,
);

/// Budget / Cost / Left cells of day and total rows, all in DZD.
List<Widget> _homeTotalCells(
  _Cols cols,
  HomeTotal budget,
  HomeTotal cost,
  TextStyle style, {
  required Color errorColor,
  Color? okColor,
}) {
  final left = budget.value - cost.value;
  Widget cell(String text, HomeTotal total, {Color? color}) => _Cell(
    cols,
    cols.money,
    Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _oneLine(Text(text, style: style.copyWith(color: color))),
        if (!total.complete)
          Text(
            '+${total.missing} without rate',
            style: style.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: errorColor,
            ),
          ),
      ],
    ),
    alignment: Alignment.centerRight,
  );
  return [
    cell(fmt.money(budget.value, homeCurrency), budget),
    cell(fmt.money(cost.value, homeCurrency), cost),
    cell(
      fmt.money(left, homeCurrency),
      HomeTotal(0, budget.missing + cost.missing, const {}),
      color: left < 0 ? errorColor : okColor,
    ),
  ];
}

/// An amount in its own currency, with its DZD value underneath.
Widget _amountCell(
  BuildContext context,
  _Cols cols,
  double amount,
  String code,
  Rates rates,
  TextStyle style, {
  Color? color,
}) {
  final cs = Theme.of(context).colorScheme;
  final inHome = rates.toHome(amount, code);
  final small = style.copyWith(fontSize: 11, fontWeight: FontWeight.w500);
  return _Cell(
    cols,
    cols.money,
    Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _oneLine(
          Text(fmt.money(amount, code), style: style.copyWith(color: color)),
        ),
        if (code != homeCurrency && amount != 0)
          _oneLine(
            Text(
              inHome == null
                  ? 'no rate'
                  : '= ${fmt.money(inHome, homeCurrency)}',
              style: small.copyWith(
                color: inHome == null ? cs.error : cs.primary,
              ),
            ),
          ),
      ],
    ),
    alignment: Alignment.centerRight,
  );
}

class _HeaderRow extends StatelessWidget {
  final _Cols cols;
  const _HeaderRow({required this.cols});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: cs.onPrimary,
    );
    Widget h(double w, String t, {bool right = false}) => _Cell(
      cols,
      w,
      Text(t, style: style),
      alignment: right ? Alignment.centerRight : Alignment.centerLeft,
    );
    return _gridRow(color: cs.primary, [
      h(cols.num, '#'),
      if (cols.compact)
        h(cols.time, 'Time')
      else ...[
        h(cols.start, 'Start'),
        h(cols.end, 'End'),
        h(cols.dur, 'Time'),
      ],
      h(cols.activity, 'Activity'),
      h(cols.money, 'Budget', right: true),
      h(cols.money, 'Cost', right: true),
      h(cols.money, 'Left (DZD)', right: true),
      h(cols.desc, 'Description'),
    ]);
  }
}

class _DayRow extends StatelessWidget {
  final DayHeaderRow row;
  final Rates rates;
  final _Cols cols;
  const _DayRow({required this.row, required this.rates, required this.cols});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: cs.onSecondaryContainer,
    );
    return _gridRow(color: cs.secondaryContainer, [
      _Cell(
        cols,
        cols.lead,
        Text(
          'DAY ${row.dayNumber}  ·  ${cols.compact ? fmt.shortDay(row.day) : fmt.day(row.day)}',
          style: style,
        ),
      ),
      ..._homeTotalCells(
        cols,
        budgetOf(row.blocks, rates),
        costOf(row.blocks, rates),
        style,
        errorColor: cs.error,
      ),
      _Cell(
        cols,
        cols.desc,
        Text(
          '${fmt.duration(row.planned)} planned',
          style: style.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ]);
  }
}

class _BlockRowView extends StatelessWidget {
  final BlockRow row;
  final Rates rates;
  final _Cols cols;
  final bool isNow;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BlockRowView({
    required this.row,
    required this.rates,
    required this.cols,
    required this.isNow,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = row.block;
    final text = TextStyle(fontSize: 13, color: cs.onSurface);
    final mono = text.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final bg = isNow
        ? cs.primaryContainer
        : row.index.isEven
        ? cs.surfaceContainerLowest
        : cs.surfaceContainerLow;
    final warning = row.overlaps
        ? 'Overlaps the previous block'
        : row.outsideTrip
        ? 'Outside the trip dates'
        : null;
    final over = b.overBudget(rates);
    final left = b.remainingHome(rates);

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: _gridRow([
          _Cell(
            cols,
            cols.num,
            warning != null
                ? Tooltip(
                    message: warning,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: cs.error,
                    ),
                  )
                : isNow
                ? Icon(Icons.play_arrow, size: 18, color: cs.primary)
                : Text(
                    '${row.index}',
                    style: mono.copyWith(color: cs.onSurfaceVariant),
                  ),
          ),
          ...cols.timeCells(b.start, b.end, mono),
          _Cell(
            cols,
            cols.activity,
            Text(b.activity, style: text.copyWith(fontWeight: FontWeight.w600)),
          ),
          _amountCell(context, cols, b.budget, b.budgetCurrency, rates, mono),
          _amountCell(
            context,
            cols,
            b.cost,
            b.costCurrency,
            rates,
            mono.copyWith(fontWeight: over ? FontWeight.bold : null),
            color: over ? cs.error : null,
          ),
          _Cell(
            cols,
            cols.money,
            left == null
                ? Tooltip(
                    message: 'Set the missing exchange rate',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Text(
                      'no rate',
                      style: mono.copyWith(color: cs.error, fontSize: 11),
                    ),
                  )
                : _oneLine(
                    Text(
                      fmt.money(left, homeCurrency),
                      style: mono.copyWith(
                        color: over
                            ? cs.onErrorContainer
                            : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            alignment: Alignment.centerRight,
            color: over ? cs.errorContainer.withValues(alpha: 0.6) : null,
          ),
          _Cell(
            cols,
            cols.desc,
            b.description.isEmpty
                ? const SizedBox.shrink()
                : LinkifiedText(b.description, style: text),
          ),
        ]),
      ),
    );
  }
}

class _GapRowView extends StatelessWidget {
  final GapRow row;
  final _Cols cols;
  final bool isNow;
  final VoidCallback onTap;

  const _GapRowView({
    required this.row,
    required this.cols,
    required this.isNow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 12,
      fontStyle: FontStyle.italic,
      color: cs.onSurfaceVariant,
    );
    return Material(
      color: isNow ? cs.tertiaryContainer : cs.surface,
      child: InkWell(
        onTap: onTap,
        child: _gridRow([
          _Cell(
            cols,
            cols.num,
            Icon(
              isNow ? Icons.play_arrow : Icons.add,
              size: 16,
              color: cs.outline,
            ),
          ),
          ...cols.timeCells(row.start, row.end, style),
          _Cell(cols, cols.activity, Text('Free time', style: style)),
          _Cell(cols, cols.money, const SizedBox.shrink()),
          _Cell(cols, cols.money, const SizedBox.shrink()),
          _Cell(cols, cols.money, const SizedBox.shrink()),
          _Cell(cols, cols.desc, Text('Tap to plan this time', style: style)),
        ]),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final Trip trip;
  final Rates rates;
  final _Cols cols;
  const _TotalRow({
    required this.trip,
    required this.rates,
    required this.cols,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: cs.onSurface,
    );
    return _gridRow(color: cs.surfaceContainerHighest, [
      _Cell(
        cols,
        cols.lead,
        Text('TOTAL  ·  ${trip.blocks.length} blocks', style: style),
      ),
      ..._homeTotalCells(
        cols,
        trip.totalBudget(rates),
        trip.totalCost(rates),
        style,
        errorColor: cs.error,
        okColor: Colors.green.shade800,
      ),
      _Cell(
        cols,
        cols.desc,
        Text(
          '${fmt.duration(Duration(minutes: trip.plannedMinutes))} planned · '
          '${fmt.duration(Duration(minutes: trip.freeMinutes))} free',
          style: style.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    ]);
  }
}
