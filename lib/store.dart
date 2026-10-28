import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Holds every trip and persists them on the device.
class TripStore extends ChangeNotifier {
  static const _key = 'trips_v1';

  final List<Trip> _trips = [];
  bool loaded = false;

  List<Trip> get trips =>
      [..._trips]..sort((a, b) => a.start.compareTo(b.start));

  Trip? byId(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _trips
          ..clear()
          ..addAll(list.map((e) => Trip.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('Could not read saved trips: $e');
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_trips.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> upsertTrip(Trip trip) {
    final i = _trips.indexWhere((t) => t.id == trip.id);
    if (i == -1) {
      _trips.add(trip);
    } else {
      _trips[i] = trip;
    }
    return _save();
  }

  Future<void> deleteTrip(String id) {
    _trips.removeWhere((t) => t.id == id);
    return _save();
  }

  Future<void> upsertBlock(Trip trip, TimeBlock block) {
    final i = trip.blocks.indexWhere((b) => b.id == block.id);
    if (i == -1) {
      trip.blocks.add(block);
    } else {
      trip.blocks[i] = block;
    }
    return _save();
  }

  Future<void> deleteBlock(Trip trip, String blockId) {
    trip.blocks.removeWhere((b) => b.id == blockId);
    return _save();
  }

  /// A small example so the dashboard isn't empty on first launch.
  Future<Trip> addSampleTrip() {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day + 7);
    DateTime at(int day, int h, [int m = 0]) =>
        DateTime(d0.year, d0.month, d0.day + day, h, m);

    final trip = Trip(
      name: 'Paris weekend (sample)',
      start: at(0, 8),
      end: at(2, 20),
      currency: '€',
      blocks: [
        TimeBlock(
          start: at(0, 8),
          end: at(0, 10, 30),
          activity: 'Train to Paris',
          budget: 90,
          cost: 84.5,
          description:
              'Seat 42, coach 7. Tickets: https://www.sncf-connect.com',
        ),
        TimeBlock(
          start: at(0, 11),
          end: at(0, 12),
          activity: 'Hotel check-in',
          budget: 0,
          description:
              'Drop bags early. Map: https://maps.google.com/?q=Le+Marais',
        ),
        TimeBlock(
          start: at(0, 12),
          end: at(0, 13, 30),
          activity: 'Lunch',
          budget: 35,
          cost: 41,
          description: 'Bistro near the hotel',
        ),
        TimeBlock(
          start: at(0, 14),
          end: at(0, 17),
          activity: 'Louvre',
          budget: 22,
          cost: 22,
          description:
              'Book the time slot first: https://www.louvre.fr/en/visit',
        ),
        TimeBlock(
          start: at(0, 19, 30),
          end: at(0, 21, 30),
          activity: 'Dinner + Seine walk',
          budget: 60,
          cost: 0,
          description: '',
        ),
        TimeBlock(
          start: at(0, 22),
          end: at(1, 8),
          activity: 'Sleep',
          description: 'Hotel',
        ),
        TimeBlock(
          start: at(1, 8, 30),
          end: at(1, 9, 30),
          activity: 'Breakfast',
          budget: 15,
        ),
        TimeBlock(
          start: at(1, 10),
          end: at(1, 12, 30),
          activity: 'Eiffel Tower',
          budget: 30,
          description: 'Summit tickets: https://www.toureiffel.paris/en',
        ),
      ],
    );
    _trips.add(trip);
    _save();
    return Future.value(trip);
  }
}
