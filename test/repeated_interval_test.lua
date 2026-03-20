-- test/repeated_interval_test.lua
-- Unit tests for the "repeated-interval" counterpoint rule.
--
-- Rule: the same vertical interval class (ic) must not repeat for
-- 4 or more consecutive steps.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local repeated_interval_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "repeated-interval" then
    repeated_interval_rule = r
    break
  end
end
assert(repeated_interval_rule, "repeated-interval rule not found")

local function check_repeated_interval(cf, cp, length)
  return repeated_interval_rule.check(cf, cp, length)
end

-- Filter violations to only those from repeated-interval rule
local function filter_repeated_interval(violations)
  local result = {}
  for _, v in ipairs(violations) do
    if v.summary and v.summary:match("interval 4.* in row") then
      table.insert(result, v)
    end
  end
  return result
end

TestRepeatedInterval = {}

function TestRepeatedInterval.test_three_consecutive_fifths_accepted()
  -- Three consecutive fifths (ic=7) should be accepted
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 70, 70, 70, 70}
  local cp = {67, 67, 67, 65, 80, 70, 70, 70}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "three consecutive same intervals should be accepted")
end

function TestRepeatedInterval.test_four_consecutive_fifths_rejected()
  -- Four consecutive fifths should be flagged at step 4
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  -- Padding varies the interval to avoid a second streak of 4+ triggering again
  local cf = {60, 60, 60, 60, 60, 70, 70, 70}
  local cp = {67, 67, 67, 67, 65, 77, 77, 77}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "four consecutive fifths should be flagged")
  luaunit.assertEquals(v[1].step, 4)
end

function TestRepeatedInterval.test_five_consecutive_thirds()
  -- Five consecutive minor thirds (ic=3)
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {63, 63, 63, 63, 63, 65, 65, 65}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertEquals(#v, 2, "five consecutive same intervals should produce 2 violations (steps 4 and 5)")
end

function TestRepeatedInterval.test_streak_resets_after_different_interval()
  -- Three fifths, one third, three fifths
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 63, 67, 67, 67, 65}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  -- Streak of three 7's, then reset to 3, then three 7's (so no 4+ in a row)
  luaunit.assertEquals(#v, 0, "streak reset by different interval should be accepted")
end

function TestRepeatedInterval.test_four_fifths_then_different()
  -- Four fifths then a third
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 63, 65, 65, 65}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "four same intervals followed by different should flag step 4 only")
  luaunit.assertEquals(v[1].step, 4)
end

function TestRepeatedInterval.test_seven_consecutive_unisons()
  -- Seven consecutive unisons (ic=0) — step 8 breaks the streak to yield exactly 4 violations
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 65}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertEquals(#v, 4, "seven consecutive same intervals should produce 4 violations (steps 4-7)")
end

function TestRepeatedInterval.test_empty_note_resets_streak()
  -- Streak of three fifths, empty note, then more fifths
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 0, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 67, 67, 65}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  -- At step 4, both cf[4] and cp[4] are checked; one is zero, so streak resets
  luaunit.assertEquals(#v, 0, "empty note should reset streak")
end

function TestRepeatedInterval.test_streak_of_3_then_empty_then_4()
  -- First group: three fifths (ok)
  -- Step 4: empty, resets streak
  -- Steps 5-8: four fifths, flagged at step 8
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 0, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 67, 67, 67, 67}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "four consecutive after reset should produce 1 violation")
  luaunit.assertEquals(v[1].step, 8)
end

function TestRepeatedInterval.test_violation_voice_is_2()
  -- Narrowed to test repeated-interval rule only; filter out violations from other rules
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {67, 67, 67, 67, 65, 65, 65, 65}
  local v = filter_repeated_interval(check_repeated_interval(cf, cp, 8))
  luaunit.assertTrue(#v > 0, "should have violations")
  if #v > 0 then luaunit.assertEquals(v[1].voice, 2, "repeated interval violations always report voice=2") end
end
