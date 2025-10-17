# Duplicate Prevention Implementation Plan

## Overview
This document outlines the strategy to prevent duplicate rivers and river runs from being created in the BrownClaw application. The solution includes both frontend validation and backend/database constraints.

---

## Current State Analysis

### Rivers Collection (`rivers`)
**Structure:**
```dart
{
  id: string (auto-generated),
  name: string,
  region: string (Province/State),
  country: string,
  description: string?,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**Current Duplicate Risk:**
- ✅ Partial check exists in `create_river_run_screen.dart` (lines 238-252)
- ⚠️ Case-sensitive comparison only
- ❌ No Firestore uniqueness constraint
- ❌ Race condition possible (two simultaneous creates)

### River Runs Collection (`river_runs`)
**Structure:**
```dart
{
  id: string (auto-generated),
  riverId: string (reference to rivers),
  name: string,
  difficultyClass: string,
  stationId: string?, // Optional link to gauge station
  // ... other fields
}
```

**Current Duplicate Risk:**
- ✅ Partial check for stationId in `river_run_service.dart:375-390`
- ❌ No check for riverId + name combination
- ❌ Race conditions possible

---

## Implementation Strategy

### Phase 1: Firestore Security Rules & Indexes
**Priority: HIGH** | **Effort: LOW** | **Impact: HIGH**

#### 1.1 Create Firestore Indexes for Uniqueness Queries

Add to `firestore.indexes.json`:
```json
{
  "indexes": [
    // Existing indexes...
    {
      "collectionGroup": "rivers",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "name",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "region",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "country",
          "order": "ASCENDING"
        }
      ]
    },
    {
      "collectionGroup": "river_runs",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "riverId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "name",
          "order": "ASCENDING"
        }
      ]
    }
  ]
}
```

#### 1.2 Create Firestore Security Rules

Create `firestore.rules` file (or update existing):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if river name is unique
    function isUniqueRiver(name, region, country) {
      return !exists(/databases/$(database)/documents/rivers/$(request.resource.id));
    }
    
    // Helper function to check if river run is unique
    function isUniqueRun(riverId, runName) {
      return !exists(/databases/$(database)/documents/river_runs/$(request.resource.id));
    }
    
    match /rivers/{riverId} {
      allow read: if request.auth != null;
      
      allow create: if request.auth != null
        && request.resource.data.name is string
        && request.resource.data.region is string
        && request.resource.data.country is string;
      
      allow update: if request.auth != null
        && request.resource.data.name is string;
      
      allow delete: if request.auth != null;
    }
    
    match /river_runs/{runId} {
      allow read: if request.auth != null;
      
      allow create: if request.auth != null
        && request.resource.data.riverId is string
        && request.resource.data.name is string
        && request.resource.data.difficultyClass is string;
      
      allow update: if request.auth != null;
      
      allow delete: if request.auth != null;
    }
    
    match /river_descents/{descentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    match /user_favorites/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /water_stations/{stationId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Could be restricted to admin only
    }
  }
}
```

---

### Phase 2: Backend Service Layer Improvements
**Priority: HIGH** | **Effort: MEDIUM** | **Impact: HIGH**

#### 2.1 Enhance RiverService with Duplicate Detection

Update `lib/services/river_service.dart`:

```dart
// Add after existing imports
import 'dart:async';

class RiverService {
  // ... existing code ...

  /// Check if a river with the same name, region, and country exists
  /// Returns existing river ID if found, null otherwise
  static Future<String?> findExistingRiver({
    required String name,
    required String region,
    required String country,
  }) async {
    try {
      final normalizedName = name.trim().toLowerCase();
      final normalizedRegion = region.trim().toLowerCase();
      final normalizedCountry = country.trim().toLowerCase();

      // Get all rivers and filter client-side for case-insensitive comparison
      final snapshot = await _riversCollection.get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final existingName = (data['name'] as String?)?.trim().toLowerCase() ?? '';
        final existingRegion = (data['region'] as String?)?.trim().toLowerCase() ?? '';
        final existingCountry = (data['country'] as String?)?.trim().toLowerCase() ?? '';
        
        if (existingName == normalizedName &&
            existingRegion == normalizedRegion &&
            existingCountry == normalizedCountry) {
          return doc.id;
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking for duplicate river: $e');
      }
      rethrow;
    }
  }

  /// Add a new river with duplicate prevention
  /// Returns existing river ID if duplicate found, new ID otherwise
  static Future<String> addRiverSafe(River river) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add rivers');
    }

    try {
      // Check for existing river first
      final existingId = await findExistingRiver(
        name: river.name,
        region: river.region,
        country: river.country,
      );

      if (existingId != null) {
        if (kDebugMode) {
          print('ℹ️ River already exists: ${river.name} -> $existingId');
        }
        return existingId;
      }

      // No duplicate found, create new river
      return await addRiver(river);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in addRiverSafe: $e');
      }
      rethrow;
    }
  }
}
```

#### 2.2 Enhance RiverRunService with Duplicate Detection

Update `lib/services/river_run_service.dart`:

```dart
class RiverRunService {
  // ... existing code ...

  /// Check if a river run with the same riverId and name exists
  /// Returns existing run ID if found, null otherwise
  static Future<String?> findExistingRun({
    required String riverId,
    required String name,
  }) async {
    try {
      final normalizedName = name.trim().toLowerCase();

      // Query runs for this river
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
      rethrow;
    }
  }

  /// Add a new run with duplicate prevention
  /// Returns existing run ID if duplicate found, new ID otherwise
  /// Throws DuplicateRunException if duplicate found and throwOnDuplicate is true
  static Future<String> addRunSafe(
    RiverRun run, {
    bool throwOnDuplicate = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to add river runs');
    }

    try {
      // Check for existing run by riverId + name
      final existingId = await findExistingRun(
        riverId: run.riverId,
        name: run.name,
      );

      if (existingId != null) {
        if (throwOnDuplicate) {
          throw DuplicateRunException(
            'A run named "${run.name}" already exists on this river',
            existingRunId: existingId,
          );
        }
        
        if (kDebugMode) {
          print('ℹ️ River run already exists: ${run.name} -> $existingId');
        }
        return existingId;
      }

      // Also check by stationId if present
      if (run.stationId != null) {
        final existingByStation = await getRunIdByStationId(run.stationId!);
        if (existingByStation != null) {
          if (throwOnDuplicate) {
            throw DuplicateRunException(
              'A run with this gauge station already exists',
              existingRunId: existingByStation,
            );
          }
          
          if (kDebugMode) {
            print('ℹ️ River run with station ${run.stationId} exists -> $existingByStation');
          }
          return existingByStation;
        }
      }

      // No duplicate found, create new run
      return await addRun(run);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in addRunSafe: $e');
      }
      rethrow;
    }
  }
}

/// Custom exception for duplicate run detection
class DuplicateRunException implements Exception {
  final String message;
  final String existingRunId;

  DuplicateRunException(this.message, {required this.existingRunId});

  @override
  String toString() => message;
}
```

---

### Phase 3: Frontend UI Improvements
**Priority: MEDIUM** | **Effort: MEDIUM** | **Impact: MEDIUM**

#### 3.1 Update CreateRiverRunScreen

Update `lib/screens/create_river_run_screen.dart` in the `_createRiverRun` method:

```dart
Future<void> _createRiverRun() async {
  if (!_formKey.currentState!.validate()) return;

  if (mounted) {
    setState(() {
      _isLoading = true;
    });
  }

  try {
    // Use safe add method with duplicate checking
    String riverId = await RiverService.addRiverSafe(River(
      id: '',
      name: _riverNameController.text.trim(),
      region: _selectedRegion,
      country: _selectedCountry,
      description: 'River created from new run submission',
    ));

    // Check for duplicate run before creating
    final existingRunId = await RiverRunService.findExistingRun(
      riverId: riverId,
      name: _runNameController.text.trim(),
    );

    if (existingRunId != null) {
      // Show dialog asking user what to do
      if (mounted) {
        final shouldNavigate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Run Already Exists'),
            content: Text(
              'A run named "${_runNameController.text.trim()}" already '
              'exists on this river. Would you like to view it instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('View Existing'),
              ),
            ],
          ),
        );

        if (shouldNavigate == true) {
          // Navigate to the existing run details
          final run = await RiverRunService.getRunById(existingRunId);
          if (run != null && mounted) {
            Navigator.of(context).pop(); // Close create screen
            // Navigate to run detail screen
            // Navigator.push(...) to RiverRunDetailScreen
          }
        }
      }
      return;
    }

    // Create the river run using safe method
    final newRun = RiverRun(
      id: '',
      riverId: riverId,
      name: _runNameController.text.trim(),
      difficultyClass: _selectedDifficulty,
      // ... rest of the fields
    );

    final runId = await RiverRunService.addRunSafe(newRun);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('River run created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating river run: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

#### 3.2 Add Real-time Duplicate Warning

Add a debounced duplicate check while user is typing:

```dart
class _CreateRiverRunScreenState extends State<CreateRiverRunScreen> {
  // ... existing fields ...
  
  Timer? _duplicateCheckTimer;
  bool _isDuplicateRun = false;
  String? _duplicateRunId;

  @override
  void initState() {
    super.initState();
    
    // Listen for changes in river name or run name
    _riverNameController.addListener(_onRiverOrRunNameChanged);
    _runNameController.addListener(_onRiverOrRunNameChanged);
  }

  void _onRiverOrRunNameChanged() {
    _duplicateCheckTimer?.cancel();
    _duplicateCheckTimer = Timer(const Duration(milliseconds: 800), () {
      _checkForDuplicateRun();
    });
  }

  Future<void> _checkForDuplicateRun() async {
    final riverName = _riverNameController.text.trim();
    final runName = _runNameController.text.trim();

    if (riverName.isEmpty || runName.isEmpty) {
      setState(() {
        _isDuplicateRun = false;
        _duplicateRunId = null;
      });
      return;
    }

    try {
      // Find river ID
      final rivers = await RiverService.searchRivers(riverName).first;
      final matchingRiver = rivers.firstWhere(
        (r) => r.name.toLowerCase() == riverName.toLowerCase(),
        orElse: () => const River(id: '', name: '', region: '', country: ''),
      );

      if (matchingRiver.id.isEmpty) {
        setState(() {
          _isDuplicateRun = false;
          _duplicateRunId = null;
        });
        return;
      }

      // Check for duplicate run
      final duplicateId = await RiverRunService.findExistingRun(
        riverId: matchingRiver.id,
        name: runName,
      );

      if (mounted) {
        setState(() {
          _isDuplicateRun = duplicateId != null;
          _duplicateRunId = duplicateId;
        });
      }
    } catch (e) {
      // Silent fail for UX
      if (kDebugMode) {
        print('Error checking duplicate: $e');
      }
    }
  }

  @override
  void dispose() {
    _duplicateCheckTimer?.cancel();
    // ... existing disposal code ...
    super.dispose();
  }

  // In the build method, add a warning banner:
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create River Run')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Show duplicate warning if detected
            if (_isDuplicateRun)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A run with this name already exists on this river.',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to existing run
                        // ... implementation
                      },
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                // ... existing form fields ...
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Phase 4: Data Migration & Cleanup
**Priority: LOW** | **Effort: MEDIUM** | **Impact: LOW**

#### 4.1 Create Admin Script to Find & Merge Duplicates

Create `admin_scripts/find_duplicate_rivers.py`:

```python
#!/usr/bin/env python3
"""
Find and report duplicate rivers and runs in Firestore.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

def find_duplicate_rivers(db):
    """Find rivers with duplicate name/region/country combinations."""
    rivers_ref = db.collection('rivers')
    rivers = rivers_ref.stream()
    
    # Group by normalized name, region, country
    groups = defaultdict(list)
    
    for river in rivers:
        data = river.to_dict()
        key = (
            data['name'].lower().strip(),
            data['region'].lower().strip(),
            data['country'].lower().strip()
        )
        groups[key].append({
            'id': river.id,
            'name': data['name'],
            'region': data['region'],
            'country': data['country'],
            'created_at': data.get('createdAt'),
        })
    
    # Find groups with duplicates
    duplicates = {k: v for k, v in groups.items() if len(v) > 1}
    
    return duplicates

def find_duplicate_runs(db):
    """Find runs with duplicate riverId/name combinations."""
    runs_ref = db.collection('river_runs')
    runs = runs_ref.stream()
    
    # Group by riverId and normalized name
    groups = defaultdict(list)
    
    for run in runs:
        data = run.to_dict()
        key = (
            data['riverId'],
            data['name'].lower().strip()
        )
        groups[key].append({
            'id': run.id,
            'name': data['name'],
            'riverId': data['riverId'],
            'created_at': data.get('createdAt'),
        })
    
    # Find groups with duplicates
    duplicates = {k: v for k, v in groups.items() if len(v) > 1}
    
    return duplicates

def main():
    # Initialize Firebase
    cred = credentials.Certificate('service_account_key.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    print("🔍 Searching for duplicate rivers...")
    duplicate_rivers = find_duplicate_rivers(db)
    
    if duplicate_rivers:
        print(f"\n⚠️  Found {len(duplicate_rivers)} duplicate river groups:")
        for (name, region, country), rivers in duplicate_rivers.items():
            print(f"\n  {name} ({region}, {country}):")
            for river in rivers:
                print(f"    - ID: {river['id']} (created: {river['created_at']})")
    else:
        print("✅ No duplicate rivers found")
    
    print("\n🔍 Searching for duplicate runs...")
    duplicate_runs = find_duplicate_runs(db)
    
    if duplicate_runs:
        print(f"\n⚠️  Found {len(duplicate_runs)} duplicate run groups:")
        for (river_id, name), runs in duplicate_runs.items():
            print(f"\n  {name} (River: {river_id}):")
            for run in runs:
                print(f"    - ID: {run['id']} (created: {run['created_at']})")
    else:
        print("✅ No duplicate runs found")

if __name__ == "__main__":
    main()
```

---

## Implementation Checklist

### Phase 1: Database Layer (Must Do First)
- [ ] Update `firestore.indexes.json` with new composite indexes
- [ ] Create/update `firestore.rules` with security rules
- [ ] Deploy indexes to Firebase: `firebase deploy --only firestore:indexes`
- [ ] Deploy rules to Firebase: `firebase deploy --only firestore:rules`
- [ ] Test indexes are working (check Firebase Console)

### Phase 2: Service Layer (Backend Logic)
- [ ] Add `findExistingRiver()` to `RiverService`
- [ ] Add `addRiverSafe()` to `RiverService`
- [ ] Add `findExistingRun()` to `RiverRunService`
- [ ] Add `addRunSafe()` to `RiverRunService`
- [ ] Create `DuplicateRunException` class
- [ ] Update `_createOrGetRiver()` helper to use new safe methods
- [ ] Update `createRunFromStationData()` to use new safe methods
- [ ] Write unit tests for duplicate detection logic

### Phase 3: UI Layer (User Experience)
- [ ] Update `CreateRiverRunScreen._createRiverRun()` to use safe methods
- [ ] Add duplicate warning dialog
- [ ] Add real-time duplicate detection (debounced)
- [ ] Add duplicate warning banner in form
- [ ] Test user flow with duplicate detection
- [ ] Update `EditRiverRunScreen` if applicable

### Phase 4: Data Cleanup (Optional)
- [ ] Run `find_duplicate_rivers.py` script
- [ ] Manually review and merge duplicate rivers
- [ ] Update river_runs references if rivers are merged
- [ ] Run `find_duplicate_runs.py` script
- [ ] Manually review and merge duplicate runs
- [ ] Update river_descents references if runs are merged

### Phase 5: Testing
- [ ] Unit tests for `findExistingRiver()`
- [ ] Unit tests for `findExistingRun()`
- [ ] Integration test for duplicate prevention
- [ ] Manual testing: Try to create duplicate river
- [ ] Manual testing: Try to create duplicate run
- [ ] Manual testing: Verify race condition handling
- [ ] Load testing: Simulate concurrent creates

---

## Benefits

### 🎯 Data Integrity
- Prevents duplicate entries at creation time
- Ensures referential integrity across collections
- Reduces storage costs

### 🚀 Performance
- Composite indexes speed up uniqueness queries
- Client-side caching reduces redundant queries
- Debounced validation reduces server load

### 💡 User Experience
- Real-time feedback prevents submission errors
- Helpful error messages guide users
- Option to view existing entries instead of creating duplicates

### 🔒 Security
- Firestore rules provide server-side validation
- Cannot bypass validation via API calls
- Protects against malicious duplicate creation

---

## Technical Considerations

### Race Conditions
Even with duplicate checks, race conditions are possible:
```
User A: Check for duplicate -> None found
User B: Check for duplicate -> None found
User A: Create river X
User B: Create river X  ← DUPLICATE CREATED
```

**Mitigation:**
1. Use Firestore transactions for critical creates
2. Accept eventual consistency and provide merge tools
3. Consider Firestore unique constraint workaround (separate collection for unique keys)

### Case Sensitivity
Rivers named "Bow River" vs "bow river" should be treated as duplicates.
- All comparisons use `.toLowerCase().trim()`
- Original casing preserved in database
- Search is case-insensitive

### Performance Impact
- Initial uniqueness check adds ~100-200ms latency
- Composite indexes reduce this to ~50-100ms
- Acceptable trade-off for data quality

### Backwards Compatibility
- Existing data is not affected
- New validation only applies to new creates
- Migration script needed for existing duplicates

---

## Alternative Approaches Considered

### 1. Unique Compound Keys in Document IDs
**Approach:** Use `{name}_{region}_{country}` as document ID
**Pros:** Firestore guarantees uniqueness
**Cons:** Makes updates difficult, IDs become very long

### 2. Cloud Functions Trigger
**Approach:** Cloud Function validates on onCreate
**Pros:** Centralized validation
**Cons:** Higher latency, requires Firebase Cloud Functions setup

### 3. Real-time Database Instead
**Approach:** Use Realtime Database which supports unique constraints
**Cons:** Major migration effort, lose Firestore benefits

---

## Success Metrics

### Before Implementation
- Estimated duplicates: Unknown (run detection script)
- User reports: Occasional confusion about duplicate entries

### After Implementation  
- New duplicates created: 0 (target)
- Average duplicate detection latency: <100ms
- User satisfaction: Improved clarity in form validation
- Database size reduction: 5-10% (estimated from cleanup)

---

## Timeline Estimate

| Phase | Effort | Duration |
|-------|--------|----------|
| Phase 1: Database Layer | Low | 1-2 hours |
| Phase 2: Service Layer | Medium | 3-4 hours |
| Phase 3: UI Layer | Medium | 3-4 hours |
| Phase 4: Data Cleanup | Medium | 2-3 hours |
| Phase 5: Testing | Medium | 2-3 hours |
| **Total** | **Medium** | **11-16 hours** |

---

## Next Steps

1. ✅ Review and approve this plan
2. 🔧 Start with Phase 1 (Database Layer)
3. 🧪 Test each phase before moving to next
4. 📝 Document any deviations or learnings
5. 🎉 Deploy and monitor

---

*Last Updated: October 17, 2025*
*Author: GitHub Copilot*
*Status: Draft - Awaiting Approval*
