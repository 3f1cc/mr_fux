-- test/large_leap_test.lua
-- Unit tests for the "large-leap" melodic rule.
--
-- Rule: a leap larger than one octave (> 12 chromatic semitones)
-- between consecutive non-zero notes is forbidden in either voice.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local large_leap_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "large-leap" then
    large_leap_rule = r
    break
  end
end
assert(large_leap_rule, "large-leap rule not found")

local function check_large_leap(cf, cp, length)
  return large_leap_rule.check(cf, cp, length)
end

TestLargeLeap = {}

function TestLargeLeap.test_octave_leap_accepted()
  -- Exactly 12 semitones (octave) is the boundary — should be accepted.
  local cf = {60, 72, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave leap (exactly 12 st) should be accepted")
end

function TestLargeLeap.test_leap_of_13_in_cf()
  -- 13 semitones in CF should be flagged.
  local cf = {60, 73, 72, 72, 72, 72, 72, 72}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "leap of 13 semitones in CF should be flagged")
  luaunit.assertEquals(v[1].step, 2)
  luaunit.assertEquals(v[1].voice, 1)
  luaunit.assertEquals(v[1].summary, "leap > 8ve")
  luaunit.assertEquals(v[1].related[1].step, 1)
  luaunit.assertEquals(v[1].related[1].voice, 1)
end

function TestLargeLeap.test_leap_of_13_in_cp()
  -- 13 semitones in CP should be flagged with voice=2.
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 73, 72, 72, 72, 72, 72, 72}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "leap of 13 semitones in CP should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestLargeLeap.test_both_voices_leap()
  -- Both voices leap > 12 st simultaneously.
  local cf = {60, 73, 72, 72, 72, 72, 72, 72}
  local cp = {60, 73, 72, 72, 72, 72, 72, 72}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "both voices leaping should produce 2 violations")
end

function TestLargeLeap.test_downward_leap_of_13()
  -- Downward leap (negative interval) should also be flagged (uses abs).
  local cf = {73, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "downward leap of 13 semitones should be flagged")
end

function TestLargeLeap.test_empty_previous_note_skipped()
  -- If previous note is 0 (empty), the leap check is skipped.
  local cf = {0, 73, 72, 72, 72, 72, 72, 72}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "leap from empty note should be skipped")
end

function TestLargeLeap.test_empty_arriving_note_skipped()
  -- If arriving note is 0, the leap check is skipped.
  local cf = {60, 0, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "leap to empty note should be skipped")
end

function TestLargeLeap.test_interior_leap_at_correct_step()
  -- Interior leap of 13 st should be flagged at the correct step.
  local cf = {60, 60, 60, 73, 72, 72, 72, 72}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 1)
  luaunit.assertEquals(v[1].step, 4)
end

function TestLargeLeap.test_leap_of_24_semitones()
  -- Two octaves (24 semitones) should definitely be flagged.
  local cf = {60, 84, 83, 83, 83, 83, 83, 83}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_large_leap(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "leap of 24 semitones should be flagged")
end
