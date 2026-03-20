-- test/parallel_fifths_test.lua
-- Unit tests for the "parallel-fifths" counterpoint rule.
--
-- Rule: two consecutive steps both with ic=7 (perfect fifth) where motion
-- is NOT contrary (i.e., both voices in same direction or one static)
-- constitute parallel fifths.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local parallel_fifths_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "parallel-fifths" then
    parallel_fifths_rule = r
    break
  end
end
assert(parallel_fifths_rule, "parallel-fifths rule not found")

local function check_parallel_fifths(cf, cp, length)
  return parallel_fifths_rule.check(cf, cp, length)
end

TestParallelFifths = {}

function TestParallelFifths.test_both_ascend_to_fifth()
  -- Step 1: CF=60, CP=67 (fifth)
  -- Step 2: CF=62, CP=69 (fifth, both ascended)
  local cf = {60, 62, 64, 64, 64, 64, 64, 64}
  local cp = {67, 69, 72, 72, 72, 72, 72, 72}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "parallel fifths (similar motion) should be flagged")
  luaunit.assertEquals(v[1].step, 2)
end

function TestParallelFifths.test_both_descend_to_fifth()
  -- Both voices descend from fifth to fifth
  local cf = {62, 60, 58, 58, 58, 58, 58, 58}
  local cp = {69, 67, 64, 64, 64, 64, 64, 64}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "parallel fifths (both descend) should be flagged")
end

function TestParallelFifths.test_contrary_motion_to_fifth_accepted()
  -- CF ascends, CP descends, both arrive at fifth
  local cf = {60, 62, 60, 60, 60, 60, 60, 60}
  local cp = {69, 67, 60, 60, 60, 60, 60, 60}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "contrary motion to fifth should be accepted")
end

function TestParallelFifths.test_oblique_to_fifth_rejected()
  -- CF stays, CP ascends (oblique motion) to fifth → flagged
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 65, 67, 67, 69, 69, 69, 69}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "oblique motion to fifth should be flagged")
end

function TestParallelFifths.test_fifth_to_third()
  -- Step 1: fifth (CF=60, CP=67)
  -- Step 2: third (CF=62, CP=65) — not a fifth
  local cf = {60, 62, 64, 64, 64, 64, 64, 64}
  local cp = {67, 65, 63, 63, 63, 63, 63, 63}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "fifth followed by non-fifth should be accepted")
end

function TestParallelFifths.test_third_to_fifth()
  -- Step 1: third (CF=60, CP=65)
  -- Step 2: fifth (CF=62, CP=69) — first not a fifth
  local cf = {60, 62, 60, 60, 60, 60, 60, 60}
  local cp = {65, 69, 60, 60, 60, 60, 60, 60}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "non-fifth followed by fifth should be accepted")
end

function TestParallelFifths.test_three_consecutive_fifths()
  -- All fifths, all ascending
  local cf = {60, 62, 64, 72, 72, 72, 72, 72}
  local cp = {67, 69, 71, 80, 80, 80, 80, 80}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "three consecutive fifths should produce 2 violations (steps 2 and 3)")
end

function TestParallelFifths.test_empty_note_skipped()
  local cf = {60, 0, 62, 64, 72, 72, 72, 72}
  local cp = {67, 67, 69, 72, 80, 80, 80, 80}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "parallel fifths with empty note should be skipped")
end

function TestParallelFifths.test_related_field_has_three_entries()
  local cf = {60, 62, 64, 64, 64, 64, 64, 64}
  local cp = {67, 69, 72, 72, 72, 72, 72, 72}
  local v = check_parallel_fifths(cf, cp, 8)
  luaunit.assertEquals(#v[1].related, 3, "related field should have 3 entries")
end
