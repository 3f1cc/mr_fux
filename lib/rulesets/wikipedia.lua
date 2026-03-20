-- lib/rulesets/wikipedia.lua
-- First-species counterpoint rules drawn from the Wikipedia article on
-- species counterpoint.  This is the default rule set for mr_fux.
--
-- Returns a flat list of rule tables:
--   name  : string  (kebab-case identifier)
--   type  : "melodic" | "counterpoint"
--   check : function(cf, cp, length) -> list of violations
--
-- Each violation:
--   step    : int (1..length)
--   voice   : int (1=CF, 2=CP)
--   summary : string  (* prefix = advisory)
--   related : list of {step, voice}

return {

  -- Melodic: flag any leap larger than an octave in either voice.
  {
    name = "large-leap",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      for i = 2, length do
        if cf[i] > 0 and cf[i-1] > 0 then
          if math.abs(cf[i] - cf[i-1]) > 12 then
            table.insert(result, {
              step    = i,
              voice   = 1,
              summary = "leap > 8ve",
              related = {{step = i-1, voice = 1}},
            })
          end
        end
        if cp[i] > 0 and cp[i-1] > 0 then
          if math.abs(cp[i] - cp[i-1]) > 12 then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "leap > 8ve",
              related = {{step = i-1, voice = 2}},
            })
          end
        end
      end
      return result
    end,
  },

  -- Melodic: flag forbidden melodic intervals — tritone, major 6th,
  -- minor 7th, major 7th (semitone sizes 6, 9, 10, 11).
  -- Leaps > octave are caught by large-leap above.
  {
    name = "forbidden-interval",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      local names = {[6]="tritone leap",[9]="maj 6th leap",
                     [10]="min 7th leap",[11]="maj 7th leap"}
      for _, pair in ipairs({{cf, 1}, {cp, 2}}) do
        local notes, vn = pair[1], pair[2]
        for i = 2, length do
          if notes[i] > 0 and notes[i-1] > 0 then
            local iv = math.abs(notes[i] - notes[i-1])
            if names[iv] then
              table.insert(result, {
                step    = i,
                voice   = vn,
                summary = names[iv],
                related = {{step = i-1, voice = vn}},
              })
            end
          end
        end
      end
      return result
    end,
  },

  -- Melodic: the final note must be approached by step (≤ 2 semitones).
  {
    name = "step-to-final",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      local i = length
      if cf[i] > 0 and cf[i-1] > 0 then
        if math.abs(cf[i] - cf[i-1]) > 2 then
          table.insert(result, {
            step    = i,
            voice   = 1,
            summary = "leap to final",
            related = {{step = i-1, voice = 1}},
          })
        end
      end
      if cp[i] > 0 and cp[i-1] > 0 then
        if math.abs(cp[i] - cp[i-1]) > 2 then
          table.insert(result, {
            step    = i,
            voice   = 2,
            summary = "leap to final",
            related = {{step = i-1, voice = 2}},
          })
        end
      end
      return result
    end,
  },

  -- Melodic: three consecutive notes that outline a tritone (6 st) or
  -- seventh (10 or 11 st) are forbidden, e.g. ascending F–A–B♮.
  {
    name = "tritone-outline",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      local bad = {[6]="tritone outline",[10]="7th outline",[11]="7th outline"}
      for _, pair in ipairs({{cf, 1}, {cp, 2}}) do
        local notes, vn = pair[1], pair[2]
        for i = 3, length do
          if notes[i] > 0 and notes[i-1] > 0 and notes[i-2] > 0 then
            local span = math.abs(notes[i] - notes[i-2]) % 12
            if bad[span] then
              table.insert(result, {
                step    = i,
                voice   = vn,
                summary = bad[span],
                related = {
                  {step = i-2, voice = vn},
                  {step = i-1, voice = vn},
                },
              })
            end
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: flag dissonant vertical intervals (2nds, tritone, 7ths,
  -- and the perfect fourth which is dissonant in 2-voice strict CP).
  {
    name = "dissonance",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      local dissonant = {[1]=true,[2]=true,[5]=true,[6]=true,[10]=true,[11]=true}
      for i = 1, length do
        if cf[i] > 0 and cp[i] > 0 then
          local ic = math.abs(cf[i] - cp[i]) % 12
          if dissonant[ic] then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "dissonance",
              related = {{step = i, voice = 1}},
            })
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: flag parallel perfect fifths (similar/oblique motion only;
  -- contrary motion to a fifth is acceptable).
  {
    name = "parallel-fifths",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for i = 2, length do
        if cf[i] > 0 and cp[i] > 0 and cf[i-1] > 0 and cp[i-1] > 0 then
          local ic_prev = math.abs(cf[i-1] - cp[i-1]) % 12
          local ic_curr = math.abs(cf[i]   - cp[i]  ) % 12
          if ic_prev == 7 and ic_curr == 7 then
            local contrary = (cf[i]-cf[i-1] > 0 and cp[i]-cp[i-1] < 0)
                          or (cf[i]-cf[i-1] < 0 and cp[i]-cp[i-1] > 0)
            if not contrary then
              table.insert(result, {
                step    = i,
                voice   = 2,
                summary = "parallel 5th",
                related = {
                  {step = i-1, voice = 1},
                  {step = i-1, voice = 2},
                  {step = i,   voice = 1},
                },
              })
            end
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: flag parallel octaves/unisons (same exclusion for contrary
  -- motion).
  {
    name = "parallel-octaves",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for i = 2, length do
        if cf[i] > 0 and cp[i] > 0 and cf[i-1] > 0 and cp[i-1] > 0 then
          local ic_prev = math.abs(cf[i-1] - cp[i-1]) % 12
          local ic_curr = math.abs(cf[i]   - cp[i]  ) % 12
          if ic_prev == 0 and ic_curr == 0 then
            local contrary = (cf[i]-cf[i-1] > 0 and cp[i]-cp[i-1] < 0)
                          or (cf[i]-cf[i-1] < 0 and cp[i]-cp[i-1] > 0)
            if not contrary then
              table.insert(result, {
                step    = i,
                voice   = 2,
                summary = "parallel 8ve",
                related = {
                  {step = i-1, voice = 1},
                  {step = i-1, voice = 2},
                  {step = i,   voice = 1},
                },
              })
            end
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: first and last notes must be perfect consonances.
  -- Unison/octave (ic 0) or fifth (ic 7) are allowed when CP is above CF.
  -- When CP is below CF only unison/octave (ic 0) is allowed, not a fifth.
  {
    name = "endpoints",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for _, i in ipairs({1, length}) do
        if cf[i] > 0 and cp[i] > 0 then
          local ic       = math.abs(cf[i] - cp[i]) % 12
          local cp_below = cp[i] < cf[i]
          local ok       = (ic == 0) or (ic == 7 and not cp_below)
          if not ok then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "imperfect end",
              related = {{step = i, voice = 1}},
            })
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: unisons are only permitted at the first and last step.
  {
    name = "no-interior-unison",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for i = 2, length - 1 do
        if cf[i] > 0 and cp[i] > 0 then
          if cf[i] == cp[i] then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "interior unison",
              related = {{step = i, voice = 1}},
            })
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: the interval between voices must not exceed a major
  -- tenth (16 semitones).
  {
    name = "wide-spacing",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for i = 1, length do
        if cf[i] > 0 and cp[i] > 0 then
          if math.abs(cf[i] - cp[i]) > 16 then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "spacing > 10th",
              related = {{step = i, voice = 1}},
            })
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: perfect consonances (P5, P8/unison) must be approached
  -- by oblique or contrary motion — similar motion is forbidden (AC3).
  {
    name = "hidden-parallel",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for i = 2, length do
        if cf[i] > 0 and cp[i] > 0 and cf[i-1] > 0 and cp[i-1] > 0 then
          local ic_curr = math.abs(cf[i] - cp[i]) % 12
          if ic_curr == 0 or ic_curr == 7 then
            local cf_d = cf[i] - cf[i-1]
            local cp_d = cp[i] - cp[i-1]
            local similar = (cf_d > 0 and cp_d > 0) or (cf_d < 0 and cp_d < 0)
            if similar then
              table.insert(result, {
                step    = i,
                voice   = 2,
                summary = ic_curr == 0 and "hidden 8ve" or "hidden 5th",
                related = {
                  {step = i-1, voice = 1},
                  {step = i-1, voice = 2},
                  {step = i,   voice = 1},
                },
              })
            end
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: both voices must not skip in the same direction
  -- simultaneously (a skip is an interval of a 3rd or 4th, 3–5 semitones).
  {
    name = "similar-skip",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      for i = 2, length do
        if cf[i] > 0 and cp[i] > 0 and cf[i-1] > 0 and cp[i-1] > 0 then
          local cf_d = cf[i] - cf[i-1]
          local cp_d = cp[i] - cp[i-1]
          local same_dir = (cf_d > 0 and cp_d > 0) or (cf_d < 0 and cp_d < 0)
          local cf_skip = math.abs(cf_d) >= 3
          local cp_skip = math.abs(cp_d) >= 3
          if same_dir and cf_skip and cp_skip then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "similar skip",
              related = {
                {step = i-1, voice = 1},
                {step = i-1, voice = 2},
                {step = i,   voice = 1},
              },
            })
          end
        end
      end
      return result
    end,
  },

  -- Melodic: an ascending minor sixth (8 semitones up) must be immediately
  -- followed by downward motion.
  {
    name = "minor-sixth-resolve",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      for _, pair in ipairs({{cf, 1}, {cp, 2}}) do
        local notes, vn = pair[1], pair[2]
        for i = 2, length - 1 do
          if notes[i] > 0 and notes[i-1] > 0 and notes[i+1] > 0 then
            if notes[i] - notes[i-1] == 8 then   -- ascending minor 6th
              if notes[i+1] >= notes[i] then      -- did not resolve down
                table.insert(result, {
                  step    = i + 1,
                  voice   = vn,
                  summary = "min 6th unresolved",
                  related = {
                    {step = i-1, voice = vn},
                    {step = i,   voice = vn},
                  },
                })
              end
            end
          end
        end
      end
      return result
    end,
  },

  -- Melodic: rules for same-direction skips (AM3):
  --  (a) second skip must be smaller than the first
  --  (b) span from first to third note must not be dissonant
  --  (c) span from first to third note must not exceed an octave
  --  (d) no more than two same-direction non-step movements in a row
  {
    name = "skip-order",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      local dissonant = {[1]=true,[2]=true,[5]=true,[6]=true,[10]=true,[11]=true}
      for _, pair in ipairs({{cf, 1}, {cp, 2}}) do
        local notes, vn = pair[1], pair[2]
        for i = 3, length do
          if notes[i] > 0 and notes[i-1] > 0 and notes[i-2] > 0 then
            local d1 = notes[i-1] - notes[i-2]
            local d2 = notes[i]   - notes[i-1]
            local same_dir   = (d1 > 0 and d2 > 0) or (d1 < 0 and d2 < 0)
            local first_skip  = math.abs(d1) >= 3 and math.abs(d1) <= 5
            local second_skip = math.abs(d2) >= 3 and math.abs(d2) <= 5
            if same_dir and first_skip and second_skip then
              -- (a) second skip must be smaller
              if math.abs(d2) >= math.abs(d1) then
                table.insert(result, {
                  step    = i,
                  voice   = vn,
                  summary = "skip not smaller",
                  related = {{step=i-2,voice=vn},{step=i-1,voice=vn}},
                })
              end
              -- (b) span must not be dissonant
              local span_ic = math.abs(notes[i] - notes[i-2]) % 12
              if dissonant[span_ic] then
                table.insert(result, {
                  step    = i,
                  voice   = vn,
                  summary = "dissonant skip span",
                  related = {{step=i-2,voice=vn},{step=i-1,voice=vn}},
                })
              end
              -- (c) span must not exceed an octave
              if math.abs(notes[i] - notes[i-2]) > 12 then
                table.insert(result, {
                  step    = i,
                  voice   = vn,
                  summary = "skip span > 8ve",
                  related = {{step=i-2,voice=vn},{step=i-1,voice=vn}},
                })
              end
            end
            -- (d) three or more same-direction non-step movements in a row
            if i >= 4 and notes[i-3] > 0 then
              local d0      = notes[i-2] - notes[i-3]
              local all_dir = (d0>0 and d1>0 and d2>0) or (d0<0 and d1<0 and d2<0)
              if all_dir and math.abs(d0)>=3 and math.abs(d1)>=3 and math.abs(d2)>=3 then
                table.insert(result, {
                  step    = i,
                  voice   = vn,
                  summary = "3+ same-dir skips",
                  related = {
                    {step=i-3,voice=vn},{step=i-2,voice=vn},{step=i-1,voice=vn},
                  },
                })
              end
            end
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint: the same vertical interval must not occur more than
  -- three times in a row.
  {
    name = "repeated-interval",
    type = "counterpoint",
    check = function(cf, cp, length)
      local result = {}
      local streak  = 0
      local prev_ic = nil
      for i = 1, length do
        if cf[i] > 0 and cp[i] > 0 then
          local ic = math.abs(cf[i] - cp[i]) % 12
          if ic == prev_ic then
            streak = streak + 1
          else
            streak  = 1
            prev_ic = ic
          end
          if streak > 3 then
            table.insert(result, {
              step    = i,
              voice   = 2,
              summary = "interval 4+ in row",
              related = {{step = i, voice = 1}},
            })
          end
        else
          streak  = 0
          prev_ic = nil
        end
      end
      return result
    end,
  },

  -- Melodic (AM4, advisory *): after a skip or leap, the next motion
  -- should be a step in the opposite direction.
  {
    name = "post-skip-step",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      for _, pair in ipairs({{cf, 1}, {cp, 2}}) do
        local notes, vn = pair[1], pair[2]
        for i = 2, length - 1 do
          if notes[i] > 0 and notes[i-1] > 0 and notes[i+1] > 0 then
            local d1 = notes[i]   - notes[i-1]
            local d2 = notes[i+1] - notes[i]
            if math.abs(d1) >= 3 then   -- skip or larger
              local resolves = (d1 > 0 and d2 < 0 and math.abs(d2) <= 2)
                            or (d1 < 0 and d2 > 0 and math.abs(d2) <= 2)
              if not resolves then
                table.insert(result, {
                  step    = i + 1,
                  voice   = vn,
                  summary = "* no step-back",
                  related = {
                    {step = i-1, voice = vn},
                    {step = i,   voice = vn},
                  },
                })
              end
            end
          end
        end
      end
      return result
    end,
  },

  -- Melodic (AM7, advisory *): a monotonic run of notes moving in the
  -- same direction must not outline a seventh (10+ semitones).
  {
    name = "seventh-run",
    type = "melodic",
    check = function(cf, cp, length)
      local result = {}
      for _, pair in ipairs({{cf, 1}, {cp, 2}}) do
        local notes, vn = pair[1], pair[2]
        local run_start = 1
        local run_dir   = 0
        for i = 2, length do
          if notes[i] > 0 and notes[i-1] > 0 then
            local d   = notes[i] - notes[i-1]
            local dir = (d > 0) and 1 or ((d < 0) and -1 or 0)
            if dir == 0 or dir ~= run_dir then
              run_start = i - 1
              run_dir   = dir
            end
            if run_dir ~= 0 then
              local span = math.abs(notes[i] - notes[run_start])
              if span >= 10 then    -- minor seventh or larger
                table.insert(result, {
                  step    = i,
                  voice   = vn,
                  summary = "* 7th in run",
                  related = {{step = run_start, voice = vn}},
                })
                run_start = i   -- reset to avoid re-flagging same run
              end
            end
          else
            run_start = i
            run_dir   = 0
          end
        end
      end
      return result
    end,
  },

  -- Counterpoint (FS6, advisory *, flagged on last note): the CP line
  -- should include at least one pair of consecutive imperfect consonances
  -- (parallel thirds or sixths).
  {
    name = "no-parallel-imperfect",
    type = "counterpoint",
    check = function(cf, cp, length)
      local imperfect = {[3]=true,[4]=true,[8]=true,[9]=true}
      local prev_ic   = nil
      for i = 1, length do
        if cf[i] > 0 and cp[i] > 0 then
          local ic = math.abs(cf[i] - cp[i]) % 12
          if imperfect[ic] and prev_ic and imperfect[prev_ic] then
            return {}   -- found a pair — no violation
          end
          prev_ic = ic
        else
          prev_ic = nil
        end
      end
      if cf[length] > 0 and cp[length] > 0 then
        return {{
          step    = length,
          voice   = 2,
          summary = "* no 3rds/6ths",
          related = {},
        }}
      end
      return {}
    end,
  },

}
