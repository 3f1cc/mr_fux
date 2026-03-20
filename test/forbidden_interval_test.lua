-- test/forbidden_interval_test.lua
-- Unit tests for the "forbidden-interval" melodic rule.
--
-- Rule: tritone (6 st), major sixth (9 st), minor seventh (10 st),
-- and major seventh (11 st) leaps are forbidden.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local forbidden_interval_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "forbidden-interval" then
    forbidden_interval_rule = r
    break
  end
end
assert(forbidden_interval_rule, "forbidden-interval rule not found")

local function check_forbidden(cf, cp, length)
  return forbidden_interval_rule.check(cf, cp, length)
end

TestForbiddenInterval = {}

function TestForbiddenInterval.test_tritone_rejected()
  local cf = {60, 66, 66, 66, 66, 66, 66, 66}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "tritone (6 st) should be flagged")
  luaunit.assertEquals(v[1].summary, "tritone leap")
end

function TestForbiddenInterval.test_major_sixth_rejected()
  local cf = {60, 69, 69, 69, 69, 69, 69, 69}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "major sixth (9 st) should be flagged")
  luaunit.assertEquals(v[1].summary, "maj 6th leap")
end

function TestForbiddenInterval.test_minor_seventh_rejected()
  local cf = {60, 70, 70, 70, 70, 70, 70, 70}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "minor seventh (10 st) should be flagged")
  luaunit.assertEquals(v[1].summary, "min 7th leap")
end

function TestForbiddenInterval.test_major_seventh_rejected()
  local cf = {60, 71, 71, 71, 71, 71, 71, 71}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "major seventh (11 st) should be flagged")
  luaunit.assertEquals(v[1].summary, "maj 7th leap")
end

function TestForbiddenInterval.test_perfect_fifth_accepted()
  local cf = {60, 67, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "perfect fifth (7 st) should be accepted")
end

function TestForbiddenInterval.test_perfect_fourth_accepted()
  local cf = {60, 65, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "perfect fourth (5 st) should be accepted")
end

function TestForbiddenInterval.test_major_third_accepted()
  local cf = {60, 64, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "major third (4 st) should be accepted")
end

function TestForbiddenInterval.test_octave_accepted()
  local cf = {60, 72, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave (12 st) should be accepted")
end

function TestForbiddenInterval.test_tritone_in_cp()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 66, 66, 66, 66, 66, 66, 66}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "tritone in CP should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestForbiddenInterval.test_descending_tritone()
  local cf = {66, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "descending tritone should be flagged (abs used)")
end

function TestForbiddenInterval.test_empty_previous_note_skipped()
  local cf = {0, 66, 67, 67, 67, 67, 67, 67}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "leap from empty note should be skipped")
end

function TestForbiddenInterval.test_both_voices_forbidden()
  local cf = {60, 66, 66, 66, 66, 66, 66, 66}
  local cp = {60, 71, 71, 71, 71, 71, 71, 71}
  local v = check_forbidden(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "forbidden intervals in both voices should produce 2 violations")
end
