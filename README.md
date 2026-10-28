# Trip Planner

A Flutter mobile app that plans a trip minute by minute in a spreadsheet-style table.

## Features
- **Trips** with a start date + time and an end date + time.
- **Dashboard** for each trip:
  - Summary tiles: total budget, spent, remaining / over budget, % of trip time planned and free time left.
  - A "Now" line while the trip is on: current activity and time left, or the next activity.
  - **Excel-like table**: one row per time block with #, Start, End, Time, Activity, Budget, Cost, Left and Description. The header stays visible; swipe sideways for more columns.
  - Rows are grouped by **day**, each day row shows its budget and cost subtotals, and a **TOTAL** row sits at the bottom.
  - **Free time** rows show every unplanned gap. Tap one to plan it.
  - Rows over budget are shown in red. Overlapping blocks and blocks outside the trip dates get a ⚠ icon.
  - The block happening right now is highlighted.
- **Time blocks**: activity, start, end, quick-duration chips, budget, actual cost and a multi-line description.
- **Clickable links** in descriptions (`https://…`, `www.…`, e-mail addresses), in both the table and the editor preview.
- Tap a row to edit it. Long-press a row to edit, duplicate or delete it (deletes can be undone).
- Copy the whole table as CSV, ready to paste into Excel or Google Sheets.
- Data is saved on the device (shared_preferences).
- On phones, Start/End/Time are combined into one column so Budget and Cost stay visible. Tablets show every column separately.

## Run it
```bash
flutter pub get
flutter run              # on a connected phone or emulator
flutter build apk        # Android APK -> build/app/outputs/flutter-apk/app-release.apk
flutter build ios        # iOS (on a Mac with Xcode)
```

## Code
- `lib/models.dart`: Trip, TimeBlock, and the table row builder (days, gaps, overlaps)
- `lib/store.dart`: storage on the device
- `lib/screens/trip_dashboard_screen.dart`: dashboard and table
- `lib/screens/block_editor_screen.dart`, `trip_editor_screen.dart`: forms
- `lib/widgets/linkified_text.dart`: clickable links
