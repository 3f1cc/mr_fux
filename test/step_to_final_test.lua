-- test/step_to_final_test.lua
-- Unit tests for the "step-to-final" melodic rule.
--
-- Rule: the final note must be approached by stepwise motion
-- (≤ 2 chromatic semitones) in either voice.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local step_to_final_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "step-to-final" then
    step_to_final_rule = r
    break
  end
end
assert(step_to_final_rule, "step-to-final rule not found")

local function check_step_to_final(cf, cp, length)
  return step_to_final_rule.check(cf, cp, length)
end

TestStepToFinal = {}

function TestStepToFinal.test_semitone_approach_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 61}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "semitone approach to final should be accepted")
end

function TestStepToFinal.test_whole_tone_approach_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 62}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "whole-tone approach (2 st) to final should be accepted")
end

function TestStepToFinal.test_minor_third_approach_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 63}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "minor third approach (3 st) to final should be flagged")
  luaunit.assertEquals(v[1].step, 8)
  luaunit.assertEquals(v[1].voice, 1)
  luaunit.assertEquals(v[1].summary, "leap to final")
end

function TestStepToFinal.test_descending_minor_third_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 63, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "descending minor third to final should be flagged")
end

function TestStepToFinal.test_leap_in_cp_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 63}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "leap to final in CP should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestStepToFinal.test_both_voices_leap_to_final()
  local cf = {60, 60, 60, 60, 60, 60, 60, 63}
  local cp = {60, 60, 60, 60, 60, 60, 60, 63}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "both voices leaping to final should produce 2 violations")
end

function TestStepToFinal.test_empty_penultimate_cf_skipped()
  local cf = {60, 60, 60, 60, 60, 60, 0, 63}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "leap to final with empty penultimate CF should be skipped")
end

function TestStepToFinal.test_empty_final_cf_skipped()
  local cf = {60, 60, 60, 60, 60, 60, 60, 0}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "final note empty should not be checked")
end

function TestStepToFinal.test_interior_leap_not_flagged()
  local cf = {60, 63, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "interior leap should not be flagged (rule only checks final step)")
end

function TestStepToFinal.test_octave_leap_to_final_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 72}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_step_to_final(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "octave leap to final should be flagged")
end
