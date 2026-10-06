import 'package:flutter/material.dart';

import 'database_helper.dart';

// Entry point. The database must be open BEFORE the first screen asks it
// for rows, so we await init() here. If it fails, we show an honest error
// screen instead of an empty roster that pretends nothing is stored.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Could not open local storage. Restart the app and check the logs.',
          ),
        ),
      ),
    ));
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

// Root widget. It receives the one initialized helper and passes it down.
class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      home: RosterScreen(helper: helper),
    );
  }
}

// The one and only screen: form on top, record count, then the list.
class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  // Form pieces. One form is reused for both Add and Edit.
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  // Rows exactly as the database returned them (a list of maps).
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;

  // True once at least one read has succeeded. The empty message is only
  // allowed after a successful read that returned zero rows.
  bool _hasLoaded = false;

  // ONE busy flag guards every database action (read, add, edit, delete).
  // It starts true because the first load begins right away in initState.
  bool _busy = true;

  // Message from the last failed READ. Kept separate from write feedback.
  String? _readError;

  // Plain text feedback for the last action (success, not found, error).
  String? _feedback;

  // The _id of the row being edited. null means the form is in Add mode.
  int? _editingId;

  @override
  void initState() {
    super.initState();
    // The first load happens here, never inside build().
    _initialLoad();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- reading

  // Reads rows and count from the database and updates the screen.
  // Returns true if the read worked. Does not touch the busy flag, so the
  // caller decides when the busy period ends.
  Future<bool> _reload() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return false;
      setState(() {
        _rows = rows;
        _count = count;
        _hasLoaded = true;
        _readError = null;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read the roster. Press Refresh to retry.';
      });
      return false;
    }
  }

  Future<void> _initialLoad() async {
    try {
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRefreshPressed() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final ok = await _reload();
      if (ok && mounted) {
        setState(() => _feedback = 'Refreshed from the database.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- validation

  // Name must be nonempty after trimming spaces.
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a name. Spaces alone do not count.';
    }
    return null;
  }

  // Age must be a whole number from 0 through 130 inclusive.
  // int.tryParse returns null for "abc" and "1.5", so those are rejected.
  String? _validateAge(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Enter an age from 0 to 130.';
    }
    // Digits only (no sign, decimal point, or hex), at most 3 characters.
    if (!RegExp(r'^\d{1,3}$').hasMatch(text)) {
      return 'Age must be a whole number such as 21.';
    }
    final age = int.tryParse(text);
    if (age == null) {
      return 'Age must be a whole number such as 21.';
    }
    if (age < 0 || age > 130) {
      return 'Age must be between 0 and 130.';
    }
    return null;
  }

  // ------------------------------------------------------- add / edit / save

  // Called by the Add/Save button. Adds in Add mode, updates in Edit mode.
  Future<void> _onSavePressed() async {
    if (_busy) return;
    // Invalid input stops here, so nothing is written.
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    if (age == null) return; // Cannot happen after validation; safe guard.

    final editingId = _editingId;
    setState(() {
      _busy = true;
      _feedback = null;
    });

    // Step 1: the write. Step 2: the refresh. They report separately.
    String writeMessage;
    bool writeSucceeded = false;
    bool clearEditSelection = false;

    try {
      if (editingId == null) {
        // _id is left out so SQLite assigns a new one.
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
        writeSucceeded = true;
        writeMessage = 'Added $name, age $age. New ID: $id.';
      } else {
        // The update targets the selected row by its integer _id.
        final affected = await widget.helper.update({
          DatabaseHelper.columnId: editingId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
        if (affected == 1) {
          writeSucceeded = true;
          writeMessage =
              'Updated ID $editingId to $name, age $age. Rows affected: $affected.';
        } else {
          // Zero rows means the guest no longer exists. Do not say "saved".
          clearEditSelection = true;
          writeMessage =
              'Guest ID $editingId was not found, so nothing was updated '
              '(rows affected: $affected). Your typed text is still in the form.';
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Write failed: $error\n$stackTrace');
      if (!mounted) return;
      // Keep the typed input so the user can retry.
      setState(() {
        _feedback = 'Error: could not save. Your input was kept. Try again.';
        _busy = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      if (writeSucceeded) {
        // Clear the form only when the write itself worked.
        _nameController.clear();
        _ageController.clear();
        _editingId = null;
      } else if (clearEditSelection) {
        _editingId = null;
      }
    });
    // Reset validation messages after clearing, so no stale red text shows.
    if (writeSucceeded) _formKey.currentState?.reset();

    try {
      final refreshed = await _reload();
      if (!mounted) return;
      setState(() {
        if (writeSucceeded && !refreshed) {
          _feedback = 'Saved, but refresh failed. Press Refresh to see it. '
              '$writeMessage';
        } else {
          _feedback = writeMessage;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Puts a row into the form and remembers its ID.
  void _onEditPressed(Map<String, dynamic> row) {
    if (_busy) return;
    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = null;
    });
    _formKey.currentState?.reset();
    // reset() restores initial values, so set the text again afterwards.
    _nameController.text = row[DatabaseHelper.columnName] as String;
    _ageController.text = '${row[DatabaseHelper.columnAge]}';
  }

  // Cancel edit never writes anything. It only clears the form.
  void _onCancelEditPressed() {
    if (_busy || _editingId == null) return;
    setState(() {
      _editingId = null;
      _nameController.clear();
      _ageController.clear();
      _feedback = 'Edit canceled. Nothing was changed.';
    });
    _formKey.currentState?.reset();
  }

  // ----------------------------------------------------------------- delete

  Future<void> _onDeletePressed(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;

    // Ask first. The dialog names the row's ID and name.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete ID $id ($name)? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      // Canceled: write nothing.
      setState(() => _feedback = 'Delete canceled. Nothing was changed.');
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });

    String message;
    bool deleteSucceeded = false;
    try {
      // Targets the row by its ID, never by name or list position.
      final deleted = await widget.helper.delete(id);
      if (deleted == 1) {
        deleteSucceeded = true;
        message = 'Deleted ID $id ($name). Rows affected: $deleted.';
      } else {
        message = 'Guest ID $id was not found (rows affected: $deleted). '
            'The list was reloaded.';
      }
      // Either way that row is gone, so if it was being edited, clear the edit state.
      if (_editingId == id && mounted) {
        setState(() {
          _editingId = null;
          _nameController.clear();
          _ageController.clear();
        });
        _formKey.currentState?.reset();
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = 'Error: could not delete ID $id. Try again.';
        _busy = false;
      });
      return;
    }

    try {
      final refreshed = await _reload();
      if (!mounted) return;
      setState(() {
        _feedback = (refreshed || !deleteSucceeded)
            ? message
            : 'Deleted, but refresh failed. Press Refresh. $message';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final editing = _editingId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Fall Festival Roster')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The mode label tells the user what Save will do.
              Text(
                editing ? 'Editing guest ID $_editingId' : 'Add a new guest',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _ageController,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          hintText: '0 to 130',
                          border: OutlineInputBorder(),
                        ),
                        // Plain text keyboard so every invalid case in the
                        // T6 test (letters, decimals) can be typed and rejected.
                        keyboardType: TextInputType.text,
                        validator: _validateAge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _onSavePressed,
                    child: Text(editing ? 'Save' : 'Add'),
                  ),
                  OutlinedButton(
                    onPressed: (_busy || !editing) ? null : _onCancelEditPressed,
                    child: const Text('Cancel edit'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _onRefreshPressed,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Explicit record count straight from the database.
              Text(
                'Guests in database: $_count',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 4),
                Text(_feedback!),
              ],
              const SizedBox(height: 8),
              Expanded(child: _buildListArea()),
            ],
          ),
        ),
      ),
    );
  }

  // Chooses between loading, read error, empty, and the real list.
  Widget _buildListArea() {
    // Loading: the first read has not finished yet.
    if (_busy && !_hasLoaded && _readError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Read error: say so honestly. Never show this as "no guests".
    if (_readError != null) {
      return Center(child: Text('Error: $_readError'));
    }
    // Empty: only reached after a successful read with zero rows.
    if (_hasLoaded && _rows.isEmpty) {
      return const Center(
        child: Text('No festival guests yet. Add the first one above!'),
      );
    }
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final id = row[DatabaseHelper.columnId] as int;
        final name = row[DatabaseHelper.columnName] as String;
        final age = row[DatabaseHelper.columnAge] as int;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('ID: $id   Age: $age'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _onEditPressed(row),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _onDeletePressed(row),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
