# Simple Duplicate Prevention - UI Only

## Simplified Approach

Instead of complex database constraints and service layer changes, we'll add **simple UI validation** that checks for duplicates before submission and shows a clear warning to the user.

---

## What We'll Do

### 1. Add Duplicate Check in CreateRiverRunScreen
**File:** `lib/screens/create_river_run_screen.dart`

When user clicks "Create Run", before actually creating:
1. Search for existing rivers with the same name (case-insensitive)
2. If river exists, check for runs with the same name
3. If duplicate found, show dialog with options:
   - **Cancel** - Go back and edit
   - **Create Anyway** - Override and create duplicate
   - **View Existing** - Navigate to the existing run

### 2. Add Visual Feedback While Typing
Show a small info message below the river/run name fields:
- ℹ️ "Similar river found: Bow River (Alberta)"
- ⚠️ "A run with this name already exists on this river"

---

## Implementation (Simple)

### Step 1: Add Duplicate Check Method

Add this method to `_CreateRiverRunScreenState`:

```dart
Future<bool> _checkForDuplicates() async {
  final riverName = _riverNameController.text.trim();
  final runName = _runNameController.text.trim();

  if (riverName.isEmpty || runName.isEmpty) return true; // Allow if empty

  try {
    // Check if river exists
    final existingRivers = await RiverService.searchRivers(riverName).first;
    final matchingRiver = existingRivers.firstWhere(
      (r) => r.name.toLowerCase() == riverName.toLowerCase(),
      orElse: () => const River(id: '', name: '', region: '', country: ''),
    );

    if (matchingRiver.id.isNotEmpty) {
      // River exists, check for duplicate run
      final existingId = await RiverRunService.findExistingRun(
        riverId: matchingRiver.id,
        name: runName,
      );

      if (existingId != null) {
        // Show dialog
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Duplicate Found'),
            content: Text(
              'A run named "$runName" already exists on "$riverName".\n\n'
              'What would you like to do?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'view'),
                child: const Text('View Existing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'create'),
                child: const Text('Create Anyway'),
              ),
            ],
          ),
        );

        if (result == 'cancel' || result == null) {
          return false; // Don't create
        } else if (result == 'view') {
          // Navigate to existing run
          final run = await RiverRunService.getRunById(existingId);
          if (run != null && mounted) {
            Navigator.pop(context); // Close create screen
            // TODO: Navigate to run detail screen
          }
          return false; // Don't create
        }
        // If 'create', continue with creation
      }
    }

    return true; // No duplicate or user chose to create anyway
  } catch (e) {
    if (kDebugMode) {
      print('Error checking duplicates: $e');
    }
    return true; // On error, allow creation
  }
}
```

### Step 2: Update _createRiverRun Method

Modify the existing method to call the duplicate check:

```dart
Future<void> _createRiverRun() async {
  if (!_formKey.currentState!.validate()) return;

  // ADD THIS: Check for duplicates first
  final shouldCreate = await _checkForDuplicates();
  if (!shouldCreate) return;

  if (mounted) {
    setState(() {
      _isLoading = true;
    });
  }

  try {
    // ... rest of existing code stays the same ...
  }
}
```

### Step 3: Add findExistingRun Method to RiverRunService

Add this simple helper to `lib/services/river_run_service.dart`:

```dart
/// Check if a river run with the same riverId and name exists
/// Returns existing run ID if found, null otherwise
static Future<String?> findExistingRun({
  required String riverId,
  required String name,
}) async {
  try {
    final normalizedName = name.trim().toLowerCase();

    final snapshot = await _runsCollection
        .where('riverId', isEqualTo: riverId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final existingName = (data['name'] as String?)?.trim().toLowerCase() ?? '';
      
      if (existingName == normalizedName) {
        return doc.id;
      }
    }

    return null;
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error checking for duplicate run: $e');
    }
    return null; // Return null on error to allow creation
  }
}
```

---

## That's It!

### Total Changes:
1. **One new method** in `CreateRiverRunScreen` (`_checkForDuplicates`)
2. **One line added** to `_createRiverRun` (call the check)
3. **One helper method** in `RiverRunService` (`findExistingRun`)

### Time: ~30 minutes

### What it does:
- ✅ Prevents accidental duplicates with a friendly dialog
- ✅ Gives users options (cancel, view existing, or create anyway)
- ✅ No database changes needed
- ✅ No complex indexes or rules
- ✅ Graceful error handling (allows creation on errors)

### What it doesn't do:
- ❌ Won't prevent duplicates if user chooses "Create Anyway"
- ❌ No real-time warnings while typing (keeps it simple)
- ❌ No database-level constraints (but that's okay for this use case)

---

## Optional: Add Same Check to LogbookEntryScreen

If you want to prevent duplicate river descents (logbook entries), add a similar check in `lib/screens/logbook_entry_screen.dart` before calling `_addLogEntry()`.

---

## Why This is Good Enough:

1. **Solves 95% of the problem** - Most duplicates are accidental
2. **Fast to implement** - No infrastructure changes
3. **User-friendly** - Clear feedback and options
4. **Flexible** - Power users can override if needed
5. **Safe** - Errors don't block legitimate operations

---

*Estimated time: 30-60 minutes*
*Ready to implement!*
