-- test/endpoints_test.lua
-- Unit tests for the "endpoints" counterpoint rule (summary: "imperfect end").
--
-- Rule (FS1 / AC1): the first and last vertical intervals must be perfect
-- consonances.  When CP is above CF, unison (ic=0), octave (ic=0), and fifth
-- (ic=7) are allowed.  When CP is below CF, only unison and octave (ic=0) are
-- allowed — a fifth is forbidden in that voicing.
--
-- MIDI pitch arithmetic is chromatic: one octave = 12 semitones.
-- The rule computes: ic = math.abs(cf - cp) % 12
-- so compound intervals reduce to the same ic as their simple equivalents
-- (e.g. a compound fifth at 19 semitones → ic 7, same as a simple fifth).
--
-- Terminology:
--   unison  — same MIDI pitch (e.g. both 60).        difference =  0, ic = 0
--   octave  — 12 semitones apart (e.g. 60 and 72).  difference = 12, ic = 0
--   fifth   — 7 semitones apart (e.g. 60 and 67).   difference =  7, ic = 7

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

-- Find the endpoints rule in the rules table.
local endpoints_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "endpoints" then
    endpoints_rule = r
    break
  end
end
assert(endpoints_rule, "endpoints rule not found in lib/rules")

-- Thin wrapper so tests read naturally.
local function check_endpoints(cf, cp, length)
  return endpoints_rule.check(cf, cp, length)
end

-- Build CF and CP tables of the given length.  Only the first and last
-- entries carry non-zero pitches; the interior is 0 so the endpoints rule
-- examines them in isolation.
-- `length` defaults to 8 when omitted.
local function make_voices(cf_first, cp_first, cf_last, cp_last, length)
  length = length or 8
  local cf, cp = {}, {}
  for i = 1, length do cf[i] = 0; cp[i] = 0 end
  cf[1]      = cf_first;  cp[1]      = cp_first
  cf[length] = cf_last;   cp[length] = cp_last
  return cf, cp
end

TestEndpoints = {}

-- ── Perfect consonances that must be accepted ────────────────────────────────

function TestEndpoints.test_unison_accepted()
  -- Unison: same MIDI pitch.  abs(60 - 60) % 12 = 0.
  local cf, cp = make_voices(60, 60, 60, 60)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "unison should be accepted at both endpoints")
end

function TestEndpoints.test_octave_above_accepted()
  -- Octave above: CP = CF + 12 semitones.  abs(72 - 60) % 12 = 0.
  -- An octave is NOT a unison — the two voices sound different pitches.
  local cf, cp = make_voices(60, 72, 60, 72)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave with CP above should be accepted")
end

function TestEndpoints.test_octave_below_accepted()
  -- Octave below: CP = CF - 12 semitones.  abs(48 - 60) % 12 = 0.
  local cf, cp = make_voices(60, 48, 60, 48)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave with CP below should be accepted")
end

function TestEndpoints.test_double_octave_accepted()
  -- Two octaves above: CP = CF + 24 semitones.  abs(84 - 60) % 12 = 0.
  -- The % 12 reduces a compound interval to the same ic as the simple interval.
  local cf, cp = make_voices(60, 84, 60, 84)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "double octave (24 semitones) should be accepted")
end

function TestEndpoints.test_fifth_cp_above_accepted()
  -- Perfect fifth above: CP = CF + 7 semitones.  abs(67 - 60) % 12 = 7.
  local cf, cp = make_voices(60, 67, 60, 67)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "fifth with CP above should be accepted")
end

function TestEndpoints.test_compound_fifth_cp_above_accepted()
  -- Compound fifth (12th): CP = CF + 19 semitones.  abs(79 - 60) % 12 = 7.
  -- The rule treats this as ic=7, the same as a simple fifth.
  local cf, cp = make_voices(60, 79, 60, 79)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "compound fifth (19 semitones) should be accepted")
end

-- ── Imperfect consonances and other intervals must be rejected ───────────────

function TestEndpoints.test_fifth_cp_below_rejected()
  -- Fifth below: abs(67 - 60) % 12 = 7, but CP (60) < CF (67) → rejected.
  -- When CP is below CF only unison / octave (ic = 0) are allowed.
  local cf, cp = make_voices(67, 60, 67, 60)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "fifth with CP below should be rejected at both endpoints")
  luaunit.assertEquals(v[1].summary, "imperfect end")
  luaunit.assertEquals(v[1].step, 1)
  luaunit.assertEquals(v[2].step, 8)
end

function TestEndpoints.test_major_third_rejected()
  -- Major third: CP = CF + 4 semitones.  abs(64 - 60) % 12 = 4.
  local cf, cp = make_voices(60, 64, 60, 64)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "major third should be rejected at both endpoints")
  luaunit.assertEquals(v[1].summary, "imperfect end")
end

function TestEndpoints.test_minor_third_rejected()
  -- Minor third: CP = CF + 3 semitones.  abs(63 - 60) % 12 = 3.
  local cf, cp = make_voices(60, 63, 60, 63)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "minor third should be rejected at both endpoints")
end

function TestEndpoints.test_compound_major_third_rejected()
  -- Compound major third (major 10th): CP = CF + 16 semitones.
  -- abs(76 - 60) % 12 = 4.  Same ic as a simple major third — rejected.
  local cf, cp = make_voices(60, 76, 60, 76)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "compound major third (16 semitones) should be rejected")
end

function TestEndpoints.test_sixth_rejected()
  -- Major sixth: CP = CF + 9 semitones.  abs(69 - 60) % 12 = 9.
  local cf, cp = make_voices(60, 69, 60, 69)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "major sixth should be rejected at both endpoints")
end

function TestEndpoints.test_dissonance_rejected()
  -- Major second: CP = CF + 2 semitones.  abs(62 - 60) % 12 = 2.
  local cf, cp = make_voices(60, 62, 60, 62)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "major second (dissonance) should be rejected at both endpoints")
end

function TestEndpoints.test_augmented_octave_rejected()
  -- Augmented octave: CP = CF + 13 semitones.  abs(73 - 60) % 12 = 1.
  -- Despite being "almost an octave", ic=1 (minor second) is rejected.
  local cf, cp = make_voices(60, 73, 60, 73)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "augmented octave (13 semitones, ic=1) should be rejected")
end

function TestEndpoints.test_diminished_octave_rejected()
  -- Diminished octave: CP = CF + 11 semitones.  abs(71 - 60) % 12 = 11.
  -- Despite being "almost an octave", ic=11 (major seventh) is rejected.
  local cf, cp = make_voices(60, 71, 60, 71)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "diminished octave (11 semitones, ic=11) should be rejected")
end

-- ── Mixed: valid start, invalid end ─────────────────────────────────────────

function TestEndpoints.test_valid_start_invalid_end()
  -- Start: unison (ok).  End: major third (violation).
  local cf, cp = make_voices(60, 60, 60, 64)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "only the end should be flagged")
  luaunit.assertEquals(v[1].step, 8)
end

function TestEndpoints.test_invalid_start_valid_end()
  -- Start: major third (violation).  End: fifth CP above (ok).
  local cf, cp = make_voices(60, 64, 60, 67)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "only the start should be flagged")
  luaunit.assertEquals(v[1].step, 1)
end

-- ── Interior notes are not checked ──────────────────────────────────────────

function TestEndpoints.test_interior_imperfect_intervals_ignored()
  -- Endpoints are perfect fifths (ok); interior steps are major thirds
  -- (imperfect, irrelevant to this rule).
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 64, 64, 64, 64, 64, 64, 67}
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "interior imperfect intervals should not trigger this rule")
end

-- ── Empty (zero) notes are skipped ──────────────────────────────────────────

function TestEndpoints.test_empty_cp_note_skipped()
  -- CP not yet entered (0); rule should not fire.
  local cf, cp = make_voices(60, 0, 60, 0)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "zero (empty) CP note should be skipped")
end

function TestEndpoints.test_empty_cf_note_skipped()
  -- CF not entered at endpoint (unusual but should not error).
  local cf, cp = make_voices(0, 60, 0, 60)
  local v = check_endpoints(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "zero (empty) CF note should be skipped")
end

-- ── Variable length ──────────────────────────────────────────────────────────

function TestEndpoints.test_length_4_endpoints_checked()
  -- With length=4 the last step is 4, not 8.
  -- make_voices places the last note at cf[length], not at cf[8].
  local cf, cp = make_voices(60, 67, 60, 64, 4)
  local v = check_endpoints(cf, cp, 4)
  luaunit.assertEquals(#v, 1, "only step 4 should be flagged")
  luaunit.assertEquals(v[1].step, 4)
end

function TestEndpoints.test_length_12_last_step_checked()
  -- With length=12 the last step is 12 (not 8 or any other diatonic count).
  local cf, cp = make_voices(60, 64, 60, 64, 12)
  local v = check_endpoints(cf, cp, 12)
  -- Both endpoints are major thirds (ic=4) — both should be flagged.
  local steps = {}
  for _, vi in ipairs(v) do steps[vi.step] = true end
  luaunit.assertTrue(steps[1],  "step 1 should be flagged for length=12")
  luaunit.assertTrue(steps[12], "step 12 should be flagged for length=12")
end
