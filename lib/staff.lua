-- lib/staff.lua
-- Grand staff coordinate helpers for mr_fux.

local STEP       = 2     -- pixels per diatonic step
local MIDDLE_C_Y = 36    -- screen Y for middle C (ledger line between staves)

-- Convert a MIDI note number to a diatonic staff position relative to
-- middle C (C4 = 0).  Returns nil for empty notes (midi == 0).
local function midi_to_staff_pos(midi)
  if midi == 0 then return nil end
  local pc_to_dia = {[0]=0,[1]=0,[2]=1,[3]=1,[4]=2,[5]=3,
                     [6]=3,[7]=4,[8]=4,[9]=5,[10]=5,[11]=6}
  local octave = math.floor(midi / 12) - 5
  local pc     = midi % 12
  return octave * 7 + pc_to_dia[pc]
end

-- Convert a diatonic staff position to a screen Y pixel coordinate.
local function staff_y(pos)
  return MIDDLE_C_Y - pos * STEP
end

return {
  STEP              = STEP,
  MIDDLE_C_Y        = MIDDLE_C_Y,
  midi_to_staff_pos = midi_to_staff_pos,
  staff_y           = staff_y,
}
