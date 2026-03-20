-- test/dissonance_test.lua
-- Unit tests for the "dissonance" counterpoint rule.
--
-- Rule: dissonant vertical interval classes must not occur.
-- Dissonant ic values: 1 (m2), 2 (M2), 5 (P4), 6 (tritone), 10 (m7), 11 (M7).

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local dissonance_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "dissonance" then
    dissonance_rule = r
    break
  end
end
assert(dissonance_rule, "dissonance rule not found")

local function check_dissonance(cf, cp, length)
  return dissonance_rule.check(cf, cp, length)
end

TestDissonance = {}

function TestDissonance.test_minor_second_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {61, 61, 61, 61, 61, 61, 61, 61}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "minor 2nd (ic=1) should be flagged at all steps")
  luaunit.assertEquals(v[1].summary, "dissonance")
end

function TestDissonance.test_major_second_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {62, 62, 62, 62, 62, 62, 62, 62}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "major 2nd (ic=2) should be flagged")
end

function TestDissonance.test_perfect_fourth_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {65, 65, 65, 65, 65, 65, 65, 65}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "perfect 4th (ic=5) should be flagged")
end

function TestDissonance.test_tritone_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {66, 66, 66, 66, 66, 66, 66, 66}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "tritone (ic=6) should be flagged")
end

function TestDissonance.test_minor_seventh_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {70, 70, 70, 70, 70, 70, 70, 70}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "minor 7th (ic=10) should be flagged")
end

function TestDissonance.test_major_seventh_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {71, 71, 71, 71, 71, 71, 71, 71}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "major 7th (ic=11) should be flagged")
end

function TestDissonance.test_unison_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "unison (ic=0) should be accepted")
end

function TestDissonance.test_minor_third_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {63, 63, 63, 63, 63, 63, 63, 63}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "minor 3rd (ic=3) should be accepted")
end

function TestDissonance.test_major_third_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {64, 64, 64, 64, 64, 64, 64, 64}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "major 3rd (ic=4) should be accepted")
end

function TestDissonance.test_perfect_fifth_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 67, 67, 67}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "perfect 5th (ic=7) should be accepted")
end

function TestDissonance.test_minor_sixth_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {68, 68, 68, 68, 68, 68, 68, 68}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "minor 6th (ic=8) should be accepted")
end

function TestDissonance.test_major_sixth_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {69, 69, 69, 69, 69, 69, 69, 69}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "major 6th (ic=9) should be accepted")
end

function TestDissonance.test_octave_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {72, 72, 72, 72, 72, 72, 72, 72}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave (ic=0) should be accepted")
end

function TestDissonance.test_compound_minor_second_rejected()
  -- 60 and 73: |73-60|=13, 13%12=1 (minor 2nd)
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {73, 73, 73, 73, 73, 73, 73, 73}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 8, "compound minor 2nd (ic=1) should be flagged")
end

function TestDissonance.test_empty_cf_skipped()
  local cf = {0, 60, 60, 60, 60, 60, 60, 60}
  local cp = {61, 61, 61, 61, 61, 61, 61, 61}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 7, "empty CF note should skip that step")
end

function TestDissonance.test_empty_cp_skipped()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {0, 61, 61, 61, 61, 61, 61, 61}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(#v, 7, "empty CP note should skip that step")
end

function TestDissonance.test_violation_voice_is_2()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {61, 61, 61, 61, 61, 61, 61, 61}
  local v = check_dissonance(cf, cp, 8)
  luaunit.assertEquals(v[1].voice, 2, "dissonance violations always report voice=2")
end
