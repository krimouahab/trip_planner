import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency.dart';
import 'models.dart';

/// Holds every trip and the exchange rates, and persists them on the device.
class TripStore extends ChangeNotifier {
  static const _key = 'trips_v1';
  static const _ratesKey = 'rates_v1';

  final List<Trip> _trips = [];
  Rates rates = Rates();
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
    final rawRates = prefs.getString(_ratesKey);
    if (rawRates != null) {
      try {
        rates = Rates.fromJson(jsonDecode(rawRates) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not read saved rates: $e');
      }
    }
    // Make every currency already used by a trip show up in Settings.
    for (final t in _trips) {
      for (final c in t.currenciesUsed) {
        if (!rates.contains(c)) rates.set(c, null);
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
    await prefs.setString(_ratesKey, jsonEncode(rates.toJson()));
  }

  /// Adds or updates a currency; [rate] is how many DZD one unit is worth.
  Future<void> setRate(String code, double? rate) {
    rates.set(code, rate);
    return _save();
  }

  /// Currencies still used by a trip can't be removed.
  bool isCurrencyInUse(String code) =>
      _trips.any((t) => t.currenciesUsed.contains(code));

  Future<void> removeCurrency(String code) {
    rates.remove(code);
    return _save();
  }

  void _registerCurrencies(Iterable<String> codes) {
    for (final c in codes) {
      if (!rates.contains(c)) rates.set(c, null);
    }
  }

  Future<void> upsertTrip(Trip trip) {
    final i = _trips.indexWhere((t) => t.id == trip.id);
    if (i == -1) {
      _trips.add(trip);
    } else {
      _trips[i] = trip;
    }
    _registerCurrencies(trip.currenciesUsed);
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
    _registerCurrencies([block.budgetCurrency, block.costCurrency]);
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

    TimeBlock eur(
      DateTime start,
      DateTime end,
      String activity, {
      double budget = 0,
      double cost = 0,
      String description = '',
    }) => TimeBlock(
      start: start,
      end: end,
      activity: activity,
      budget: budget,
      budgetCurrency: 'EUR',
      cost: cost,
      costCurrency: 'EUR',
      description: description,
    );

    final trip = Trip(
      name: 'Paris weekend (sample)',
      start: at(0, 6),
      end: at(2, 20),
      currency: 'EUR',
      blocks: [
        TimeBlock(
          start: at(0, 6),
          end: at(0, 8, 30),
          activity: 'Flight Algiers → Paris',
          budget: 45000,
          cost: 42500,
          description: 'Paid in dinars. Check-in: https://airalgerie.dz',
        ),
        eur(
          at(0, 9),
          at(0, 10, 30),
          'Train to the city',
          budget: 15,
          cost: 11.8,
          description: 'RER B. Tickets: https://www.ratp.fr',
        ),
        eur(
          at(0, 11),
          at(0, 12),
          'Hotel check-in',
          description:
              'Drop bags early. Map: https://maps.google.com/?q=Le+Marais',
        ),
        eur(
          at(0, 12),
          at(0, 13, 30),
          'Lunch',
          budget: 35,
          cost: 41,
          description: 'Bistro near the hotel',
        ),
        eur(
          at(0, 14),
          at(0, 17),
          'Louvre',
          budget: 22,
          cost: 22,
          description:
              'Book the time slot first: https://www.louvre.fr/en/visit',
        ),
        eur(at(0, 19, 30), at(0, 21, 30), 'Dinner + Seine walk', budget: 60),
        eur(at(0, 22), at(1, 8), 'Sleep', description: 'Hotel'),
        eur(at(1, 8, 30), at(1, 9, 30), 'Breakfast', budget: 15),
        eur(
          at(1, 10),
          at(1, 12, 30),
          'Eiffel Tower',
          budget: 30,
          description: 'Summit tickets: https://www.toureiffel.paris/en',
        ),
      ],
    );
    _trips.add(trip);
    _registerCurrencies(trip.currenciesUsed);
    _save();
    return Future.value(trip);
  }
}
