-- test/minor_sixth_resolve_test.lua
-- Unit tests for the "minor-sixth-resolve" melodic rule.
--
-- Rule: an ascending minor sixth (exactly +8 chromatic semitones)
-- must be immediately followed by downward motion.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local minor_sixth_resolve_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "minor-sixth-resolve" then
    minor_sixth_resolve_rule = r
    break
  end
end
assert(minor_sixth_resolve_rule, "minor-sixth-resolve rule not found")

local function check_minor_sixth_resolve(cf, cp, length)
  return minor_sixth_resolve_rule.check(cf, cp, length)
end

TestMinorSixthResolve = {}

function TestMinorSixthResolve.test_ascending_m6_resolves_down_step()
  -- Ascending minor sixth, resolves down by step
  local cf = {60, 68, 67, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "ascending m6 resolving down should be accepted")
end

function TestMinorSixthResolve.test_ascending_m6_resolves_down_leap()
  -- Ascending minor sixth, resolves down by leap
  local cf = {60, 68, 65, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "ascending m6 resolving down by leap should be accepted")
end

function TestMinorSixthResolve.test_ascending_m6_followed_by_same_pitch()
  -- Ascending minor sixth, followed by same pitch (no resolution)
  local cf = {60, 68, 68, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "ascending m6 not resolving should be flagged")
  luaunit.assertEquals(v[1].step, 3)
  luaunit.assertEquals(v[1].summary, "min 6th unresolved")
end

function TestMinorSixthResolve.test_ascending_m6_followed_by_ascending_step()
  -- Ascending minor sixth, followed by ascending step (no resolution)
  local cf = {60, 68, 69, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "ascending m6 followed by ascending step should be flagged")
end

function TestMinorSixthResolve.test_ascending_m6_followed_by_ascending_leap()
  -- Ascending minor sixth, followed by ascending leap
  local cf = {60, 68, 72, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "ascending m6 followed by ascending leap should be flagged")
end

function TestMinorSixthResolve.test_descending_minor_sixth()
  -- Descending minor sixth (-8 semitones) should not trigger rule
  local cf = {68, 60, 61, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "descending minor sixth should be accepted")
end

function TestMinorSixthResolve.test_ascending_major_sixth()
  -- Ascending major sixth (+9 semitones) should not trigger rule
  local cf = {60, 69, 70, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "ascending major sixth should not trigger rule")
end

function TestMinorSixthResolve.test_ascending_m6_in_cp()
  -- Ascending minor sixth in CP voice
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 68, 69, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "ascending m6 in CP should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestMinorSixthResolve.test_empty_note_after_m6_skipped()
  -- Empty note following the minor sixth
  local cf = {60, 68, 0, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "minor sixth with empty following note should be skipped")
end

function TestMinorSixthResolve.test_m6_at_penultimate_step()
  -- Minor sixth ending at step length-1, resolved at step length
  local cf = {60, 60, 60, 60, 60, 60, 68, 67}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "ascending m6 at penultimate step, resolved at final step, should be accepted")
end

function TestMinorSixthResolve.test_m6_at_penultimate_not_resolved()
  -- Minor sixth at penultimate step, not resolved at final step
  local cf = {60, 60, 60, 60, 60, 60, 68, 69}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = check_minor_sixth_resolve(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "ascending m6 at penultimate step, not resolved, should be flagged at step 8")
  luaunit.assertEquals(v[1].step, 8)
end
