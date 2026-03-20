-- test/parallel_octaves_test.lua
-- Unit tests for the "parallel-octaves" counterpoint rule.
--
-- Rule: two consecutive steps both with ic=0 (unison or octave)
-- where motion is NOT contrary constitute parallel octaves.

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local parallel_octaves_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "parallel-octaves" then
    parallel_octaves_rule = r
    break
  end
end
assert(parallel_octaves_rule, "parallel-octaves rule not found")

local function check_parallel_octaves(cf, cp, length)
  return parallel_octaves_rule.check(cf, cp, length)
end

TestParallelOctaves = {}

function TestParallelOctaves.test_unison_to_unison_both_ascend()
  -- Unison at both steps, both ascend
  local cf = {60, 62, 84, 84, 84, 84, 84, 84}
  local cp = {60, 62, 85, 85, 85, 85, 85, 85}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "parallel unisons (similar motion) should be flagged")
  luaunit.assertEquals(v[1].step, 2)
end

function TestParallelOctaves.test_octave_to_octave_both_ascend()
  -- Octave (CP above) at both steps, both ascend
  local cf = {60, 62, 84, 84, 84, 84, 84, 84}
  local cp = {72, 74, 85, 85, 85, 85, 85, 85}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "parallel octaves (similar motion) should be flagged")
end

function TestParallelOctaves.test_octave_to_octave_contrary_motion()
  -- Octave to octave with contrary motion (CF up, CP down)
  local cf = {60, 62, 70, 70, 70, 70, 70, 70}
  local cp = {72, 70, 78, 78, 78, 78, 78, 78}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "parallel octaves with contrary motion should be accepted")
end

function TestParallelOctaves.test_unison_to_fifth()
  -- Unison then fifth (ic=7) — second is not ic=0
  local cf = {60, 62, 70, 70, 70, 70, 70, 70}
  local cp = {60, 69, 78, 78, 78, 78, 78, 78}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "unison to non-octave should be accepted")
end

function TestParallelOctaves.test_fifth_to_unison()
  -- Fifth then unison — first is not ic=0
  local cf = {60, 62, 70, 70, 70, 70, 70, 70}
  local cp = {67, 62, 78, 78, 78, 78, 78, 78}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "non-octave to unison should be accepted")
end

function TestParallelOctaves.test_both_descend_to_unison()
  -- Both voices descend to unison
  local cf = {62, 60, 84, 84, 84, 84, 84, 84}
  local cp = {62, 60, 85, 85, 85, 85, 85, 85}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "parallel unisons (both descend) should be flagged")
end

function TestParallelOctaves.test_oblique_to_octave_rejected()
  -- CF stays, CP moves to octave (oblique, not contrary)
  local cf = {60, 60, 84, 84, 84, 84, 84, 84}
  local cp = {72, 72, 85, 85, 85, 85, 85, 85}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 1, "oblique motion to octave should be flagged")
end

function TestParallelOctaves.test_three_consecutive_octaves()
  -- All octaves, all ascending
  local cf = {60, 62, 64, 84, 84, 84, 84, 84}
  local cp = {72, 74, 76, 85, 85, 85, 85, 85}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 2, "three consecutive octaves should produce 2 violations")
end

function TestParallelOctaves.test_empty_note_skipped()
  local cf = {60, 0, 62, 84, 84, 84, 84, 84}
  local cp = {60, 60, 62, 85, 85, 85, 85, 85}
  local v = check_parallel_octaves(cf, cp, 8)
  luaunit.assertEquals(#v, 0, "parallel octaves with empty note should be skipped")
end
