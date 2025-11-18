#!/usr/bin/env python3
"""
Validate that transformed JSON matches BrownClaw Dart model schemas.
Checks field names and types against expected Dart model structure.
"""

import json
import sys
from typing import Dict, Any, List

# Expected Dart model schemas (based on lib/models/*.dart)
# Note: Dart's fromMap() ignores extra fields, so we only validate REQUIRED fields
RIVER_SCHEMA = {
    'id': str,
    'name': str,
    'region': str,
    'country': str,
    # Optional fields - Dart model handles these
    'description': (str, type(None)),
    'createdAt': (str, type(None)),
    'updatedAt': (str, type(None)),
}

# Extra fields allowed (not in Dart model but ignored safely)
RIVER_EXTRA_ALLOWED = ['source', 'sourceUrl']

RIVER_RUN_SCHEMA = {
    'id': str,
    'riverId': str,
    'name': str,
    'difficultyClass': str,
    # Optional fields - Dart model handles these
    'description': (str, type(None)),
    'length': (int, float, type(None)),
    'putIn': (str, type(None)),
    'takeOut': (str, type(None)),
    'gradient': (int, float, str, type(None)),  # Can be string or number
    'season': (str, type(None)),
    'permits': (str, type(None)),
    'hazards': (list, type(None)),
    'minRecommendedFlow': (int, float, type(None)),
    'maxRecommendedFlow': (int, float, type(None)),
    'optimalFlowMin': (int, float, type(None)),
    'optimalFlowMax': (int, float, type(None)),
    'flowUnit': (str, type(None)),
    'stationId': (str, type(None)),  # Links to water_stations
    'createdBy': (str, type(None)),
    'createdAt': (str, type(None)),
    'updatedAt': (str, type(None)),
}

# Extra fields allowed (not in Dart model but ignored safely)
RIVER_RUN_EXTRA_ALLOWED = ['source', 'sourceUrl', 'shuttle', 'scoutingNotes', 
                            'coordinates', 'timeMin', 'timeMax']

def check_type(value: Any, expected_types) -> bool:
    """Check if value matches expected type(s)."""
    if not isinstance(expected_types, tuple):
        expected_types = (expected_types,)
    return isinstance(value, expected_types)

def validate_document(doc: Dict, schema: Dict, extra_allowed: List[str], doc_type: str) -> List[str]:
    """Validate a single document against schema."""
    errors = []
    
    # Check for required fields (non-optional types)
    for field, field_type in schema.items():
        if type(None) not in (field_type if isinstance(field_type, tuple) else (field_type,)):
            # Required field
            if field not in doc:
                errors.append(f"❌ Missing required field: {field}")
            elif not check_type(doc[field], field_type):
                errors.append(f"❌ Invalid type for {field}: expected {field_type}, got {type(doc[field])}")
    
    # Check field types for present fields
    for field, value in doc.items():
        if field in schema:
            if not check_type(value, schema[field]):
                errors.append(f"❌ Invalid type for {field}: expected {schema[field]}, got {type(value)}")
        elif field not in extra_allowed:
            # Unknown field (not in schema or extra allowed)
            errors.append(f"⚠️  Extra field (will be ignored by Dart): {field}")
    
    return errors

def validate_collection(file_path: str, schema: Dict, extra_allowed: List[str], collection_name: str) -> bool:
    """Validate entire collection file."""
    print(f"\n{'='*60}")
    print(f"Validating {collection_name} against Dart model schema...")
    print(f"{'='*60}")
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {file_path}")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}")
        return False
    
    if not isinstance(data, list):
        print(f"❌ Expected list of documents, got {type(data)}")
        return False
    
    print(f"📊 Total documents: {len(data)}")
    
    # Validate each document
    all_errors = []
    warnings = []
    for i, doc in enumerate(data):
        errors = validate_document(doc, schema, extra_allowed, collection_name)
        # Separate critical errors from warnings
        critical = [e for e in errors if e.startswith('❌')]
        warning = [e for e in errors if e.startswith('⚠️')]
        
        if critical:
            all_errors.append((i, doc.get('id', 'unknown'), critical))
        if warning:
            warnings.append((i, doc.get('id', 'unknown'), warning))
    
    # Report results
    if all_errors:
        print(f"\n❌ Validation FAILED: {len(all_errors)}/{len(data)} documents have critical errors")
        print("\nShowing first 5 critical errors:")
        for i, doc_id, errors in all_errors[:5]:
            print(f"\n  Document [{i}] {doc_id}:")
            for error in errors[:3]:  # Show max 3 errors per doc
                print(f"    {error}")
        
        if len(all_errors) > 5:
            print(f"\n  ... and {len(all_errors) - 5} more documents with errors")
        return False
    else:
        print(f"✅ Validation PASSED: All {len(data)} documents are valid")
        
        if warnings:
            print(f"\n⚠️  Note: {len(warnings)} documents have extra fields (will be ignored by Dart)")
            if len(warnings) <= 3:
                for i, doc_id, warns in warnings[:3]:
                    print(f"  {doc_id}: {', '.join([w.split(': ')[1] for w in warns])}")
        
        # Show sample document
        print("\n📄 Sample document structure:")
        sample = data[0].copy()
        sample['id'] = f"{sample['id']}"
        print(json.dumps(sample, indent=2)[:500] + "...")
        
        # Show field coverage
        print(f"\n📋 Field usage statistics:")
        field_counts = {}
        for doc in data:
            for field in doc.keys():
                field_counts[field] = field_counts.get(field, 0) + 1
        
        for field, count in sorted(field_counts.items()):
            percentage = (count / len(data)) * 100
            required = " (required)" if field in schema and type(None) not in (schema[field] if isinstance(schema[field], tuple) else (schema[field],)) else ""
            print(f"  {field}: {count}/{len(data)} ({percentage:.1f}%){required}")
        
        return True

def main():
    print("🔍 BrownClaw Dart Model Validation Tool")
    
    # Validate rivers
    rivers_valid = validate_collection(
        'run_data/firestore_import/rivers.json',
        RIVER_SCHEMA,
        RIVER_EXTRA_ALLOWED,
        'River'
    )
    
    # Validate river_runs
    runs_valid = validate_collection(
        'run_data/firestore_import/river_runs.json',
        RIVER_RUN_SCHEMA,
        RIVER_RUN_EXTRA_ALLOWED,
        'RiverRun'
    )
    
    # Final summary
    print("\n" + "="*60)
    print("VALIDATION SUMMARY")
    print("="*60)
    print(f"River model: {'✅ PASS' if rivers_valid else '❌ FAIL'}")
    print(f"RiverRun model: {'✅ PASS' if runs_valid else '❌ FAIL'}")
    
    if rivers_valid and runs_valid:
        print("\n✅ All data is compatible with Dart models!")
        print("\nReady to upload with:")
        print("  python3 python_scripts/upload_to_firestore.py --dry-run")
        return 0
    else:
        print("\n❌ Fix validation errors before uploading")
        return 1

if __name__ == "__main__":
    sys.exit(main())
