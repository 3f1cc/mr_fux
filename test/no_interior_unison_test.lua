-- test/no_interior_unison_test.lua
-- Unit tests for the "no-interior-unison" counterpoint rule.
--
-- Rule: ic=0 (unison or octave) is forbidden at interior steps (2..length-1).
-- Endpoints are exempt.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local no_interior_unison_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "no-interior-unison" then
    no_interior_unison_rule = r
    break
  end
end
assert(no_interior_unison_rule, "no-interior-unison rule not found")

local function check_no_interior_unison(cf, cp, length)
  return no_interior_unison_rule.check(cf, cp, length)
end

TestNoInteriorUnison = {}

function TestNoInteriorUnison.test_unison_at_first_endpoint_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 67}
  local cp = {60, 65, 65, 65, 65, 65, 65, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "unison at first endpoint should be accepted")
end

function TestNoInteriorUnison.test_unison_at_last_endpoint_accepted()
  local cf = {60, 65, 65, 65, 65, 65, 65, 60}
  local cp = {67, 60, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "unison at last endpoint should be accepted")
end

function TestNoInteriorUnison.test_unison_at_step_2_rejected()
  local cf = {60, 60, 65, 65, 65, 65, 65, 67}
  local cp = {67, 60, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "unison at step 2 (interior) should be flagged")
  luaunit.assertEquals(v[1].step, 2)
  luaunit.assertEquals(v[1].summary, "interior unison")
end

function TestNoInteriorUnison.test_unison_at_step_5_rejected()
  local cf = {60, 65, 65, 65, 60, 65, 65, 67}
  local cp = {67, 60, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "unison at step 5 (interior) should be flagged")
  luaunit.assertEquals(v[1].step, 5)
end

function TestNoInteriorUnison.test_octave_at_interior_accepted()
  -- CP is 12 semitones above CF (octave) — ic=0
  local cf = {60, 60, 65, 65, 65, 65, 65, 67}
  local cp = {67, 72, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "octave at interior should be accepted")
end

function TestNoInteriorUnison.test_double_octave_at_interior_accepted()
  -- CP is 24 semitones above CF (double octave) — ic=0
  local cf = {60, 60, 65, 65, 65, 65, 65, 67}
  local cp = {67, 84, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "double octave at interior should be accepted")
end

function TestNoInteriorUnison.test_multiple_interior_unisons()
  -- Unisons at steps 2, 3, 4
  local cf = {60, 60, 60, 60, 65, 65, 65, 67}
  local cp = {67, 60, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 3, "multiple interior unisons should produce 3 violations")
end

function TestNoInteriorUnison.test_empty_interior_note_skipped()
  local cf = {60, 65, 0, 65, 65, 65, 65, 67}
  local cp = {67, 60, 60, 60, 60, 60, 60, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "interior unison with empty note should be skipped")
end

function TestNoInteriorUnison.test_fifth_at_interior_accepted()
  local cf = {60, 60, 60, 60, 60, 60, 60, 67}
  local cp = {67, 67, 65, 65, 65, 65, 65, 60}
  local v = check_no_interior_unison(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "fifth at interior (ic=7, not 0) should be accepted")
end
