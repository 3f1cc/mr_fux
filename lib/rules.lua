-- lib/rules.lua
-- Counterpoint rule engine for mr_fux.
--
-- Rule sets live in lib/rulesets/<name>.lua and return a flat list of rule
-- tables.  Each rule:
--   name  : string
--   type  : "melodic" | "counterpoint"
--   check : function(cf, cp, length) -> list of violations
--
-- Each violation:
--   step    : int (1..length)  primary failing note
--   voice   : int (1=CF, 2=CP)
--   summary : string           one-line description (* prefix = advisory)
--   related : list of {step, voice}  contributing notes (excluding primary)

local M = {}

----------------------------------------------------------------------
-- Available rule sets
----------------------------------------------------------------------

-- On norns `include` is a global that resolves paths relative to the current
-- file, so "rulesets/wikipedia" finds lib/rulesets/wikipedia.lua correctly.
-- In the test environment (plain Lua, cwd = mr_fux/) `include` is nil, so we
-- fall back to require("lib/rulesets/<name>") which also resolves correctly.
local function _load_ruleset(name)
  if type(include) == "function" then
    return include("lib/rulesets/" .. name)
  else
    return require("lib/rulesets/" .. name)
  end
end

local _rulesets = {
  wikipedia = _load_ruleset("wikipedia"),
}

-- Ordered list of names shown in the params menu.
M.ruleset_names = {"wikipedia"}

-- Active rule list (points into the selected ruleset).
M.rules = _rulesets["wikipedia"]

-- Switch to a different rule set by name.  Unknown names are ignored.
function M.set_ruleset(name)
  if _rulesets[name] then
    M.rules = _rulesets[name]
  end
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Run all active rules and return a flat violations list.
function M.run_checks(cf, cp, length)
  local violations = {}
  for _, rule in ipairs(M.rules) do
    for _, v in ipairs(rule.check(cf, cp, length)) do
      table.insert(violations, v)
    end
  end
  return violations
end

-- All violations for a given (step, voice) pair.
function M.violations_at(violations, step, voice)
  local result = {}
  for _, v in ipairs(violations) do
    if v.step == step and v.voice == voice then
      table.insert(result, v)
    end
  end
  return result
end

-- True if any violation exists at (step, voice).
function M.has_violation(violations, step, voice)
  for _, v in ipairs(violations) do
    if v.step == step and v.voice == voice then return true end
  end
  return false
end

return M
