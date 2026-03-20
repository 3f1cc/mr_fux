-- test/tritone_outline_test.lua
-- Unit tests for the "tritone-outline" melodic rule.
--
-- Rule: three consecutive non-zero notes whose outer span
-- (modulo 12) equals 6 (tritone), 10, or 11 (sevenths) are forbidden.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local tritone_outline_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "tritone-outline" then
    tritone_outline_rule = r
    break
  end
end
assert(tritone_outline_rule, "tritone-outline rule not found")

local function check_tritone_outline(cf, cp, length)
  return tritone_outline_rule.check(cf, cp, length)
end

TestTritoneOutline = {}

function TestTritoneOutline.test_tritone_outline_rejected()
  -- Minor thirds outlining a tritone: 60, 63, 66 → span 6
  local cf = {60, 63, 66, 67, 67, 67, 67, 67}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "tritone outline should be flagged")
  luaunit.assertEquals(v[1].step, 3)
  luaunit.assertEquals(v[1].summary, "tritone outline")
end

function TestTritoneOutline.test_minor_seventh_outline_rejected()
  -- 60, 65, 70 → span 10 (minor 7th)
  local cf = {60, 65, 70, 78, 78, 78, 78, 78}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "minor 7th outline should be flagged")
  luaunit.assertEquals(v[1].summary, "7th outline")
end

function TestTritoneOutline.test_major_seventh_outline_rejected()
  -- 60, 65, 71 → span 11 (major 7th)
  local cf = {60, 65, 71, 72, 72, 72, 72, 72}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "major 7th outline should be flagged")
  luaunit.assertEquals(v[1].summary, "7th outline")
end

function TestTritoneOutline.test_fifth_outline_accepted()
  -- 60, 64, 67 → span 7 (perfect 5th)
  local cf = {60, 64, 67, 68, 68, 68, 68, 68}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "perfect 5th outline should be accepted")
end

function TestTritoneOutline.test_octave_outline_accepted()
  -- 60, 66, 72 → span 12, 12 % 12 = 0 (octave)
  local cf = {60, 66, 72, 73, 73, 73, 73, 73}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave outline should be accepted")
end

function TestTritoneOutline.test_compound_tritone_outline()
  -- 60, 69, 78 → span 18, 18 % 12 = 6 (compound tritone)
  local cf = {60, 69, 78, 82, 82, 82, 82, 82}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "compound tritone outline should be flagged")
  luaunit.assertEquals(v[1].summary, "tritone outline")
end

function TestTritoneOutline.test_tritone_outline_in_cp()
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 63, 66, 70, 70, 70, 70, 70}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "tritone outline in CP should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestTritoneOutline.test_empty_middle_note_skipped()
  local cf = {60, 0, 66, 70, 70, 70, 70, 70}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "outline with empty middle note should be skipped")
end

function TestTritoneOutline.test_empty_first_note_skipped()
  local cf = {0, 63, 66, 70, 70, 70, 70, 70}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "outline with empty first note should be skipped")
end

function TestTritoneOutline.test_violation_at_correct_step()
  -- Tritone outline at notes 3-4-5
  local cf = {60, 60, 60, 63, 66, 70, 70, 70}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_tritone_outline(cf, cp, 8)
  luaunit.assertEquals(#v, 1)
  luaunit.assertEquals(v[1].step, 5)
  luaunit.assertEquals(v[1].related[1].step, 3)
  luaunit.assertEquals(v[1].related[2].step, 4)
end
