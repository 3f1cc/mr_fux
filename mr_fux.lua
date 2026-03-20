-- mr_fux: species counterpoint exercise tool
-- create two-part first species counterpoint
-- and receive feedback on rule violations
--
-- K1 held = shift
-- K2: select voice (cantus / counterpoint)
-- K3: start playback  |  shift+K3: enter/exit check mode
-- E1: move cursor
-- E2: change note pitch (active voice)
-- E3: change counterpoint note  |  (check mode) scroll issues

engine.name = 'PolyPerc'

MusicUtil = require "musicutil"
local json       = include("lib/json")
local rules_lib  = include("lib/rules")
local staff      = include("lib/staff")
local fileselect = require "fileselect"
local textentry  = require "textentry"

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local MAX_LENGTH = 24
local MODE_EDIT         = "edit"
local MODE_CHECK        = "check"
local MODE_CONFIRM_SAVE = "confirm_save"

----------------------------------------------------------------------
-- Grand staff layout
----------------------------------------------------------------------

-- Diatonic positions relative to middle C (C4 = pos 0)
local TREBLE_LINES = {2, 4, 6, 8, 10}   -- E4 G4 B4 D5 F5
local BASS_LINES   = {-2, -4, -6, -8, -10} -- A3 F3 D3 B2 G2

local STAFF_X1 = 2
local STAFF_X2 = 126
local NOTE_X0  = 10
local NOTE_DX  = 7

----------------------------------------------------------------------
-- Data
----------------------------------------------------------------------

local cantus       = {}
local counterpoint = {}
do
  local default_cf = {60, 62, 64, 65, 67, 65, 64, 62}
  for i = 1, MAX_LENGTH do
    cantus[i]       = default_cf[i] or 0
    counterpoint[i] = 0
  end
end

----------------------------------------------------------------------
-- UI state
----------------------------------------------------------------------

local LENGTH       = 8      -- current sequence length (4..MAX_LENGTH)
local layout       = 2      -- 1 = normal, 2 = narrow
local scroll_offset = 0     -- pixels scrolled left (always >= 0)

local cursor       = 1
local active_voice = 1      -- 1 = cantus firmus, 2 = counterpoint
local mode         = MODE_EDIT
local shift          = false
local k2_held        = false
local k2_chord_used  = false  -- true if K3 was pressed while K2 held (suppresses voice toggle on release)

-- Playback
local playing           = false
local play_pos          = 0
local play_metro
local play_solo_voice    = nil  -- set during solo playback (1=CF, 2=CP), nil=both
local play_return_cursor = nil  -- set when playing from check mode

-- Check mode
local violations      = {}   -- flat list of {step,voice,summary,related}
local check_issue_idx = 1    -- which issue at cursor is shown
local flash_bright    = 6    -- alternates for related-note flash
local flash_metro

----------------------------------------------------------------------
-- Rule-check helpers
----------------------------------------------------------------------

local function run_checks()
  violations = rules_lib.run_checks(cantus, counterpoint, LENGTH)
end

-- Is (step, voice) a related note for the currently displayed issue?
local function is_related(step, voice)
  local vols = rules_lib.violations_at(violations, cursor, active_voice)
  local v = vols[check_issue_idx]
  if not v then return false end
  for _, r in ipairs(v.related) do
    if r.step == step and r.voice == voice then return true end
  end
  return false
end

----------------------------------------------------------------------
-- Staff coordinate helpers
----------------------------------------------------------------------

local function note_x(i)
  return NOTE_X0 + (i - 1) * NOTE_DX - scroll_offset
end

----------------------------------------------------------------------
-- Audio
----------------------------------------------------------------------

local function play_note(midi_num)
  if midi_num and midi_num > 0 then
    engine.hz(MusicUtil.note_num_to_freq(midi_num))
  end
end

----------------------------------------------------------------------
-- Pitch editing
----------------------------------------------------------------------

-- Natural (non-accidental) pitch classes: C D E F G A B.
local natural_pc = {[0]=true,[2]=true,[4]=true,[5]=true,
                    [7]=true,[9]=true,[11]=true}

-- Increment or decrement a MIDI pitch by |d| diatonic steps, skipping
-- chromatic accidentals so that each step lands on a natural pitch.
-- Clamps the result to the playable range [36, 84].
local function diatonic_step(midi, d)
  local n   = midi
  local dir = d > 0 and 1 or -1
  for _ = 1, math.abs(d) do
    repeat n = n + dir until natural_pc[n % 12]
  end
  return util.clamp(n, 36, 84)
end

----------------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------------

local function draw_staves()
  screen.level(1)
  for _, pos in ipairs(TREBLE_LINES) do
    screen.move(STAFF_X1, staff.staff_y(pos))
    screen.line(STAFF_X2, staff.staff_y(pos))
    screen.stroke()
  end
  for _, pos in ipairs(BASS_LINES) do
    screen.move(STAFF_X1, staff.staff_y(pos))
    screen.line(STAFF_X2, staff.staff_y(pos))
    screen.stroke()
  end
  screen.move(STAFF_X1, staff.staff_y(TREBLE_LINES[#TREBLE_LINES]))
  screen.line(STAFF_X1, staff.staff_y(BASS_LINES[#BASS_LINES]))
  screen.stroke()
end

local function draw_ledger(x, pos)
  if pos == 0 then
    screen.level(1)
    screen.move(x - 4, staff.staff_y(0))
    screen.line(x + 4, staff.staff_y(0))
    screen.stroke()
  end
  local p = 12
  while p <= pos do
    screen.level(1)
    screen.move(x - 4, staff.staff_y(p))
    screen.line(x + 4, staff.staff_y(p))
    screen.stroke()
    p = p + 2
  end
  p = -12
  while p >= pos do
    screen.level(1)
    screen.move(x - 4, staff.staff_y(p))
    screen.line(x + 4, staff.staff_y(p))
    screen.stroke()
    p = p - 2
  end
end

-- Square note head: cantus firmus.
local function draw_cf_note(x, y, lv)
  screen.level(lv)
  if layout == 2 then
    -- 3×3 filled square.  Shifted up 1 px (y-2 not y-1) so the visual
    -- centre aligns with the staff line / between-line position at y.
    screen.rect(x - 1, y - 2, 3, 3)
  else
    screen.rect(x - 2, y - 2, 5, 4)
  end
  screen.fill()
end

-- Counterpoint note head.
-- Normal mode: filled circle (r=2).
-- Narrow mode: X shape (two diagonal lines), shifted up 1 px to match CF
-- alignment.  Clearly distinguishable from the solid CF square.
local function draw_cp_note(x, y, lv, step)
  screen.level(lv)
  if layout == 2 then
    -- X shape.  Coordinates shifted up by 1 px relative to y so that the
    -- visual centre sits on the same grid line as the CF square.
    screen.move(x - 1, y - 2); screen.line(x + 2, y + 1); screen.stroke()
    screen.level(lv)
    screen.move(x + 2, y - 2); screen.line(x - 1, y + 1); screen.stroke()
  else
    screen.circle(x, y, 2)
    screen.fill()
  end
end

-- Scroll so the cursor column is visible within the staff area.
local function update_scroll()
  local margin = NOTE_DX
  local x = NOTE_X0 + (cursor - 1) * NOTE_DX
  if x - scroll_offset < STAFF_X1 + margin then
    scroll_offset = x - STAFF_X1 - margin
  elseif x - scroll_offset > STAFF_X2 - margin then
    scroll_offset = x - STAFF_X2 + margin
  end
  if scroll_offset < 0 then scroll_offset = 0 end
end

-- Brightness for a note in check mode.
local function check_level(step, voice)
  if is_related(step, voice) then
    return flash_bright
  elseif step == cursor and voice == active_voice then
    return rules_lib.has_violation(violations, step, voice) and 15 or 4
  elseif rules_lib.has_violation(violations, step, voice) then
    return 11
  else
    return 3
  end
end

----------------------------------------------------------------------
-- File I/O
----------------------------------------------------------------------

local DATA_DIR = _path.data .. "mr_fux/"
local last_filename = "exercise"   -- most recently used save/load name
local pending_save_name = nil      -- filename awaiting overwrite confirmation
local pre_confirm_mode  = nil      -- mode to restore after confirm dialog

local function do_save(name)
  run_checks()   -- ensure violations reflect current notes
  util.make_dir(DATA_DIR)
  local data = {
    length       = LENGTH,
    cantus       = cantus,
    counterpoint = counterpoint,
    violations   = violations,
  }
  last_filename = name
  local path = DATA_DIR .. name .. ".json"
  local f = io.open(path, "w")
  if f then
    f:write(json.encode(data))
    f:close()
  end
end

local function do_load(path)
  last_filename = path:match("([^/]+)%.json$") or last_filename
  local f = io.open(path, "r")
  if not f then return end
  local s = f:read("*a")
  f:close()
  local ok, data = pcall(json.decode, s)
  if not ok or type(data) ~= "table" then return end
  if type(data.length) == "number" then
    LENGTH = math.max(4, math.min(MAX_LENGTH, math.floor(data.length)))
    params:set("length", LENGTH)
  end
  if type(data.cantus) == "table" then
    for i = 1, MAX_LENGTH do cantus[i] = data.cantus[i] or 0 end
  end
  if type(data.counterpoint) == "table" then
    for i = 1, MAX_LENGTH do counterpoint[i] = data.counterpoint[i] or 0 end
  end
  violations      = type(data.violations) == "table" and data.violations or {}
  check_issue_idx = 1
  cursor          = util.clamp(cursor, 1, LENGTH)
  update_scroll()
end

----------------------------------------------------------------------
-- Norns callbacks
----------------------------------------------------------------------

function init()
  play_metro = metro.init()
  play_metro.time = 0.5
  play_metro.event = function()
    play_pos = play_pos + 1
    if play_pos > LENGTH then
      playing        = false
      play_pos       = 0
      play_solo_voice = nil
      play_metro:stop()
      if play_return_cursor then
        cursor           = play_return_cursor
        play_return_cursor = nil
      end
      redraw()
      return
    end
    if play_solo_voice ~= 2 then play_note(cantus[play_pos]) end
    if play_solo_voice ~= 1 and counterpoint[play_pos] > 0 then
      play_note(counterpoint[play_pos])
    end
    redraw()
  end

  flash_metro = metro.init()
  flash_metro.time = 0.6
  flash_metro.event = function()
    flash_bright = (flash_bright == 6) and 12 or 6
    redraw()
  end

  -- Exercise parameters
  params:add_separator("exercise_sep", "exercise")
  params:add_number("length", "length", 4, MAX_LENGTH, 8)
  params:set_action("length", function(v)
    LENGTH = v
    cursor = util.clamp(cursor, 1, LENGTH)
    violations      = {}
    check_issue_idx = 1
    scroll_offset   = 0
    update_scroll()
    redraw()
  end)
  params:add_option("layout", "layout", {"normal", "narrow"}, 2)
  params:set_action("layout", function(v)
    layout = v
    if layout == 1 then
      NOTE_X0 = 14; NOTE_DX = 14
    else
      NOTE_X0 = 10; NOTE_DX = 7
    end
    scroll_offset = 0
    update_scroll()
    redraw()
  end)

  -- Rule set selection
  params:add_separator("rules_sep", "rules")
  params:add_option("ruleset", "rule set", rules_lib.ruleset_names, 1)
  params:set_action("ruleset", function(v)
    rules_lib.set_ruleset(rules_lib.ruleset_names[v])
    violations      = {}
    check_issue_idx = 1
    redraw()
  end)

  -- Save / load parameters
  params:add_separator("file_sep", "file")
  params:add_trigger("load_file", "load")
  params:set_action("load_file", function()
    fileselect.enter(DATA_DIR, function(file)
      if file ~= "cancel" then
        do_load(file)
        redraw()
      end
    end)
  end)
  params:add_trigger("save_file", "save")
  params:set_action("save_file", function()
    local function on_name_entered(name)
      if not name then return end
      if name == "" then name = last_filename end
      local path = DATA_DIR .. name .. ".json"
      local existing = io.open(path, "r")
      if existing then
        existing:close()
        -- File exists: close params menu and ask for confirmation before overwriting.
        norns.menu.toggle(false)
        pending_save_name = name
        pre_confirm_mode  = mode
        mode = MODE_CONFIRM_SAVE
        redraw()
      else
        do_save(name)
      end
    end
    textentry.enter(on_name_entered, last_filename, "save as")
  end)

  redraw()
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.line_width(1)
  screen.font_size(8)

  if mode == MODE_CONFIRM_SAVE then
    screen.level(15)
    screen.move(2, 20)
    screen.text("file exists:")
    screen.move(2, 32)
    screen.text(pending_save_name)
    screen.level(6)
    screen.move(2, 50)
    screen.text("K2: rename  K3: overwrite")
    screen.update()
    return
  end

  -- Status bar (y=8 baseline, above treble top at y=16)
  if mode == MODE_CHECK then
    local vols = rules_lib.violations_at(violations, cursor, active_voice)
    local v = vols[check_issue_idx]
    if v then
      screen.level(15)
      screen.move(2, 8)
      screen.text(v.summary)
      if #vols > 1 then
        screen.level(5)
        screen.move(94, 8)
        screen.text(check_issue_idx .. "/" .. #vols)
      end
    else
      screen.level(4)
      screen.move(2, 8)
      screen.text("CHECK")
    end
  else
    screen.level(4)
    screen.move(2, 8)
    screen.text(active_voice == 1 and "CF" or "CP")
    if playing then
      screen.move(14, 8)
      screen.text(">")
    end
  end

  draw_staves()

  -- Pass 1: cursor highlight and ledger lines (drawn before note heads so
  -- that notes always render on top of the staff for better legibility).
  for i = 1, LENGTH do
    local x = note_x(i)
    if x < STAFF_X1 - NOTE_DX or x > STAFF_X2 + NOTE_DX then goto continue1 end

    -- Cursor: symbol just below the bass staff indicating the active voice.
    -- Horizontal line = cantus firmus (voice 1); small square = counterpoint (voice 2).
    if i == cursor then
      local mark_y = staff.staff_y(BASS_LINES[#BASS_LINES]) + 3
      screen.level(6)
      if active_voice == 1 then
        screen.rect(x - 2, mark_y, 5, 1)
      else
        screen.rect(x - 1, mark_y, 2, 2)
      end
      screen.fill()
    end

    local cf_pos = staff.midi_to_staff_pos(cantus[i])
    local cp_pos = staff.midi_to_staff_pos(counterpoint[i])
    if cf_pos then draw_ledger(x, cf_pos) end
    if cp_pos then draw_ledger(x, cp_pos) end

    ::continue1::
  end

  -- Pass 2: note heads (rendered on top of staves and ledger lines).
  for i = 1, LENGTH do
    local x = note_x(i)
    if x < STAFF_X1 - NOTE_DX or x > STAFF_X2 + NOTE_DX then goto continue2 end

    local cf_pos = staff.midi_to_staff_pos(cantus[i])
    local cp_pos = staff.midi_to_staff_pos(counterpoint[i])

    local cf_lv, cp_lv
    if mode == MODE_CHECK then
      if cf_pos then cf_lv = check_level(i, 1) end
      if cp_pos then cp_lv = check_level(i, 2) end
    else
      local playing_here = playing and (i == play_pos)
      if cf_pos then
        cf_lv = playing_here and 15
             or (i == cursor and active_voice == 1 and 15)
             or (i == cursor and 11)   -- inactive voice at cursor: brighter
             or 7
      end
      if cp_pos then
        cp_lv = playing_here and 15
             or (i == cursor and active_voice == 2 and 15)
             or (i == cursor and 11)   -- inactive voice at cursor: brighter
             or 7
      end
    end

    -- Draw CP before CF so that CF always paints on top.  Some narrow-mode
    -- CP shapes use level-0 erasures that would otherwise overwrite CF pixels.
    if cp_pos and cp_lv then
      draw_cp_note(x, staff.staff_y(cp_pos), cp_lv, i)
    end
    if cf_pos and cf_lv then
      draw_cf_note(x, staff.staff_y(cf_pos), cf_lv)
    end

    ::continue2::
  end

  screen.update()
end

function key(n, z)
  if mode == MODE_CONFIRM_SAVE then
    if n == 2 then
      -- K2: go back to text entry to rename.
      -- Handle on key RELEASE so textentry doesn't immediately see a K2 release
      -- and cancel itself (textentry exits on n==2 z==0).
      if z == 1 then
        -- On press: suppress voice-toggle that would fire on release.
        k2_chord_used = true
      else
        -- On release: open textentry.
        local name = pending_save_name
        mode = pre_confirm_mode
        pending_save_name = nil
        pre_confirm_mode  = nil
        local function on_name_entered(new_name)
          if not new_name then return end
          if new_name == "" then new_name = name end
          local path = DATA_DIR .. new_name .. ".json"
          local existing = io.open(path, "r")
          if existing then
            existing:close()
            pending_save_name = new_name
            pre_confirm_mode  = mode
            mode = MODE_CONFIRM_SAVE
            redraw()
          else
            do_save(new_name)
          end
        end
        textentry.enter(on_name_entered, name, "save as")
      end
      return
    end
    if z == 0 then return end
    if n == 3 then
      -- K3: confirm overwrite
      local name = pending_save_name
      mode = pre_confirm_mode
      pending_save_name = nil
      pre_confirm_mode  = nil
      do_save(name)
      redraw()
    end
    return
  end

  if n == 1 then
    shift = (z == 1)
    return
  end

  if n == 2 then
    if z == 1 then
      if shift then
        -- K1+K2: play the active voice solo once
        k2_chord_used = true
        if not playing then
          play_return_cursor = (mode == MODE_CHECK) and cursor or nil
          play_solo_voice = active_voice
          playing  = true
          play_pos = 0
          play_metro:start()
        end
      else
        k2_held       = true
        k2_chord_used = false
      end
    else
      k2_held = false
      if not k2_chord_used then
        active_voice = (active_voice == 1) and 2 or 1
        if mode == MODE_CHECK then check_issue_idx = 1 end
        redraw()
      end
      k2_chord_used = false
    end
    return
  end

  if z == 0 then return end

  if n == 3 then
    if shift then
      -- K1+K3: toggle check mode
      if mode == MODE_EDIT then
        mode = MODE_CHECK
        check_issue_idx = 1
        run_checks()
        flash_metro:start()
      else
        mode = MODE_EDIT
        flash_metro:stop()
      end
      redraw()
    elseif not playing then
      -- K3: start playback once (works in both modes).
      -- In check mode, remember cursor position to restore after playback.
      play_return_cursor = (mode == MODE_CHECK) and cursor or nil
      play_solo_voice = nil
      playing  = true
      play_pos = 0
      play_metro:start()
    end
  end
end

function enc(n, d)
  if mode == MODE_CHECK then
    if n == 1 then
      cursor = util.clamp(cursor + d, 1, LENGTH)
      check_issue_idx = 1
      update_scroll()
    elseif n == 2 then
      -- Edit active voice pitch in check mode, same as edit mode.
      if active_voice == 1 then
        cantus[cursor] = diatonic_step(cantus[cursor] == 0 and 60 or cantus[cursor], d)
      else
        counterpoint[cursor] = diatonic_step(counterpoint[cursor] == 0 and 60 or counterpoint[cursor], d)
      end
    elseif n == 3 then
      local vols = rules_lib.violations_at(violations, cursor, active_voice)
      check_issue_idx = util.clamp(check_issue_idx + d, 1, math.max(1, #vols))
    end
    redraw()
    return
  end

  -- Edit mode
  if n == 1 then
    cursor = util.clamp(cursor + d, 1, LENGTH)
    update_scroll()
  elseif n == 2 then
    if active_voice == 1 then
      cantus[cursor] = diatonic_step(cantus[cursor] == 0 and 60 or cantus[cursor], d)
    else
      counterpoint[cursor] = diatonic_step(counterpoint[cursor] == 0 and 60 or counterpoint[cursor], d)
    end
  elseif n == 3 then
    counterpoint[cursor] = diatonic_step(counterpoint[cursor] == 0 and 60 or counterpoint[cursor], d)
  end
  redraw()
end

function cleanup()
  if play_metro  then play_metro:stop()  end
  if flash_metro then flash_metro:stop() end
end
