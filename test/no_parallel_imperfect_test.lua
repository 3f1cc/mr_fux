-- test/no_parallel_imperfect_test.lua
-- Unit tests for the "no-parallel-imperfect" counterpoint rule (advisory).
--
-- Rule: the exercise must contain at least one consecutive pair of
-- imperfect consonances (ic in {3,4,8,9} — minor 3rd, major 3rd,
-- minor 6th, major 6th). If no such pair exists, a violation is placed
-- on the final note.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local no_parallel_imperfect_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "no-parallel-imperfect" then
    no_parallel_imperfect_rule = r
    break
  end
end
assert(no_parallel_imperfect_rule, "no-parallel-imperfect rule not found")

local function check_no_parallel_imperfect(cf, cp, length)
  return no_parallel_imperfect_rule.check(cf, cp, length)
end

TestNoParallelImperfect = {}

function TestNoParallelImperfect.test_two_consecutive_major_thirds()
  -- Two consecutive major thirds (ic=4)
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {64, 64, 64, 60, 60, 60, 60, 60}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "consecutive major thirds should prevent violation")
end

function TestNoParallelImperfect.test_two_consecutive_minor_thirds()
  -- Two consecutive minor thirds (ic=3)
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {63, 63, 63, 60, 60, 60, 60, 60}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "consecutive minor thirds should prevent violation")
end

function TestNoParallelImperfect.test_minor_third_major_sixth()
  -- Minor third then major sixth (both imperfect, consecutive)
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {63, 69, 60, 60, 60, 60, 60, 60}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "minor third followed by major sixth should prevent violation")
end

function TestNoParallelImperfect.test_only_perfect_intervals()
  -- All fifths (ic=7, perfect)
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 67, 67, 67}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "only perfect consonances should trigger violation")
  luaunit.assertEquals(v[1].step, 8)
  luaunit.assertEquals(v[1].voice, 2)
  luaunit.assertEquals(v[1].summary, "* no 3rds/6ths")
end

function TestNoParallelImperfect.test_alternating_imperfect_perfect()
  -- Alternating imperfect (third) and perfect (fifth) — no consecutive pair
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {64, 67, 64, 67, 64, 67, 64, 67}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "alternating imperfect/perfect should trigger violation")
end

function TestNoParallelImperfect.test_one_imperfect_then_all_perfects()
  -- One major third, then all fifths
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {64, 67, 67, 67, 67, 67, 67, 67}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "single imperfect without consecutive pair should trigger violation")
end

function TestNoParallelImperfect.test_imperfect_pair_in_middle()
  -- All fifths until step 3, then two thirds, then back to fifths
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 63, 63, 67, 67, 67, 67}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "imperfect pair anywhere in sequence should prevent violation")
end

function TestNoParallelImperfect.test_imperfect_pair_at_end()
  -- All fifths until step 7, then two thirds
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 63, 63, 67}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "imperfect pair at end should prevent violation")
end

function TestNoParallelImperfect.test_empty_final_note()
  -- Empty CP final note — rule should not fire (guard checks cf[length] > 0 and cp[length] > 0)
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 67, 67, 0}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "empty final note should not trigger violation")
end

function TestNoParallelImperfect.test_empty_interior_note_breaks_streak()
  -- Imperfect at step 1, empty at step 2 resets, then imperfect at step 3
  local cf = {60, 60, 0, 60, 60, 60, 60, 60}
  local cp = {64, 67, 67, 64, 60, 60, 60, 60}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  -- ic=4 at step 1, then ic=7 at step 2, then empty at step 3 resets, then ic=4 at step 4
  -- No consecutive pair of imperfects, so violate on final note
  luaunit.assertEquals(#v, 1, "empty note breaking streak should prevent pair recognition")
end

function TestNoParallelImperfect.test_violation_on_final_step_only()
  -- Only final note should carry the violation
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 67, 67, 67}
  local v = check_no_parallel_imperfect(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "should have exactly 1 violation")
  luaunit.assertEquals(v[1].step, 8, "violation should be at final step")
end
