-- test/hidden_parallel_test.lua
-- Unit tests for the "hidden-parallel" counterpoint rule.
--
-- Rule: approaching a perfect consonance (ic=0 or ic=7) by similar motion
-- (both voices in the same direction) is forbidden.
-- Oblique or contrary motion is acceptable.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local hidden_parallel_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "hidden-parallel" then
    hidden_parallel_rule = r
    break
  end
end
assert(hidden_parallel_rule, "hidden-parallel rule not found")

local function check_hidden_parallel(cf, cp, length)
  return hidden_parallel_rule.check(cf, cp, length)
end

-- Filter violations to only those from hidden-parallel rule
local function filter_hidden_parallel(violations)
  local result = {}
  for _, v in ipairs(violations) do
    if v.summary and (v.summary:match("hidden 5th") or v.summary:match("hidden 8ve")) then
      table.insert(result, v)
    end
  end
  return result
end

TestHiddenParallel = {}

function TestHiddenParallel.test_both_ascend_to_fifth()
  -- Step 1: CF=60, CP=67 (fifth)
  -- Step 2: CF=62, CP=69 (fifth, both ascended)
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 62, 64, 64, 64, 64, 64, 64}
  local cp = {67, 69, 72, 72, 72, 72, 72, 72}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "similar motion to fifth should be flagged")
  if #v > 0 then luaunit.assertEquals(v[1].summary, "hidden 5th") end
end

function TestHiddenParallel.test_both_descend_to_fifth()
  -- Both voices descend, both arrive at fifth
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {62, 60, 58, 58, 58, 58, 58, 58}
  local cp = {69, 67, 64, 64, 64, 64, 64, 64}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "both voices descend to fifth should be flagged")
end

function TestHiddenParallel.test_contrary_motion_to_fifth()
  -- CF ascends, CP descends, both arrive at fifth
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 62, 64, 64, 64, 64, 64, 64}
  local cp = {69, 67, 65, 65, 65, 65, 65, 65}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "contrary motion to fifth should be accepted")
end

function TestHiddenParallel.test_both_ascend_to_octave()
  -- Both voices ascend, both arrive at unison/octave
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 62, 70, 70, 70, 70, 70, 70}
  local cp = {60, 62, 78, 78, 78, 78, 78, 78}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "similar motion to octave should be flagged")
  if #v > 0 then luaunit.assertEquals(v[1].summary, "hidden 8ve") end
end

function TestHiddenParallel.test_both_ascend_to_third()
  -- Both voices ascend to a third (ic=4, not perfect consonance)
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 62, 64, 64, 64, 64, 64, 64}
  local cp = {63, 65, 67, 67, 67, 67, 67, 67}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "similar motion to imperfect consonance should be accepted")
end

function TestHiddenParallel.test_oblique_to_fifth()
  -- CF stays, CP rises to fifth (oblique, not similar)
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 69, 71, 71, 71, 71, 71, 71}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "oblique motion to fifth should be accepted")
end

function TestHiddenParallel.test_empty_note_skipped()
  -- Empty CF at step 2 breaks the pair; steps 3-4 use contrary motion to avoid new violations
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 0, 62, 63, 63, 63, 63, 63}
  local cp = {67, 69, 67, 66, 66, 66, 66, 66}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "hidden parallel with empty note should be skipped")
end

function TestHiddenParallel.test_related_field_has_three_entries()
  -- Narrowed to test hidden-parallel rule only; filter out violations from other rules
  local cf = {60, 62, 60, 60, 60, 60, 60, 60}
  local cp = {67, 69, 60, 60, 60, 60, 60, 60}
  local v = filter_hidden_parallel(check_hidden_parallel(cf, cp, 8))
  luaunit.assertTrue(#v > 0, "should have violations")
  if #v > 0 then luaunit.assertEquals(#v[1].related, 3, "related field should have 3 entries") end
end
