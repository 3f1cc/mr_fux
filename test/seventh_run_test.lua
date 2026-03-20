-- test/seventh_run_test.lua
-- Unit tests for the "seventh-run" melodic rule (advisory).
--
-- Rule: a monotonic run of notes all moving in the same direction
-- that spans >= 10 semitones (a minor seventh or larger) triggers
-- an advisory violation at the note that pushes over the threshold.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local seventh_run_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "seventh-run" then
    seventh_run_rule = r
    break
  end
end
assert(seventh_run_rule, "seventh-run rule not found")

local function check_seventh_run(cf, cp, length)
  return seventh_run_rule.check(cf, cp, length)
end

-- Filter violations to only those from seventh-run rule
local function filter_seventh_run(violations)
  local result = {}
  for _, v in ipairs(violations) do
    if v.summary and v.summary:match("7th in run") then
      table.insert(result, v)
    end
  end
  return result
end

TestSeventhRun = {}

function TestSeventhRun.test_ascending_run_9_semitones_accepted()
  -- Ascending run spanning exactly 9 semitones (major 6th) — accepted
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  local cf = {60, 62, 64, 66, 68, 69, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "ascending run of 9 semitones should be accepted")
end

function TestSeventhRun.test_ascending_run_10_semitones_rejected()
  -- Ascending run spanning 10 semitones (minor 7th)
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Padding continues upward so the return jump doesn't create a second 10st descending run
  local cf = {60, 62, 64, 66, 68, 70, 71, 72}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "ascending run of 10 semitones should be flagged")
  luaunit.assertEquals(v[1].step, 6)
  luaunit.assertEquals(v[1].summary, "* 7th in run")
end

function TestSeventhRun.test_ascending_run_11_semitones_rejected()
  -- Ascending run spanning 11 semitones (major 7th)
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Padding continues upward so the return jump doesn't create a second 10st+ descending run
  local cf = {60, 62, 64, 66, 68, 71, 72, 73}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "ascending run of 11 semitones should be flagged")
end

function TestSeventhRun.test_ascending_run_12_semitones_rejected()
  -- Ascending run spanning 12 semitones (octave)
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Padding continues upward so the return jump doesn't create a second 10st+ descending run
  local cf = {60, 62, 64, 66, 68, 72, 73, 74}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "ascending run of 12 semitones should be flagged")
end

function TestSeventhRun.test_direction_change_resets_run()
  -- Ascending run then descending (direction change)
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  local cf = {60, 62, 64, 66, 64, 62, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "direction change should reset run, preventing violation")
end

function TestSeventhRun.test_ascending_reaches_threshold_then_continues()
  -- Ascending run reaches 10 semitones at step 6, then continues to 12
  -- After flagging at step 6, run_start resets to 6, so 60->72 is not reflagged
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Padding continues upward so the return jump doesn't create a second 10st+ descending run
  local cf = {60, 62, 64, 66, 68, 70, 72, 73}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  -- Span 60->70 at step 6: 10 semitones, flagged. Then run_start=6.
  -- Span 70->72 at step 7: 2 semitones from new run_start, not flagged.
  luaunit.assertEquals(#v, 1, "seventh run should flag only at threshold crossing")
  luaunit.assertEquals(v[1].step, 6)
end

function TestSeventhRun.test_descending_run_10_semitones()
  -- Descending run spanning 10 semitones
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  local cf = {72, 70, 68, 66, 64, 62, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "descending run of 10 semitones should be flagged")
end

function TestSeventhRun.test_run_in_cp_voice()
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Padding continues CP upward so the return jump doesn't create a second 10st+ descending run
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 62, 64, 66, 68, 70, 71, 72}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "seventh run in CP should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestSeventhRun.test_empty_note_resets_run()
  -- Run of 5 ascending notes, empty note, then 5 more ascending
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  local cf = {60, 62, 64, 66, 68, 0, 60, 62}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  -- First run: 60->68 = 8 semitones (< 10, ok)
  -- Empty note at step 6, resets run
  -- Second run: 60->62 = 2 semitones (< 10, ok)
  luaunit.assertEquals(#v, 0, "empty note should reset run, preventing violation")
end

function TestSeventhRun.test_stationary_note_resets_direction()
  -- Run upward, then note stays at same pitch (d=0)
  -- Narrowed to test seventh-run rule only; filter out violations from other rules
  -- Padding continues upward so the return jump doesn't create a 10st+ descending run
  local cf = {60, 62, 64, 66, 66, 68, 70, 71}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_seventh_run(check_seventh_run(cf, cp, 8))
  -- At step 5, d=0 (no motion), run resets; steps 6-8 fresh ascending run (68->71, span=3, < 10)
  luaunit.assertEquals(#v, 0, "stationary note should reset run")
end
