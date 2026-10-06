# Fall Festival Roster (In-Class Activity 08, Local Storage Part 1)

* Student: Uyiosa Nehikhuere
* Course/section: Mobile Application Development
* Pathway: Undergraduate (prompts 1 to 3)

## Setup and run

* Flutter SDK: C:\Users\unehi\Flutter SDK\flutter (Dart SDK 3.13.2)
* Dart version: 3.13.2
* Device and OS: Android emulator Pixel 9 Pro XL, API 37.2, run from Android Studio
* Packages (from pubspec.yaml): sqflite ^2.4.1, path_provider ^2.1.5, path ^1.9.0
* SDK constraint kept from the sample: Dart ^3.6.1. No version changes were needed.

Commands:

```
flutter create --platforms=android,ios local_storage_lab   # only if android/ and ios/ are missing
cd local_storage_lab
flutter pub get
flutter devices
flutter run -d <device-id>
flutter analyze 2>&1 | tee evidence/analysis_output.txt
```

After `flutter create`, keep the `lib/`, `pubspec.yaml`, `analysis_options.yaml`, and `README.md` from this repository, and delete the generated `test/widget_test.dart` because it tests the old counter app.

## Schema and initialization

* `main()` creates one `DatabaseHelper`, awaits `init()` once, then passes that same instance to `DirectoryApp`. If `init()` fails, an error screen is shown instead of an empty roster. The table `my_table` has `_id INTEGER PRIMARY KEY`, `name TEXT NOT NULL`, and `age INTEGER NOT NULL`, and it is created by `onCreate` only the first time the database file is made.
* Input and ID policy: the name is trimmed and must not be empty, and the age must parse with `int.tryParse` and fall from 0 through 130. SQLite assigns `_id` on insert (the app never sends one), and every update and delete targets the row's integer `_id`, never the name or the list position.

## Memory, key-value, and SQLite in this app

* Memory state example: the text typed into the name and age fields, the `_busy` flag, and `_editingId`. These vanish when the process ends.
* Key-value preferences example (not used by this app): a saved choice such as "show ages in the list" would fit here.
* SQLite records example: the guest rows, for example `_id`, `River`, `21`, which survive a restart.

## Where the code is

* Helper (starter code, one change): `lib/database_helper.dart`. My only change is `orderBy: '_id ASC'` inside `queryAllRows()`.
* Create: `_onSavePressed` in `lib/main.dart` (insert branch).
* Read: `_reload`, which calls `queryAllRows()` and `queryRowCount()`.
* Update: `_onSavePressed` (update branch, passes `columnId: editingId`).
* Delete: `_onDeletePressed` (asks for confirmation, then calls `delete(id)`).
* Validation: `_validateName` and `_validateAge`.

## Test results

Fill every row with what you actually saw on your device. Do not copy expected values.

| Test | Action and input | Expected | Observed rows and count | Pass or fail |
| --- | --- | --- | --- | --- |
| T1 Empty | Refresh with no rows | Count 0, empty message | Count 0, "Refreshed from the database.", empty message shown | Pass |
| T2 Create | Add River 21 and River 34 | Count 2, distinct IDs A and B | A = 1 (River 21), B = 2 (River 34), count 2 | Pass |
| T3 Identity | Edit B to 99 then Cancel. Edit B again, Save 35 | B stays 34 after Cancel. Save returns 1, A stays 21, B becomes 35 | Cancel: "Edit canceled. Nothing was changed.", B 34. Save: "Updated ID 2 to River, age 35. Rows affected: 1.", A 21, count 2 | Pass |
| T4 Restart | Stop and relaunch, no data cleared | Same IDs, names, ages, count, no reseeding | Before: ID 1 River 21, ID 2 River 35, count 2. After relaunch (new process 27758, was 17218): identical, count 2 | Pass |
| T5 Delete | Cancel deleting A, then confirm and Refresh | Cancel keeps count 2. Confirm returns 1. Only B remains, count 1 | Dialog "Delete ID 1 (River)?". Cancel: count 2. Confirm: "Deleted ID 1 (River). Rows affected: 1." Refresh: only ID 2 River 35, count 1 | Pass |
| T6 Validation | Space-only name with age 21. Name Maple with ages abc, 1.5, -1, 131 separately. Then Acorn 0 and Oak 130 | Five rejections with feedback, count stays 1. Acorn and Oak accepted, count 3 | Space name + 21: rejected, "Enter a name. Spaces alone do not count.", count 1. Maple + abc: rejected, "Age must be ..." (truncated), count 1. Ages 1.5, -1, 131 and Acorn 0, Oak 130: NOT YET RUN | Partial |

* Exact stop and relaunch method used for T4: stopped the Flutter debug session in Android Studio (the app process ended and the emulator returned to another app), then started a new `flutter run` on the same emulator without uninstalling or clearing data. The log shows a new process ID. App info Force stop was not used.
* Screenshots: `evidence/T4_before.png`, `evidence/T4_after.png`, `evidence/T6_invalid.png`
* Analyzer result: `flutter analyze` not yet saved to `evidence/analysis_output.txt`. The project compiled and hot reloaded with no errors.
* Known limitations: the app has one screen and no sync or encryption. The local database file is not backed up. Update and delete report zero affected rows if the ID is gone, and the app says so rather than claiming success.

## Reflections (undergraduate prompts 1 to 3)

1. Prediction (written BEFORE T4), then actual result and interpretation:
   * Prediction (written at 6:49 PM, before running T4): ID 1 (River, 21) and ID 2 (River, 35) will both come back after the stop and relaunch, with count 2 and the same IDs, because `init()` reopens the same database file in the app documents directory and `_reload()` queries it from `initState()`, so the list is rebuilt from disk and not from memory. The edited age 35 should survive because the update was committed before the app stopped.
   * Actual: the prediction held. `T4_before.png` and `T4_after.png` both show ID 1 River 21 and ID 2 River 35 with count 2, and nothing was reseeded.
   * What would disprove it: an empty list, new IDs, or a count that restarted from 0 or 1 after relaunch would mean the data was not restored from SQLite, for example if the app had been uninstalled or storage cleared.

2. Two Rivers, one wrong edit:
   * My IDs were A = 1 and B = 2. Saving the edit returned 1 affected row, A stayed 21, and B became 35.
   * Both guests are named River, so a name cannot say which one to change. The update in `_onSavePressed` passes `DatabaseHelper.columnId: editingId`, and the helper uses `WHERE _id = ?`.
   * Hypothetical: if I picked by list position and the list were later sorted by age, position 1 could point to the other River and the wrong record would be edited.

3. My own walkthrough:
   * Observation from my screen: when Maple was entered with age abc, the Age error showed only "Age must be ..." because the Age field is narrow, so the reason was cut off.
   * Proposed improvement: set `errorMaxLines` on the Age field (or widen it) so the full message wraps. Trade off: the form gets taller and pushes the list down.
   * How I know invalid input did not save: each rejected attempt showed field feedback (see `T6_invalid.png`) and the count stayed 1 with ID 2 River 35 unchanged.

## Attribution

* Starter source: `database_helper.txt` and the sample `pubspec.yaml` supplied by the instructor. Only `orderBy` was added to the helper.
* Resources: Flutter SQLite cookbook, sqflite documentation, the activity page.
