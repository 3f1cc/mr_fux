-- test/wide_spacing_test.lua
-- Unit tests for the "wide-spacing" counterpoint rule.
--
-- Rule: the raw absolute interval between CF and CP must not exceed
-- 16 semitones (a major tenth) at any step.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local wide_spacing_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "wide-spacing" then
    wide_spacing_rule = r
    break
  end
end
assert(wide_spacing_rule, "wide-spacing rule not found")

local function check_wide_spacing(cf, cp, length)
  return wide_spacing_rule.check(cf, cp, length)
end

TestWideSpacing = {}

function TestWideSpacing.test_exactly_16_semitones_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {76, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "exactly 16 semitones should be accepted")
end

function TestWideSpacing.test_17_semitones_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {77, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "17 semitones should be flagged")
  luaunit.assertEquals(v[1].step, 1)
  luaunit.assertEquals(v[1].summary, "spacing > 10th")
end

function TestWideSpacing.test_cp_below_cf_17_semitones()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {43, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "CP below CF by 17 semitones should be flagged")
end

function TestWideSpacing.test_24_semitones_rejected()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {84, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "24 semitones (two octaves) should be flagged")
end

function TestWideSpacing.test_exactly_15_semitones_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {75, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "exactly 15 semitones should be accepted")
end

function TestWideSpacing.test_violation_at_interior_step()
  local cf = {60, 60, 60, 77, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "spacing violation at interior step")
  luaunit.assertEquals(v[1].step, 4)
end

function TestWideSpacing.test_empty_cf_skipped()
  local cf = {0, 60, 60, 60, 60, 60, 60, 60}
  local cp = {77, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "wide spacing with empty CF should be skipped")
end

function TestWideSpacing.test_empty_cp_skipped()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {0, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "wide spacing with empty CP should be skipped")
end

function TestWideSpacing.test_multiple_violations()
  local cf = {60, 60, 60, 77, 60, 77, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_wide_spacing(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "multiple spacing violations should be flagged")
end
