# mr_fux — Android Port Implementation Brief

## What the Application Is

**mr_fux** is a first-species counterpoint exercise tool. The user enters two musical voices — a *cantus firmus* (CF) and a *counterpoint* (CP) — as sequences of notes on a grand staff, then requests feedback on rule violations according to species counterpoint theory.

It is currently a Lua script for the Monome Norns hardware synthesizer (128×64 OLED, 3 keys, 3 rotary encoders). The Android port should preserve all musical logic and the grand-staff visual metaphor, adapted to a touch screen with appropriate UI controls.

---

## Data Model

### Note sequences
- Two arrays of MIDI note numbers, each of length `LENGTH` (4–24, default 8):
  - `cantus[1..LENGTH]` — cantus firmus
  - `counterpoint[1..LENGTH]` — counterpoint voice
- `0` means "empty" (no note at that step).
- Pitch range: MIDI 36–84 (C2–C6).
- Notes are **diatonic only** — only natural pitch classes are allowed: C D E F G A B (MIDI pitch classes 0, 2, 4, 5, 7, 9, 11). No accidentals.

### Default cantus
Steps 1–8 initialized to MIDI notes: `{60, 62, 64, 65, 67, 65, 64, 62}` (C4, D4, E4, F4, G4, F4, E4, D4).

### Violations
A flat list of violation records. Each record:
```
{
  step:    int       // 1..LENGTH — the primary offending note
  voice:   int       // 1 = cantus firmus, 2 = counterpoint
  summary: String    // short description; "*" prefix = advisory only
  related: List<{step: int, voice: int}>  // contributing notes besides primary
}
```

---

## Coordinate System / Staff Layout

The grand staff has treble and bass clefs drawn on a 128×64 pixel canvas. Android should scale this to fill the screen while preserving proportions.

### Staff math (from `lib/staff.lua`)
- **`STEP = 2`** pixels per diatonic step (one line/space)
- **`MIDDLE_C_Y = 36`** — screen Y for middle C (the ledger line between the two staves)
- **`staff_y(pos)`** = `MIDDLE_C_Y - pos * STEP`
- **`midi_to_staff_pos(midi)`** — converts a MIDI number to a diatonic position relative to middle C (C4 = position 0):
  ```
  pc_to_dia = {C:0, C#:0, D:1, D#:1, E:2, F:3, F#:3, G:4, G#:4, A:5, A#:5, B:6}
  octave = floor(midi / 12) - 5
  pos = octave * 7 + pc_to_dia[midi % 12]
  ```

### Staff lines (diatonic positions relative to middle C)
- **Treble lines**: positions 2, 4, 6, 8, 10 (E4, G4, B4, D5, F5)
- **Bass lines**: positions −2, −4, −6, −8, −10 (A3, F3, D3, B2, G2)

### Note horizontal layout
- `NOTE_X0 = 10`, `NOTE_DX = 7` (narrow/default layout)
- `NOTE_X0 = 14`, `NOTE_DX = 14` (normal layout)
- X position of step `i`: `NOTE_X0 + (i - 1) * NOTE_DX - scroll_offset`
- Staff spans x=2 to x=126

### Scroll
When the sequence is longer than fits on screen, the view scrolls horizontally so the cursor column stays visible. Keep a `scroll_offset` (px) and clamp it so the cursor is always within `STAFF_X1 + margin` to `STAFF_X2 - margin`.

### Ledger lines
Drawn for any note outside the staff. Draw a short horizontal line at each even diatonic position between the outermost staff line and the note:
- Above treble (pos ≥ 12): draw at pos 12, 14, 16, ...
- Below bass (pos ≤ −12): draw at pos −12, −14, −16, ...
- Middle C (pos = 0): always draw a ledger line.

### Note head shapes
- **Cantus firmus**: filled square (3×3 px in narrow mode, 5×4 in normal)
- **Counterpoint**: X shape (two diagonal lines) in narrow mode; filled circle (r=2) in normal mode
- CP is drawn before CF so CF always paints on top.

---

## Brightness / Color Levels

The original uses a 0–15 grayscale. On Android use corresponding opacity or color intensity.

**Edit mode:**
- Active voice at cursor: level 15 (brightest)
- Inactive voice at cursor: level 11
- All other notes: level 7
- Note playing back: level 15
- Staff lines: level 1 (very dim)
- Cursor marker below bass staff: level 6

**Check mode:**
- Primary note at cursor with violation: level 15
- Primary note at cursor without violation: level 4
- Any note with a violation: level 11
- Related notes (from current issue's `related` list): flash between levels 6 and 12 (600ms period)
- All other notes: level 3

---

## Application Modes

### `MODE_EDIT` (default)
Normal note entry. Status bar shows `"CF"` or `"CP"` for the active voice, and `">"` when playing.

### `MODE_CHECK`
Entered by shift+K3. Runs all rules and displays violations. Status bar shows the current violation summary (e.g. `"parallel 5th"`) and, if multiple violations at the cursor, `"n/total"`.

### `MODE_CONFIRM_SAVE`
Overwrite confirmation dialog. Shows filename and options.

---

## Controls (Original Hardware → Android Mapping)

| Original | Function | Android suggestion |
|---|---|---|
| K1 held = shift | Modifier key | Long-press, or a toggle "shift" button |
| K2 | Toggle active voice (CF/CP) | Tap a "CF/CP" toggle button |
| K1+K2 | Solo-play active voice | Shift+tap CF/CP button |
| K3 | Start playback | Play button |
| K1+K3 | Enter/exit check mode | Check button or menu item |
| E1 (encoder 1) | Move cursor left/right | Tap a note column; or swipe/arrow buttons |
| E2 (encoder 2) | Change active voice pitch by diatonic step | Up/down pitch buttons or vertical swipe on note |
| E3 (encoder 3) | In edit: change CP pitch; in check: scroll issues | In check: left/right scroll through issues at cursor |

### Diatonic pitch stepping
When raising or lowering a note, skip chromatic (non-natural) pitches. Algorithm:
```java
int diatonicStep(int midi, int delta) {
    int n = midi;
    int dir = delta > 0 ? 1 : -1;
    Set<Integer> naturalPc = Set.of(0, 2, 4, 5, 7, 9, 11);
    for (int i = 0; i < Math.abs(delta); i++) {
        do { n += dir; } while (!naturalPc.contains(n % 12));
    }
    return Math.max(36, Math.min(84, n));
}
```

---

## Rule Engine

Located in `lib/rulesets/wikipedia.lua`. Re-implement each rule in Java. All rules follow the same interface:

```java
interface Rule {
    String name();
    String type(); // "melodic" or "counterpoint"
    List<Violation> check(int[] cf, int[] cp, int length);
}
```

### All rules in the "wikipedia" rule set:

**1. `large-leap` (melodic)**
Flag any consecutive interval > 12 semitones in either voice.
Violation at step `i`, related: `{i-1, same voice}`.

**2. `forbidden-interval` (melodic)**
Flag specific melodic interval sizes (both voices):
- 6 semitones: "tritone leap"
- 9 semitones: "maj 6th leap"
- 10 semitones: "min 7th leap"
- 11 semitones: "maj 7th leap"

**3. `step-to-final` (melodic)**
The last note of each voice must be approached by step (≤ 2 semitones).
Check only step `length` vs `length-1`.

**4. `tritone-outline` (melodic)**
Three consecutive notes where the span from first to third (mod 12) is 6, 10, or 11 semitones:
- 6: "tritone outline"
- 10 or 11: "7th outline"
Related: steps `i-2` and `i-1` in same voice.

**5. `dissonance` (counterpoint)**
Vertical interval class (mod 12) at any step that is in {1, 2, 5, 6, 10, 11} is dissonant.
Violation on voice 2 (CP), related: `{step i, voice 1}`.

**6. `parallel-fifths` (counterpoint)**
Both consecutive intervals are 7 semitones (mod 12), and motion is NOT contrary.
Contrary motion: CF and CP move in opposite directions.
Violation on voice 2, related: `{i-1,1}, {i-1,2}, {i,1}`.

**7. `parallel-octaves` (counterpoint)**
Both consecutive intervals are 0 semitones (mod 12), not contrary motion.
Same structure as parallel fifths.

**8. `endpoints` (counterpoint)**
First and last steps must be perfect consonances:
- If CP is above CF: interval class 0 (unison/octave) or 7 (fifth) is OK.
- If CP is below CF: only interval class 0 is OK.
Violation: "imperfect end" on voice 2.

**9. `no-interior-unison` (counterpoint)**
Steps 2 through `length-1`: CF and CP must not have the same MIDI note.
Violation: "interior unison" on voice 2.

**10. `wide-spacing` (counterpoint)**
`|cf[i] - cp[i]| > 16` semitones (more than a major tenth).
Violation: "spacing > 10th" on voice 2.

**11. `hidden-parallel` (counterpoint)**
Approaching a perfect consonance (IC 0 or 7) by similar motion (both voices move in same direction).
- IC 0: "hidden 8ve"
- IC 7: "hidden 5th"
Related: `{i-1,1}, {i-1,2}, {i,1}`.

**12. `similar-skip` (counterpoint)**
Both voices skip (|interval| ≥ 3 semitones) in the same direction simultaneously.
Violation: "similar skip" on voice 2, related: `{i-1,1}, {i-1,2}, {i,1}`.

**13. `minor-sixth-resolve` (melodic)**
An ascending minor sixth (exactly +8 semitones) must be followed by downward motion.
If `notes[i+1] >= notes[i]` after ascending m6: "min 6th unresolved".
Violation at step `i+1`, related: `{i-1, voice}, {i, voice}`.

**14. `skip-order` (melodic)**
For three consecutive notes where both consecutive intervals are same-direction skips (3–5 semitones):
- (a) Second skip must be smaller in size than first: "skip not smaller"
- (b) Span from first to third (mod 12) must not be dissonant {1,2,5,6,10,11}: "dissonant skip span"
- (c) Span from first to third must not exceed 12 semitones: "skip span > 8ve"

Additionally (rule d), for four consecutive notes where all three intervals are same-direction skips (≥3): "3+ same-dir skips".

**15. `repeated-interval` (counterpoint)**
The same vertical interval class must not occur more than 3 times in a row.
From step 4 onward, if the current IC equals the previous 3: "interval 4+ in row".

**16. `post-skip-step` (melodic, advisory)**
After any skip (|interval| ≥ 3), the next motion should be a step (≤ 2 semitones) in the **opposite** direction. Summary: `"* no step-back"` (the `*` prefix marks it as advisory).
Violation at step `i+1`.

**17. `seventh-run` (melodic, advisory)**
A monotonic run of notes all moving in the same direction must not span ≥ 10 semitones from its start. Summary: `"* 7th in run"`.
Reset the run start and direction on any direction change or rest.

**18. `no-parallel-imperfect` (counterpoint, advisory)**
The entire exercise must contain at least one consecutive pair of imperfect consonances (parallel thirds or sixths; IC ∈ {3, 4, 8, 9}).
If none found: violation at the last step, voice 2, `"* no 3rds/6ths"`.

### Advisory violations
Violations whose summary starts with `*` are advisory. You may choose to display these differently (e.g., with a different icon or dimmer color).

---

## Check Mode UI Behavior

1. On entering check mode, run all rules immediately.
2. The cursor navigates to steps; `check_issue_idx` selects which violation at that (step, voice) is displayed (when multiple violations exist at the same note).
3. Status bar shows: current violation summary, and `"n/total"` if multiple at cursor.
4. Flash animation: related notes cycle between two brightness levels at ~600ms intervals.
5. Changing the active voice resets `check_issue_idx` to 1.

---

## Audio

Original uses `PolyPerc` engine. For Android:
- Use Android's `ToneGenerator`, `AudioTrack`, or a library like **MIDI driver** or **Oboe** to play sine/bell tones.
- Convert MIDI note number to frequency: `freq = 440.0 * 2^((midi - 69) / 12.0)`
- Playback is step-by-step at 0.5 seconds per step.
- Both voices play simultaneously at each step.
- "Solo" mode plays only one voice (CF or CP).
- Playback stops after the last step (no loop).
- While playing, the playing column is highlighted at maximum brightness.

---

## File I/O (Save/Load)

Files saved as JSON with this structure:
```json
{
  "length": 8,
  "cantus": [60, 62, 64, 65, 67, 65, 64, 62, 0, 0, ...],
  "counterpoint": [67, 69, 71, 72, 74, 72, 71, 69, 0, 0, ...],
  "violations": [
    { "step": 3, "voice": 2, "summary": "dissonance", "related": [{"step":3,"voice":1}] }
  ]
}
```
Arrays are always length 24 (MAX_LENGTH), padded with 0 for unused steps. Store files in Android's app-specific storage directory.

**Overwrite confirmation**: if a file already exists with the given name, show a confirmation dialog before overwriting.

---

## Parameters / Settings

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| `length` | int | 4–24 | 8 | Number of steps in the exercise |
| `layout` | enum | normal, narrow | narrow | Note spacing; narrow = NOTE_DX 7px, normal = NOTE_DX 14px |
| `ruleset` | enum | "wikipedia" | "wikipedia" | Rule set to use |

Changing `length` clears violations and resets cursor. Changing `ruleset` also clears violations.

---

## Source Files to Reference

All rule logic is in `mr_fux/lib/rulesets/wikipedia.lua` — translate each rule function directly.

Staff math is in `mr_fux/lib/staff.lua` — `midi_to_staff_pos()` and `staff_y()`.

Main drawing and interaction logic is in `mr_fux/mr_fux.lua`.

Unit tests in `mr_fux/test/` cover each rule with named test cases — use these to validate your Java rule implementations produce correct violations.

---

## Suggested Android Architecture

- **`NoteSequenceModel`** — holds `cantus[]`, `counterpoint[]`, `LENGTH`, and `violations[]`; provides `diatonicStep()`, `runChecks()`, `saveToJson()`, `loadFromJson()`
- **`StaffView`** — custom `View` subclass; overrides `onDraw(Canvas)`; translates staff math to Android dp/px; handles tap-to-select-step and swipe-to-change-pitch gestures
- **`RuleEngine`** — collects all `Rule` implementations and returns flat `List<Violation>`
- **`PlaybackController`** — timer-based sequencer, fires at 500ms intervals
- **`MainActivity`** — wires everything together, hosts toolbar buttons for play/check/save/load
