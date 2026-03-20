-- test/similar_skip_test.lua
-- Unit tests for the "similar-skip" counterpoint rule.
--
-- Rule: if both voices move in the same direction AND both make a skip
-- (|motion| >= 3 semitones), the move is flagged.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local similar_skip_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "similar-skip" then
    similar_skip_rule = r
    break
  end
end
assert(similar_skip_rule, "similar-skip rule not found")

local function check_similar_skip(cf, cp, length)
  return similar_skip_rule.check(cf, cp, length)
end

-- Filter violations to only those from similar-skip rule
local function filter_similar_skip(violations)
  local result = {}
  for _, v in ipairs(violations) do
    if v.summary and v.summary:match("similar skip") then
      table.insert(result, v)
    end
  end
  return result
end

TestSimilarSkip = {}

function TestSimilarSkip.test_both_skip_up_by_3()
  -- Both voices skip up by 3 semitones (minor third)
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  -- Padding holds at 63 to avoid the return skip creating a second similar-skip violation
  local cf = {60, 63, 63, 63, 63, 63, 63, 63}
  local cp = {60, 63, 63, 63, 63, 63, 63, 63}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "both skip up should be flagged")
  luaunit.assertEquals(v[1].step, 2)
  if #v > 0 then luaunit.assertEquals(v[1].summary, "similar skip") end
end

function TestSimilarSkip.test_both_skip_down_by_4()
  -- Both voices skip down
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  local cf = {64, 60, 60, 60, 60, 60, 60, 60}
  local cp = {64, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "both skip down should be flagged")
end

function TestSimilarSkip.test_opposite_direction_skips()
  -- CF skips up, CP skips down (opposite direction)
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  local cf = {60, 63, 60, 60, 60, 60, 60, 60}
  local cp = {60, 57, 60, 60, 60, 60, 60, 60}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "opposite direction skips should be accepted")
end

function TestSimilarSkip.test_cf_skips_cp_steps()
  -- CF skips up, CP steps up (2 semitones)
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  local cf = {60, 63, 60, 60, 60, 60, 60, 60}
  local cp = {60, 62, 60, 60, 60, 60, 60, 60}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "skip and step should be accepted")
end

function TestSimilarSkip.test_cf_steps_cp_skips()
  -- CF steps up (2 semitones), CP skips up
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  local cf = {60, 62, 60, 60, 60, 60, 60, 60}
  local cp = {60, 63, 60, 60, 60, 60, 60, 60}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "step and skip should be accepted")
end

function TestSimilarSkip.test_cf_skips_cp_stays()
  -- CF skips, CP stays (oblique)
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  local cf = {60, 63, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "skip with oblique motion should be accepted")
end

function TestSimilarSkip.test_both_skip_by_7_semitones()
  -- Both skip up by 7 semitones (perfect fifth)
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  -- Padding holds at 67 to avoid the return skip creating a second violation
  local cf = {60, 67, 67, 67, 67, 67, 67, 67}
  local cp = {60, 67, 67, 67, 67, 67, 67, 67}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "both skip by 7 should be flagged")
end

function TestSimilarSkip.test_both_skip_by_12_semitones()
  -- Both skip by 12 semitones (octave)
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  -- Padding holds at 72 to avoid the return skip creating a second violation
  local cf = {60, 72, 72, 72, 72, 72, 72, 72}
  local cp = {60, 72, 72, 72, 72, 72, 72, 72}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "both skip by 12 should be flagged")
end

function TestSimilarSkip.test_empty_note_skipped()
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  local cf = {60, 0, 63, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "similar skip with empty note should be skipped")
end

function TestSimilarSkip.test_two_similar_skip_events()
  -- Narrowed to test similar-skip rule only; filter out violations from other rules
  -- Hold after each skip to avoid return jumps creating extra similar-skip violations
  local cf = {60, 63, 63, 67, 67, 67, 67, 67}
  local cp = {60, 63, 63, 67, 67, 67, 67, 67}
  local v = filter_similar_skip(check_similar_skip(cf, cp, 8))
  luaunit.assertEquals(#v, 2, "two similar-skip events should produce 2 violations")
end
