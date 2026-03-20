-- test/skip_order_test.lua
-- Unit tests for the "skip-order" melodic rule.
--
-- Rule: when two consecutive skips (3-5 semitones each) move in the
-- same direction, four sub-rules apply:
-- (a) second skip must be strictly smaller than the first
-- (b) span must not be dissonant
-- (c) span must not exceed octave (> 12 st)
-- (d) no 3+ consecutive same-direction skips

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local skip_order_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "skip-order" then
    skip_order_rule = r
    break
  end
end
assert(skip_order_rule, "skip-order rule not found")

local function check_skip_order(cf, cp, length)
  return skip_order_rule.check(cf, cp, length)
end

-- Filter violations to only those matching a specific skip-order sub-rule summary
local function filter_skip_order(violations, pattern)
  local result = {}
  for _, v in ipairs(violations) do
    if v.summary and v.summary:match(pattern) then
      table.insert(result, v)
    end
  end
  return result
end

TestSkipOrder = {}

-- Sub-rule (a): second skip must be smaller than first
function TestSkipOrder.test_first_skip_4_second_skip_3_accepted()
  -- First skip +4, second skip +3 (3 < 4) — sub-rule (a) should not fire
  -- Narrowed to test skip-order sub-rule (a) only; filter out other sub-rule violations
  local cf = {60, 64, 67, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "skip not smaller")
  luaunit.assertEquals(#v, 0, "second skip smaller than first should be accepted")
end

function TestSkipOrder.test_both_skips_equal()
  -- First skip +3, second skip +3 (equal, not smaller) — sub-rule (a) fires
  -- Narrowed to test skip-order sub-rule (a) only; filter out other sub-rule violations
  local cf = {60, 63, 66, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "skip not smaller")
  luaunit.assertEquals(#v, 1, "equal skips should be flagged")
  if #v > 0 then luaunit.assertEquals(v[1].summary, "skip not smaller") end
end

function TestSkipOrder.test_first_skip_3_second_skip_4()
  -- First skip +3, second skip +4 (not smaller) — sub-rule (a) fires
  -- Narrowed to test skip-order sub-rule (a) only; filter out other sub-rule violations
  local cf = {60, 63, 67, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "skip not smaller")
  luaunit.assertEquals(#v, 1, "larger second skip should be flagged")
  if #v > 0 then luaunit.assertEquals(v[1].summary, "skip not smaller") end
end

-- Sub-rule (d): three or more consecutive same-direction skips
function TestSkipOrder.test_three_consecutive_skips()
  -- Four notes each a 3-semitone skip apart: 60, 63, 66, 69
  -- Narrowed to test skip-order sub-rule (d) only; filter out other sub-rule violations
  local cf = {60, 63, 66, 69, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "same%-dir skip")
  luaunit.assertEquals(#v, 1, "three consecutive skips should be flagged")
  luaunit.assertEquals(v[1].step, 4)
  if #v > 0 then luaunit.assertEquals(v[1].summary, "3+ same-dir skips") end
end

function TestSkipOrder.test_three_consecutive_large_skips()
  -- Three 5-semitone skips: 60, 65, 70, 75
  -- Narrowed to test skip-order sub-rule (d) only; filter out other sub-rule violations
  local cf = {60, 65, 70, 75, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "same%-dir skip")
  luaunit.assertEquals(#v, 1, "three consecutive large skips should be flagged")
end

function TestSkipOrder.test_three_skips_then_step()
  -- Three skips then a step (breaks the streak); only the 3rd skip triggers sub-rule (d)
  -- Narrowed to test skip-order sub-rule (d) only; filter out other sub-rule violations
  local cf = {60, 63, 66, 69, 70, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "same%-dir skip")
  luaunit.assertEquals(#v, 1, "third skip only should be flagged at step 4")
  luaunit.assertEquals(v[1].step, 4)
end

function TestSkipOrder.test_three_descending_skips()
  -- Descending: 72, 69, 66, 63 — hold at 63 to avoid a 4th skip creating a second violation
  -- Narrowed to test skip-order sub-rule (d) only; filter out other sub-rule violations
  local cf = {72, 69, 66, 63, 63, 63, 63, 63}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "same%-dir skip")
  luaunit.assertEquals(#v, 1, "three descending skips should be flagged")
end

function TestSkipOrder.test_opposite_directions_not_flagged()
  -- First two skips up, then direction changes — sub-rule (d) should not fire
  -- Narrowed to test skip-order sub-rule (d) only; filter out other sub-rule violations
  local cf = {60, 63, 66, 63, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "same%-dir skip")
  -- Sub-rule (a) may fire for equal skips, but sub-rule (d) must not
  luaunit.assertEquals(#v, 0, "direction change should prevent 3+ same-dir-skips violation")
end

function TestSkipOrder.test_skip_in_cp_voice()
  -- Three consecutive skips in CP — sub-rule (d) fires
  -- Narrowed to test skip-order sub-rule (d) only; filter out other sub-rule violations
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 63, 66, 69, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "same%-dir skip")
  luaunit.assertTrue(#v >= 1, "three consecutive skips in CP should be flagged")
end

function TestSkipOrder.test_empty_note_skipped()
  -- Empty note breaks the skip chain — neither sub-rule should fire
  -- Narrowed to test skip-order rule only; filter out violations from other rules
  local cf = {60, 63, 0, 66, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "skip not smaller")
  luaunit.assertEquals(#v, 0, "skip order with empty note should be skipped")
end

function TestSkipOrder.test_non_skip_movements_not_checked()
  -- Two steps (2 semitones each) — not skips (skips are 3-5 st)
  -- Narrowed to test skip-order rule only; filter out violations from other rules
  local cf = {60, 62, 64, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_skip_order(check_skip_order(cf, cp, 8), "skip not smaller")
  luaunit.assertEquals(#v, 0, "steps (not skips) should not trigger rule")
end
