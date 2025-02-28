function init()
--------------------------
-- Load presets from file
--------------------------
  reaper.ClearConsole()
  local resourcePath = reaper.GetResourcePath()
  local fxPresetFile = resourcePath .. "/presets/container.ini"
  stored_presets_tbl = {}
  local file = io.open(fxPresetFile, "r")
  if not file then
    reaper.ShowConsoleMsg("File preset non trovato: " .. fxPresetFile .. "\n")
    return
  end
  for line in file:lines() do
    local name = line:match("Name=(.*)")  -- Estrai il nome del preset
    if name then
        table.insert(stored_presets_tbl, name)  -- Aggiungi il nome del preset alla lista
    end
  end
  table.sort(stored_presets_tbl)
  file:close()

--------------------------
-- Initialize memory
--------------------------
  memory_commands_tbl = {}
  tracksobj_tbl = {}
  
  --gmem_key_start = 1000;
  num_tracks = reaper.CountTracks(0) -- Conta le tracce nel progetto
  for i = 1, num_tracks do
    table.insert(memory_commands_tbl, 0)
    table.insert(tracksobj_tbl, reaper.GetTrack(0, i - 1))
  end
  refresh_console()
end

function refresh_console()
  reaper.ClearConsole()
  reaper.ShowConsoleMsg("*********************** \n")
  reaper.ShowConsoleMsg("* Lista preset attivi * \n")
  reaper.ShowConsoleMsg("*********************** \n")
  for i = 1, num_tracks  do
    local _, track_name = reaper.GetTrackName(tracksobj_tbl[i])
    local padded_track_name = string.format("%-15s", track_name)
    local _, current_preset_name = reaper.TrackFX_GetPreset(tracksobj_tbl[i], 0|0x1000000) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
    current_pc = reaper.gmem_read(1000 + i)
    if current_preset_name ~= "" then
      reaper.ShowConsoleMsg("Traccia " .. (i).."("..padded_track_name..") - New PC: " .. tostring(current_pc) .. " - Old PC: " .. tostring(memory_commands_tbl[i]).." - Current Preset: " ..current_preset_name .. "\n")
    end
  end
end

function main()
  for i = 1, num_tracks do 
     current_cmd = reaper.gmem_read(1000 + i)
    if current_cmd ~= memory_commands_tbl[i] then -- New number midi_value arrived
      search_preset_str = string.format("%03d", i) .. "_" .. tostring(current_cmd):sub(2,4)
      for key, value in pairs(stored_presets_tbl) do
        if value:sub(1,7) == search_preset_str then -- trovato nuovo preset
          --local _ = reaper.TrackFX_SetOffline(tracksobj_tbl[i], 0, true) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
          local _ = reaper.TrackFX_SetEnabled(tracksobj_tbl[i], 0|0x1000000, false) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
          local _ = reaper.TrackFX_SetPreset(tracksobj_tbl[i], 0|0x1000000, value)
          local _ = reaper.TrackFX_SetEnabled(tracksobj_tbl[i], 0|0x1000000, true) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
          -- local _ = reaper.TrackFX_SetOffline(tracksobj_tbl[i], 0, false) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
          break
        end
      end
      memory_commands_tbl[i] = current_cmd  -- aggiorno comandi = last = new
      refresh_console()
    end
  end
  reaper.defer(main)
end

reaper.gmem_attach("MyBandNS") 
init()
main()
