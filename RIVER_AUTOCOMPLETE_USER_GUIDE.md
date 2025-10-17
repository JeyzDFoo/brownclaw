# River Name Auto-Suggest - User Guide

## What's New? 🎉

When creating a new logbook entry **or creating a new river run**, the River Name field now has **intelligent auto-suggestions** that help you find and select rivers quickly!

## Where to Find It

This feature is available in two places:
1. **Logbook Screen** → "+ Log River Descent" button → River Name field
2. **Admin/Create** → "Create New River Run" → River Name field

## How to Use

### Step 1: Start Typing
Simply start typing the name of a river in the "River Name" field.

```
River Name
┌─────────────────────────────────────────┐
│ Kick█                                   │ 
└─────────────────────────────────────────┘
```

### Step 2: See Suggestions
As you type, relevant suggestions appear below:

```
River Name
┌─────────────────────────────────────────┐
│ Kick█                                   │ 
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ ⌄ Kicking Horse River                   │
│   British Columbia, Canada              │
└─────────────────────────────────────────┘
```

### Step 3: Select a River
Tap on the river you want:

```
River Name                            ✓
┌─────────────────────────────────────────┐
│ Kicking Horse River                     │ 
└─────────────────────────────────────────┘
```

The green checkmark ✓ confirms your selection!

### Step 4: Automatic Benefits

**In Logbook Entry:**
- Runs for that river load automatically

**In Create River Run:**
- Region automatically fills (e.g., "British Columbia")
- Country automatically fills (e.g., "Canada")
- Gauge stations reload for that river

```
Section/Run
┌─────────────────────────────────────────┐
│ Select a run or search to filter...    │ 
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ ⌄ Upper Canyon - Class IV              │
│   Length: 8.5 km                        │
├─────────────────────────────────────────┤
│ ⌄ Middle Stretch - Class III           │
│   Length: 12.0 km                       │
├─────────────────────────────────────────┤
│ ⌄ Lower Gorge - Class V                │
│   Length: 6.0 km                        │
└─────────────────────────────────────────┘
```

## Benefits ✨

### 1. **Faster Entry**
- No need to type the complete river name
- Just a few characters and you're done!
- Example: "Kick" is enough to find "Kicking Horse River"
- **In Create Run**: Region and country auto-fill when selecting existing rivers!

### 2. **Accurate Names**
- All suggestions come from the database
- No typos or spelling mistakes
- Consistent naming across all entries

### 3. **Discovery**
- See what rivers are already in the system
- Learn the full, official names
- Find rivers in your region

### 4. **Better Data Quality**
- Prevents duplicate river entries
- Links properly to existing river records
- Maintains database integrity
- **In Create Run**: Encourages reuse of existing river records instead of creating duplicates

## Tips & Tricks 💡

### Tip 1: Start Small
You don't need to type much! Try just 3-4 letters:
- "ott" → Ottawa River
- "fras" → Fraser River
- "bow" → Bow River

### Tip 2: Location Hints
Suggestions show the region and country to help you pick the right river:
```
Bow River - Alberta, Canada
Bow River - Washington, USA
```

### Tip 3: Changing Your Mind
If you select the wrong river, just start typing again. The selection clears automatically when you modify the text.

### Tip 4: Mobile-Friendly
The dropdown is optimized for mobile devices with:
- Scrollable list for many results
- Touch-friendly tap targets
- Clear, readable text

## Examples

### Example 1: Finding a Popular River
```
You type: "kick"
You see:  "Kicking Horse River - British Columbia, Canada"
You tap:  Selection confirmed ✓
```

### Example 2: Similar Names
```
You type: "salmon"
You see:  
  - Salmon River - British Columbia, Canada
  - Salmon River - New Brunswick, Canada
  - Salmon River - Idaho, USA
You tap:  Your preferred Salmon River
```

### Example 3: Region Search
```
You type: "ottawa"
You see:  "Ottawa River - Ontario/Quebec, Canada"
You tap:  Selection confirmed ✓
Then:     
  - Logbook: Runs load automatically
  - Create Run: Region/Country auto-fill
```

### Example 4: Creating a Run for Existing River
```
You type: "kick"
You see:  "Kicking Horse River - British Columbia, Canada"
You tap:  Selection confirmed ✓
Result:
  ✓ Region: British Columbia (auto-filled)
  ✓ Country: Canada (auto-filled)
  ✓ Gauge stations reload for this river
```

## Technical Details

### Matching Algorithm
- **Case-insensitive**: "KICK", "kick", "Kick" all work
- **Partial match**: Searches anywhere in the name
- **Real-time**: Updates as you type

### Performance
- **Fast queries**: Results appear quickly
- **Smart loading**: Only queries when needed
- **Efficient**: Uses existing database infrastructure

### Data Source
All suggestions come from the `rivers` collection in the database, ensuring:
- ✓ Accurate information
- ✓ Consistent naming
- ✓ Up-to-date data

## Frequently Asked Questions

### Q: What if my river isn't in the list?
A: You can still type the full name manually. The system will create a new river entry if needed.

### Q: How many suggestions will I see?
A: The dropdown shows up to approximately 10-15 rivers at once. You can scroll if there are more matches.

### Q: Can I clear a selection?
A: Yes! Just start typing again or clear the field to start over.

### Q: Does this work offline?
A: The auto-suggest requires an internet connection to query the database. Offline support may be added in the future.

### Q: What happens if I select the wrong river?
A: No problem! Before submitting your entry, you can change the river by typing in the field again. Your run selection will automatically clear, allowing you to choose the correct river and run.

## Accessibility

The feature includes:
- ✓ Clear visual feedback (green checkmark)
- ✓ Helpful placeholder text
- ✓ Keyboard navigation support
- ✓ Screen reader compatible labels

## Related Features

This feature works together with:
- **Run Selection**: After choosing a river, pick a specific section/run
- **Water Level Data**: Automatically loads for the selected run
- **Edit Mode**: Suggestions work when editing existing entries
- **Favorites**: Prefilled runs from favorites work seamlessly

## Need Help?

If you encounter any issues:
1. Make sure you have an internet connection
2. Try typing more characters for better matches
3. Check that you're logged in
4. Restart the app if suggestions aren't appearing

---

**Happy paddling! 🛶**
