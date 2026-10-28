import 'package:flutter/material.dart';

import 'screens/trips_screen.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TripStore();
  store.load();
  runApp(TripPlannerApp(store: store));
}

class TripPlannerApp extends StatelessWidget {
  final TripStore store;
  const TripPlannerApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF00796B);
    return MaterialApp(
      title: 'Trip Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: TripsScreen(store: store),
    );
  }
}
