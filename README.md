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
- **Currencies**: each budget and each cost has its own 3-letter currency code (EUR, USD, TND…).
  - In every row, under the amount, its value in **DZD** is shown. The Left column and the day and TOTAL rows are in DZD.
  - The summary at the top is all in DZD, with a per-currency breakdown.
  - **Settings → Exchange rates** (💱 icon on the home screen, or the ⋮ menu on a trip): set `1 XXX = ? DZD` for each currency.
  - A currency without a rate is never guessed. Its amounts show "no rate", they are left out of the DZD totals, and a red banner says so.
  - The trip's currency is the default for new blocks.
- Copy the whole table as CSV (with currency and DZD columns), ready to paste into Excel or Google Sheets.
- Data is saved on the device (shared_preferences).
- On phones, Start/End/Time are combined into one column so Budget and Cost stay visible. Tablets show every column separately.

## Run it
```bash
flutter pub get
flutter run              # on a connected phone or emulator
flutter build apk        # Android APK -> build/app/outputs/flutter-apk/app-release.apk
flutter build ios        # iOS (on a Mac with Xcode)
```

## Get the APK without installing anything
1. Create a new repository on GitHub and upload this folder to it.
2. Open the **Actions** tab. The **Build APK** workflow runs on every push, or you can start it with **Run workflow**.
3. When it finishes (about 5–10 minutes), open the run and download **trip-planner-apk** under *Artifacts*.
4. Unzip it, copy `app-release.apk` to your phone, open it, and allow "Install unknown apps" when Android asks.

## Code
- `lib/models.dart`: Trip, TimeBlock, and the table row builder (days, gaps, overlaps)
- `lib/currency.dart`: exchange rates and DZD conversion
- `lib/store.dart`: storage on the device (trips and rates)
- `lib/screens/rates_screen.dart`: exchange rate settings
- `lib/screens/trip_dashboard_screen.dart`: dashboard and table
- `lib/screens/block_editor_screen.dart`, `trip_editor_screen.dart`: forms
- `lib/widgets/linkified_text.dart`: clickable links
