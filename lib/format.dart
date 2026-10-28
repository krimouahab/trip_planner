import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');
final _time = DateFormat('HH:mm');
final _day = DateFormat('EEE d MMM yyyy');
final _shortDay = DateFormat('EEE d MMM');
final _dateTime = DateFormat('EEE d MMM, HH:mm');

String money(double v, String currency) =>
    '${v < 0 ? '-' : ''}$currency${_money.format(v.abs())}';

String time(DateTime t) => _time.format(t);

/// End time, with "+1" when it lands on a later day than [from].
String endTime(DateTime from, DateTime end) {
  final days = DateTime(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime(from.year, from.month, from.day)).inDays;
  // An end of exactly 00:00 the next day reads better as 24:00.
  if (days == 1 && end.hour == 0 && end.minute == 0) return '24:00';
  return days > 0 ? '${_time.format(end)} +$days' : _time.format(end);
}

String day(DateTime t) => _day.format(t);
String shortDay(DateTime t) => _shortDay.format(t);
String dateTime(DateTime t) => _dateTime.format(t);

String duration(Duration d) {
  final mins = d.inMinutes;
  if (mins <= 0) return '0m';
  final days = mins ~/ (24 * 60);
  final h = (mins % (24 * 60)) ~/ 60;
  final m = mins % 60;
  final parts = <String>[
    if (days > 0) '${days}d',
    if (h > 0) '${h}h',
    if (m > 0) '${m}m',
  ];
  return parts.join(' ');
}
