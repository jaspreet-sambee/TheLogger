# Bodyweight & Time-Based Exercise Logging

## Current Approach

The app logs sets with **reps** and **weight** only (`WorkoutSet` model). There is no separate duration or time field.

### Reps-Based Bodyweight Exercises (works today)

For exercises like crunches, sit-ups, push-ups, leg raises, etc.:
- **Weight:** Leave at 0 (or user can enter 0)
- **Reps:** Enter the rep count

The UI shows weight; for weight = 0 it typically displays "0 lbs" or similar. PR logic skips sets with weight ≤ 0, which is correct for bodyweight exercises.

### Time-Based Exercises (workaround)

For planks, hollow holds, L-sits, etc., there is no duration field. Options:

1. **Use reps as seconds:** Log "60 reps" = 60-second plank. Works but is unintuitive.
2. **Use reps as approximate:** "1 rep" = 1 set held for X seconds (user remembers).
3. **Future:** Add optional `durationSeconds` to `WorkoutSet`; when set, show "0:60" instead of "60 reps" for display. Reps could stay 0 or be ignored.

## Future Considerations

- **Duration field:** Add `durationSeconds: Int?` to WorkoutSet; when non-nil, display time instead of reps.
- **Exercise type flag:** Mark exercises as reps-based vs time-based in the library; UI could show a time picker for time-based.
- **Bodyweight toggle:** Per-exercise or per-set flag to hide/minimize weight input for bodyweight movements.
