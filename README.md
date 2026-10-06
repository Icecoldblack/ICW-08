# Fall Festival Roster (In-Class Activity 08, Local Storage Part 1)

* Student: Uyiosa Nehikhuere
* Course/section: Mobile Application Development, section [FILL IN]
* Pathway: Undergraduate (prompts 1 to 3)

## Setup and run

* Flutter version: [FILL IN, from `flutter --version`]
* Dart version: [FILL IN]
* Device and OS: [FILL IN, for example Android emulator Pixel 8, Android 15]
* Packages (from pubspec.yaml): sqflite ^2.4.1, path_provider ^2.1.5, path ^1.9.0
* SDK constraint kept from the sample: Dart ^3.6.1. No version changes were needed: [CONFIRM OR NOTE ANY CHANGE]

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
| T1 Empty | Refresh with no rows | Count 0, empty message | [FILL IN] | [FILL IN] |
| T2 Create | Add River 21 and River 34 | Count 2, distinct IDs A and B | A = [ID], B = [ID], count [N] | [FILL IN] |
| T3 Identity | Edit B to 99 then Cancel. Edit B again, Save 35 | B stays 34 after Cancel. Save returns 1, A stays 21, B becomes 35 | [FILL IN] | [FILL IN] |
| T4 Restart | Force stop and relaunch, no data cleared | Same IDs, names, ages, count, no reseeding | [FILL IN] | [FILL IN] |
| T5 Delete | Cancel deleting A, then confirm and Refresh | Cancel keeps count 2. Confirm returns 1. Only B remains, count 1 | [FILL IN] | [FILL IN] |
| T6 Validation | Space-only name with age 21. Name Maple with ages abc, 1.5, -1, 131 separately. Then Acorn 0 and Oak 130 | Five rejections with feedback, count stays 1. Acorn and Oak accepted, count 3 | [FILL IN, list each attempt] | [FILL IN] |

* Exact stop and relaunch method used for T4: [FILL IN]
* Screenshots: `evidence/T4_before.png`, `evidence/T4_after.png`, `evidence/T6_invalid.png`
* Analyzer result: see `evidence/analysis_output.txt`. [FILL IN: clean, or list remaining findings]
* Known limitations: the app has one screen and no sync or encryption. The local database file is not backed up. Update and delete report zero affected rows if the ID is gone, and the app says so rather than claiming success.

## Reflections (undergraduate prompts 1 to 3)

1. Prediction (written BEFORE T4), then actual result and interpretation:
   * Prediction: [WRITE THIS BEFORE T4, with your real IDs A and B and the count]. My guess is that both River rows, with their same IDs and ages, come back after a real stop and relaunch, because `init()` reopens the same database file and `_reload()` queries it from `initState()`, so the list is rebuilt from disk and not from memory.
   * Actual: [FILL IN, citing `T4_before.png` and `T4_after.png`].
   * What would disprove it: an empty list, new IDs, or a count that restarted from 0 or 1 after relaunch would mean the data was not restored from SQLite, for example if the app had been uninstalled or storage cleared.

2. Two Rivers, one wrong edit:
   * My IDs were A = [ID] and B = [ID]. Saving the edit returned [1] affected row, A stayed 21, and B became 35: [CONFIRM FROM T3].
   * Both guests are named River, so a name cannot say which one to change. The update in `_onSavePressed` passes `DatabaseHelper.columnId: editingId`, and the helper uses `WHERE _id = ?`.
   * Hypothetical: if I picked by list position and the list were later sorted by age, position 1 could point to the other River and the wrong record would be edited.

3. My own walkthrough:
   * Observation from my screen: [FILL IN, one real thing you noticed while running Add, Edit, Cancel, and Delete].
   * Proposed improvement: [FILL IN, for example a snackbar for feedback instead of a text line]. Trade-off: [FILL IN, for example it disappears quickly and is harder to screenshot as evidence].
   * How I know invalid input did not save: in T6 each rejected attempt showed field feedback (see `T6_invalid.png`) and the count stayed [N] with B unchanged.

## Attribution

* Starter source: `database_helper.txt` and the sample `pubspec.yaml` supplied by the instructor. Only `orderBy` was added to the helper.
* Resources: Flutter SQLite cookbook, sqflite documentation, the activity page.
