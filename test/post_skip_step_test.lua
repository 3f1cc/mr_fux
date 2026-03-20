-- test/post_skip_step_test.lua
-- Unit tests for the "post-skip-step" melodic rule (advisory).
--
-- Rule: after a skip (|motion| >= 3 semitones), the next note should
-- immediately step back in the opposite direction (|next motion| <= 2 st,
-- opposite sign). This is an advisory rule (summary prefixed with *).

local luaunit   = require('lib/test/luaunit')
local rules_lib = require('lib/rules')

local post_skip_step_rule
for _, r in ipairs(rules_lib.rules) do
  if r.name == "post-skip-step" then
    post_skip_step_rule = r
    break
  end
end
assert(post_skip_step_rule, "post-skip-step rule not found")

local function check_post_skip_step(cf, cp, length)
  return post_skip_step_rule.check(cf, cp, length)
end

-- Filter violations to only those from post-skip-step rule
local function filter_post_skip_step(violations)
  local result = {}
  for _, v in ipairs(violations) do
    if v.summary and v.summary:match("step%-back") then
      table.insert(result, v)
    end
  end
  return result
end

TestPostSkipStep = {}

function TestPostSkipStep.test_skip_then_step_back_accepted()
  -- Ascending skip of 4 semitones, then descending step of 1
  -- Narrowed to test post-skip-step rule only; filter out violations from other rules
  -- Padding holds at 63 to avoid 63->60 creating a new unresolved skip
  local cf = {60, 64, 63, 63, 63, 63, 63, 63}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "skip followed by opposite step should be accepted")
end

function TestPostSkipStep.test_skip_then_step_back_by_2()
  -- Ascending skip of 4, then descending step of 2 (max step)
  local cf = {60, 64, 62, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "skip followed by 2-semitone step back should be accepted")
end

function TestPostSkipStep.test_skip_same_pitch_not_resolved()
  -- Ascending skip of 4, followed by same pitch (no resolution)
  -- Narrowed to test post-skip-step rule only; filter out violations from other rules
  local cf = {60, 64, 64, 65, 65, 65, 65, 65}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "skip not followed by step should be flagged")
  luaunit.assertEquals(v[1].step, 3)
  luaunit.assertEquals(v[1].summary, "* no step-back")
end

function TestPostSkipStep.test_skip_ascending_continuation()
  -- Ascending skip of 4, followed by ascending step
  -- Narrowed to test post-skip-step rule only; filter out violations from other rules
  local cf = {60, 64, 65, 66, 66, 66, 66, 66}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "skip not followed by opposite direction step should be flagged")
end

function TestPostSkipStep.test_skip_ascending_leap_back()
  -- Ascending skip of 4, followed by descending leap (3 st, not a step)
  -- Narrowed to test post-skip-step rule only; filter out violations from other rules
  -- Padding steps up from 61 so the 64->61 leap is itself resolved, yielding just 1 violation
  local cf = {60, 64, 61, 62, 62, 62, 62, 62}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "skip followed by leap back (not step) should be flagged")
end

function TestPostSkipStep.test_descending_skip_ascending_step_back()
  -- Descending skip of 4, then ascending step
  local cf = {64, 60, 61, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "descending skip followed by ascending step should be accepted")
end

function TestPostSkipStep.test_step_not_skip()
  -- Step of 2 semitones (not a skip) should not trigger rule
  -- Narrowed to test post-skip-step rule only; filter out violations from other rules
  -- Padding holds pitch after the step so no skips appear in the data
  local cf = {60, 62, 62, 62, 62, 62, 62, 62}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "step (not skip) should not trigger rule")
end

function TestPostSkipStep.test_skip_in_cp_voice()
  -- Narrowed to test post-skip-step rule only; filter out violations from other rules
  -- Padding holds CP at 65 to avoid 65->60 creating a new unresolved skip
  local cf = {60, 60, 60, 60, 60, 60, 60, 60}
  local cp = {60, 64, 65, 65, 65, 65, 65, 65}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "skip in CP not followed by step should be flagged")
  luaunit.assertEquals(v[1].voice, 2)
end

function TestPostSkipStep.test_empty_note_following_skip()
  local cf = {60, 64, 0, 60, 60, 60, 60, 60}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 0, "skip followed by empty note should be skipped")
end

function TestPostSkipStep.test_skip_at_last_possible_position()
  -- Skip at step 7, following note at step 8
  local cf = {60, 60, 60, 60, 60, 60, 64, 65}
  local cp = {60, 60, 60, 60, 60, 60, 60, 60}
  local v = filter_post_skip_step(check_post_skip_step(cf, cp, 8))
  luaunit.assertEquals(#v, 1, "skip at penultimate step not followed by opposite step should be flagged")
  luaunit.assertEquals(v[1].step, 8)
end
