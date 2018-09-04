--[[
    Description: Insert most recent exported file...
    Version: 1.0.0
    Author: Lokasenna
    Donation: https://paypal.me/Lokasenna
    Changelog:
        Initial Release
    Links:
        Lokasenna's Website http://forum.cockos.com/member.php?u=10417
    About:
        IMPORTANT: Linux only. Maybe OSX too, I'm not sure.

        This script is intended as a workaround for issues using some plugins
        on Linux.
        
        When running under Wine, plugins such as EZDrummer aren't able
        to export MIDI to Reaper via drag-and-drop. They *do* still export the
        file to disk, though, so if you know where they've put it you can import
        it by hand.

        The script takes a few parameters and then looks for the most recent file
        matching them, which it then inserts in your Reaper project.

        A given set of parameters can also be saved as a separate action for
        quick access via shortcut keys or the action list.
    Donation: https://www.paypal.me/Lokasenna
]]--

--[[    TO DO

    - Windows support
    - What are the "dir..." equivalents?

]]--

-- Script generated by Lokasenna's GUI Builder

local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
local script_filename = ({reaper.get_action_context()})[2]:match("([^/\\]+)$")


local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()


local settings = {}

-- BEGIN FILE COPY HERE

local sources = {
  {   
    name = "EZDrummer 2",
    path = "~/.wine/drive_c/ProgramData/Toontrack/EZdrummer/", 
    ext = "mid",
    fx = "ezdrummer"
  },
  {
    name = "MT Power Drumkit",
    path = "~/",
    ext = "mid",
    fx = "mt-powerdrumkit",
  }
}

local SCRIPT_TITLE = "Insert most recent exported file"

local POS_EDIT = 1
local POS_MOUSE_SNAP = 2
local POS_MOUSE_NOSNAP = 3

local TR_SEL = 1
local TR_MOUSE = 2
local TR_MATCH = 3

local STR_FIND = [[
Samplers will normally export files to a consistent location, often with the
same, or a similar, filename. If you know the format of your sampler's exported
filenames, you can enter the following in a terminal to find the export path:
 
        find -name "<filename>"

Known formats:

        EZDrummer 2: "Variation*.mid"
        MT PowerDrumKit: "mtpdk.mid"
 
If you don't know the exported filename, export a file and then run:

        ls -alt ~/.wine/**/*.mid | head

The most recent file should be what you want.
(Don't do this if your entire MIDI library is in that path...)

Please let me know the formats for any additional samplers and I'll add them to
the list.
]]



local MSG = {

  NO_SWS = {
    "Accessing the mouse position requires the SWS extension for Reaper to be installed first.",
    "Whoops",
    0
  },

  NO_TRACK = {
    "Couldn't find a track. Make sure the mouse is over a track panel or the arrange view.", 
    "Whoops!", 
    0
  },

  NO_MOUSE = {
    "Couldn't get the mouse position. Make sure the mouse is over the ruler or the arrange view.", 
    "Whoops!", 
    0
  }


}

local function Message(msg)
  return reaper.MB(table.unpack(msg))
end



------------------------------------
-------- Core Functions ------------
------------------------------------


local function getSelectedTracks()
  
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    tracks[#tracks+1] = reaper.GetSelectedTrack(0, i)
  end
  
  return tracks
  
end

local findSourceTracks = {
  
  [TR_SEL] = function()
    return getSelectedTracks()
  end,
  
  [TR_MOUSE] = function()
    
    -- retval, context, position = reaper.BR_TrackAtMouseCursor()
    if reaper.BR_TrackAtMouseCursor then
      local tr = reaper.BR_TrackAtMouseCursor()
      if tr then 
        return {tr} 
      else 
        Message(MSG.NO_TRACK)
        return nil
      end
    else
      Message(MSG.NO_SWS)
      return nil
    end
    
  end,
  
  [TR_MATCH] = function()
    
    for i = 0, reaper.GetNumTracks()-1 do
      
      local tr = reaper.GetTrack(0,i)
      local idx = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
      local _, name = reaper.GetTrackName(tr, "")
      if reaper.TrackFX_GetByName(tr, settings.fx, false) > -1 then
        --Msg("found on track " .. tostring(idx) .. ": " .. tostring(name))
        return {tr}
        
      end
      
    end
    
  end,
  
}

local function getLastExport()
  
  if not settings.path then return end
  
  --local str = reaper.ExecProcess( cmdline, -1 )
  local f = io.popen("ls -t " .. settings.path .. "/*." .. settings.ext)
  if not f then return end
  
  for line in f:lines() do
    return line
  end
  
end

local getInsertPos = {
  
  [POS_EDIT] = function()
    return reaper.GetCursorPosition()
  end,
  
  [POS_MOUSE_NOSNAP] = function()
    if reaper.BR_PositionAtMouseCursor then
      local pos = reaper.BR_PositionAtMouseCursor(true)
      if pos then
        return pos
      else
        Message(MSG.NO_MOUSE)
        return nil
      end
    else
      Message(MSG.NO_SWS)
      return nil
    end
  end,
  
  [POS_MOUSE_SNAP] = function()
    if reaper.BR_PositionAtMouseCursor then
      local pos = reaper.BR_PositionAtMouseCursor(true)
      if pos then
        return reaper.SnapToGrid(0, pos)
      else
        Message(MSG.NO_MOUSE)
        return nil
      end      
    else
      Message(MSG.NO_SWS)
      return nil
    end
  end
  
}

local function selectTracks(tracks)
  
  reaper.SetOnlyTrackSelected(tracks[1])
  for i = 2, #tracks do
    reaper.SetTrackSelected(tracks[i], true)
  end
  
end

local function insertFile(tracks, file, pos)
  
  local sel = getSelectedTracks()
  if #sel > 0 then selectTracks(tracks) end
  reaper.SetEditCurPos(pos, false, false)
  reaper.InsertMedia(file, 8)
  if #sel > 0 then selectTracks(sel) end
  
end

local function doInsert(tracks, file, pos)
  
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  
  insertFile(tracks, file, pos)
  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(SCRIPT_TITLE, -1)
  
end


local function paramsFromSettings(settings)
  
  local tracks = findSourceTracks[settings.track]()
  if not tracks then return end
  
  local file = getLastExport()
  if not file then return end
  
  local pos = getInsertPos[settings.pos]()
  if not pos then return end
  
  return tracks, file, pos
  
end


------------------------------------
-------- Standalone startup --------
------------------------------------


if script_filename ~= "Lokasenna_Insert most recent exported file....lua" then
  
  local tracks, file, pos = paramsFromSettings(settings)
  if tracks and file and pos then
    doInsert(tracks, file, pos)
  else
    reaper.MB("Error reading the script's settings. Make sure you haven't edited the script at all.", "Whoops!", 0)
  end
  
  return
  
end


-- END FILE COPY HERE




------------------------------------
-------- GUI Functions -------------
------------------------------------


local function updateSourceMenu()
  
  local new = {"Empty"}
  for i = 1, #sources do
    new[i] = sources[i].name
  end
  
  GUI.elms.mnu_sources.optarray = new
  GUI.elms.mnu_sources:redraw()
  
end

local function populateSourceData()
  
  local source = sources[ GUI.Val("mnu_sources") ] 
  or {name = "", path = "", ext = "", fx = ""}
  
  GUI.Val("txt_path", source.path)
  GUI.Val("txt_ext", source.ext)
  GUI.Val("txt_fx", source.fx)
  
end

local function initSources()
  
  updateSourceMenu()
  populateSourceData()
  
end

local function initSettings()

  GUI.Val("opt_insert_pos", tonumber(settings.pos))
  GUI.Val("opt_insert_track", tonumber(settings.track))

end

local function settingsFromGUI()
  
  local settings = {
    
    path = GUI.Val("txt_path"),
    ext = GUI.Val("txt_ext"),
    fx = GUI.Val("txt_fx"),
    
    pos = GUI.Val("opt_insert_pos"),
    track = GUI.Val("opt_insert_track"),
  }
  
  return settings
  
end




local function btn_go()
  settings = settingsFromGUI()
  if settings.pos > 1 or settings.track == 2 then
    reaper.MB("Move the mouse into the arrange area and press Enter.", "Mouse mode", 0)
  end
  
  local tracks, file, pos = paramsFromSettings(settings)
  if tracks and file and pos then
    doInsert(tracks, file, pos)
  end
  
end


local function btn_save_source()
  
  local settings = settingsFromGUI()
  local slot = GUI.Val("mnu_sources")
  local cur_name = sources[slot].name
  local ret, name = reaper.GetUserInputs( "Saving source...", 
  1, 
  "Source name:", 
  cur_name)
  
  if not ret then return end
  if name ~= cur_name then slot = (#sources + 1) end
  
  sources[slot] = {
    name = name,
    path = settings.path,
    ext = settings.ext,
    fx = settings.fx
  }
  
  initSources()
  GUI.Val("mnu_sources", slot)    
  
end


local function btn_del_source()
  
  local slot = GUI.Val("mnu_sources")
  table.remove(sources, slot)
  
  GUI.Val("mnu_sources", math.max(slot - 1, 1))
  initSources()
  populateSourceData()
  
end


local function btn_find()
  reaper.MB(STR_FIND, "How to find a source", 0)
end




------------------------------------
-------- Ext State Functions -------
------------------------------------


local function sourcesFromStr(str)
  
  local arr = {}
  for source in str:gmatch("[^|]+") do
    local idx, keys = source:match("^idx=(%d+);(.+)")
    idx = tonumber(idx)
    arr[idx] = {}
    for k, v in keys:gmatch("([^;]+)=([^;]+)") do
      arr[idx][k] = v
    end
  end
  
  return arr
  
end


local function settingsFromStr(str)

  local settings = {}
  settings.pos, settings.track = str:match("(%d),(%d)")

  return settings

end



local function loadFromExt()
  
  local str = reaper.GetExtState("Lokasenna", SCRIPT_TITLE)
  if not str or str == "" then return end

  local source_str, setting_str = str:match("(.+)settings=(.+)")

  sources = sourcesFromStr(source_str)
  settings = settingsFromStr(setting_str)
  
end

local function sourcesToStr(sources)
  
  local strs = {}
  for idx, source in pairs(sources) do
    strs[#strs+1] = "|idx=" .. idx
    for k, v in pairs(source) do
      strs[#strs+1] = k .. "=" .. v
    end
  end
  
  return table.concat(strs, ";")
  
end

local function settingsToStr()
  return "settings=" .. GUI.Val("opt_insert_pos") .. "," .. GUI.Val("opt_insert_track")
end

local function saveToExt()
  
  local str = sourcesToStr(sources) .. settingsToStr(settings)
  reaper.SetExtState("Lokasenna", SCRIPT_TITLE, str, true)
  
end





------------------------------------
-------- Export button -------------
------------------------------------


local function table_to_code(settings)
  
  local strs = {
    'local settings = {'
  }
  
  for k, v in pairs(settings) do
    local type = type(v)
    local param = (type == "boolean" or type == "number") and tostring(v) 
    or  ('"' .. tostring(v) .. '"')
    strs[#strs+1] = '\t' .. k .. ' = ' .. param .. ','
  end
  
  strs[#strs+1] = '}'
  
  return table.concat(strs, "\n")
  
end


local function get_settings_to_export()
  
  return table_to_code( settingsFromGUI() )
  
end


local function sanitize_filename(name)
  return string.gsub(name, "[^%w%s_]", "-")
end


local function continue_export(alias)
  
  if not alias then return end
  alias = alias[1]
  if alias == "" then return end
  
  -- Copy everything from the file between the ReaPack header and GUI stuff
  local file_in, err = io.open(script_path .. script_filename, "r")
  if err then
    reaper.MB("Error opening source file:\n" .. tostring(err), "Whoops!", 0)
    return
  end
  
  local arr, copying = {}    
  --make sure to add a header tag, "generated by" etc.
  arr[1] = "-- This script was generated by " .. script_filename .. "\n"
  
  arr[2] = "\n" .. get_settings_to_export() .. "\n"
  
  for line in file_in:lines() do
    
    if copying then
      if string.match(line, "-- END FILE COPY HERE") then break end
      arr[#arr + 1] = line
    elseif string.match(line, "-- BEGIN FILE COPY HERE") then 
      copying = true
    end 
    
  end
  
  
  local name = "Lokasenna_" .. SCRIPT_TITLE .. " - " .. alias
  
  -- Write the file
  local name_out = sanitize_filename(name) .. ".lua"
  local file_out, err = io.open(script_path .. name_out, "w")
  if err then
    reaper.MB("Error opening output file:\n" .. script_path..name_out .. "\n\n".. tostring(err), "Whoops!", 0)
    return
  end    
  file_out:write(table.concat(arr, "\n"))
  file_out:close()
  
  -- Register it as an action
  local ret = reaper.AddRemoveReaScript( true, 0, script_path .. name_out, true )
  if ret == 0 then
    reaper.MB("Error registering the new script as an action.", "Whoops!", 0)
    return
  end
  
  reaper.MB(  "Saved current settings and added to the action list:\n" .. name_out, "Done!", 0)
  
end


local function btn_export()
  
  GUI.GetUserInputs("Saving settings", {"Name for this preset:"}, {""}, continue_export, 0)
  
end






------------------------------------
-------- GUI -----------------------
------------------------------------


GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Window.lua")()
GUI.req("Modules/Window - GetUserInputs.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end



GUI.name = SCRIPT_TITLE
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 464, 384
GUI.anchor, GUI.corner = "mouse", "C"



GUI.New("mnu_sources", "Menubox", {
  z = 11,
  x = 112.0,
  y = 16.0,
  w = 256,
  h = 20,
  caption = "Exported from:",
  optarray = {"EZDrummer 2", "MT Power Drumkit", "-- new --"},
  retval = 1,
  font_a = 3,
  font_b = 4,
  col_txt = "txt",
  col_cap = "txt",
  bg = "wnd_bg",
  pad = 4,
  noarrow = false,
  align = 0
})

GUI.New("btn_find", "Button", {
  z = 11,
  x = 372,
  y = 48,
  w = 20,
  h = 20,
  caption = "?",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame",
  func = btn_find
})

GUI.New("txt_path", "Textbox", {
  z = 11,
  x = 112.0,
  y = 48.0,
  w = 256,
  h = 20,
  caption = "Path:",
  cap_pos = "left",
  font_a = 3,
  font_b = "monospace",
  color = "txt",
  bg = "wnd_bg",
  shadow = true,
  pad = 4,
  undo_limit = 20
})

GUI.New("txt_ext", "Textbox", {
  z = 11,
  x = 112.0,
  y = 72.0,
  w = 48,
  h = 20,
  caption = "Extension:",
  cap_pos = "left",
  font_a = 3,
  font_b = "monospace",
  color = "txt",
  bg = "wnd_bg",
  shadow = true,
  pad = 4,
  undo_limit = 20
})

GUI.New("txt_fx", "Textbox", {
  z = 11,
  x = 240,
  y = 72.0,
  w = 128,
  h = 20,
  caption = "FX name:",
  cap_pos = "left",
  font_a = 3,
  font_b = "monospace",
  color = "txt",
  bg = "wnd_bg",
  shadow = true,
  pad = 4,
  undo_limit = 20
})

GUI.New("btn_save_source", "Button", {
  z = 11,
  x = 144,
  y = 112,
  w = 80,
  h = 20,
  caption = "Save source",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame",
  func = btn_save_source
})

GUI.New("btn_del_source", "Button", {
  z = 11,
  x = 240,
  y = 112,
  w = 80,
  h = 20,
  caption = "Del. source",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame",
  func = btn_del_source
})

GUI.New("opt_insert_pos", "Radio", {
  z = 11,
  x = 32.0,
  y = 160.0,
  w = 192,
  h = 96,
  caption = "Insert at:",
  optarray = {"Edit cursor", "Mouse cursor (snapped)", "Mouse cursor (no snap)"},
  dir = "v",
  font_a = 2,
  font_b = 3,
  col_txt = "txt",
  col_fill = "elm_fill",
  bg = "wnd_bg",
  frame = true,
  shadow = true,
  swap = nil,
  opt_size = 20
})

GUI.New("opt_insert_track", "Radio", {
  z = 11,
  x = 240.0,
  y = 160.0,
  w = 192,
  h = 96,
  caption = "Insert on:",
  optarray = {"Selected track(s)", "Track under mouse cursor","Track matching FX name"},
  dir = "v",
  font_a = 2,
  font_b = 3,
  col_txt = "txt",
  col_fill = "elm_fill",
  bg = "wnd_bg",
  frame = true,
  shadow = true,
  swap = nil,
  opt_size = 20
})

GUI.New("btn_go", "Button", {
  z = 11,
  x = 144.0,
  y = 280.0,
  w = 48,
  h = 24,
  caption = "Go!",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame",
  func = btn_go
})

GUI.New("btn_export", "Button", {
  z = 11,
  x = 208.0,
  y = 280.0,
  w = 112,
  h = 24,
  caption = "Save as action",
  font = 3,
  col_txt = "txt",
  col_fill = "elm_frame",
  func = btn_export
})


function GUI.elms.mnu_sources:onmouseup()
  GUI.Menubox.onmouseup(self)
  populateSourceData()
end

function GUI.elms.mnu_sources:onwheel()
  GUI.Menubox.onwheel(self)
  populateSourceData()
end




GUI.exit = saveToExt

GUI.Init()

loadFromExt()
initSources()
initSettings()

GUI.Main()