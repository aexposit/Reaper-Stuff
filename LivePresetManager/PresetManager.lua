local function read_stored_presets()
    local resourcePath = reaper.GetResourcePath()
    local fxPresetFile = resourcePath .. sep .. "presets" .. sep .. "container.ini"
    nome_options = {}
    local file = io.open(fxPresetFile, "r")
    if not file then
        reaper.ShowConsoleMsg("Reaper preset file not found: " .. fxPresetFile .. "\n")
        return
    end
    for line in file:lines() do
        local name = line:match("Name=(.*)") -- Estrai il nome del preset
        if name then
            table.insert(nome_options, name) -- Aggiungi il nome del preset alla lista
        end
    end
    table.insert(nome_options, nil)
    table.sort(nome_options)
    file:close()
end




local function read_lua_table(file_path)
    if type(file_path) ~= "string" or file_path == "" then
        return nil, "No valid file selected"
    end

    local file, err = io.open(file_path, "r")
    if not file then return nil, "Error opening the file: " .. tostring(err) end

    local content = file:read("*all")
    file:close()
    mapping_data_tbl = {}
    local success, loaded_tbl = pcall(load("return " .. content))
    if success then
        return loaded_tbl
    else
        return mapping_data_tbl, "Error parsing the scene"
    end
end

local function save_lua_table()
    local ret, filename = reaper.GetUserInputs("Save scene as", 1, "Scene name:", "")
    if ret and filename ~= "" then
        local full_path = reaper.GetResourcePath() .. sep .. "Scripts" .. sep .. "AEXPO" .. sep .. filename .. ".scn"

        local file, err = io.open(full_path, "w") -- Apre il file in modalità scrittura
        local function table_to_string(tbl)
            local result = "{\n"
            for _, v in ipairs(tbl) do
                result = result ..
                    string.format("    {TrackNum=%d, PCNum=%d, Nome=\"%s\"},\n", v.TrackNum, v.PCNum, v.Nome)
            end
            result = result .. "}"
            return result
        end
        if file then
            file:write(table_to_string(parsed_data)) -- Scrive nel file
            file:close()
            reaper.ShowMessageBox("Scene: " .. full_path .. " saved", "Success", 0)
        else
            reaper.ShowMessageBox("Error saving scene", "Error", 0)
        end
    else
        reaper.ShowMessageBox("Must input a scene name", "Warning", 0)
    end
end




local function aggiungi_riga()
    local nuova_riga = { TrackNum = 1, PCNum = 1, Nome = nil }
    table.insert(parsed_data, nuova_riga)
end



local function load_scene()
    local init_path = reaper.GetResourcePath() .. sep .. "Scripts" .. sep .. "AEXPO" .. sep
    success, file_path_src = reaper.GetUserFileNameForRead(init_path, "Select a scene file (.scn)", "", "scn")
    if success and type(file_path_src) == "string" and file_path_src ~= "" then
        parsed_data, err = read_lua_table(file_path_src)
        current_scene = file_path_src:match("([^" .. sep .. "]+)$")
    else
        reaper.ShowMessageBox("No scene file selected", "Warning", 0)
    end
end

function ordina_tabella()
    table.sort(parsed_data, function(a, b)
        if tonumber(a.TrackNum) == tonumber(b.TrackNum) then
            return tonumber(a.PCNum) < tonumber(b.PCNum)
        else
            return tonumber(a.TrackNum) < tonumber(b.TrackNum)
        end
    end)
end

local function findIndexByName(options, name)
    for idx, option in ipairs(options) do
        if option == name then
            return idx
        end
    end
    return nil
end





-- Loop della GUI
local function loop()
    manage_midi_events()

    ImGui.SetNextWindowSize(ctx, 1024, 800, ImGui.Cond_FirstUseEver)
    ImGui.PushFont(ctx, font)
    local visible, open = ImGui.Begin(ctx, 'Live preset manager', true)

    if visible then
        ImGui.Text(ctx, "Live Preset monitor")
        ImGui.Dummy(ctx, 0, 10)
        if ImGui.Button(ctx, 'RESCAN PROJECT DATA') then
            read_stored_presets()
        end
        ImGui.Dummy(ctx, 0, 10)

        if ImGui.BeginTable(ctx, "Trackmon table", 4, ImGui.TableFlags_Borders, 1000) then
            ImGui.TableSetupColumn(ctx, "TrackNum", ImGui.TableColumnFlags_WidthFixed)
            ImGui.TableSetupColumn(ctx, "   TrackName   ", ImGui.TableColumnFlags_WidthFixed, 400)
            ImGui.TableSetupColumn(ctx, "Last MIDI", ImGui.TableColumnFlags_WidthFixed)
            ImGui.TableSetupColumn(ctx, " Current preset ", ImGui.TableColumnFlags_WidthFixed, 600)
            ImGui.TableHeadersRow(ctx)
            for i = 1, reaper.CountTracks(0) do
                local rtrack = reaper.GetTrack(0, i - 1)
                local _, _name = reaper.GetTrackName(rtrack)
                local _, _current_preset_name = reaper.TrackFX_GetPreset(rtrack, 0|0x1000000)
                if _current_preset_name ~= "" then
                    ImGui.TableNextRow(ctx)
                    ImGui.TableSetColumnIndex(ctx, 0)
                    ImGui.SetNextItemWidth(ctx, -1)
                    ImGui.Text(ctx, i)
                    ImGui.TableSetColumnIndex(ctx, 1)
                    ImGui.SetNextItemWidth(ctx, -1)
                    ImGui.Text(ctx, _name)
                    ImGui.TableSetColumnIndex(ctx, 2)
                    ImGui.SetNextItemWidth(ctx, -1)
                    ImGui.Text(ctx, tostring(memory_commands_tbl[i]))
                    ImGui.TableSetColumnIndex(ctx, 3)
                    ImGui.SetNextItemWidth(ctx, -1)
                    ImGui.Text(ctx, _current_preset_name)
                end
            end
            ImGui.EndTable(ctx)
        end

        ImGui.Dummy(ctx, 0, 10)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 10)
        ImGui.Text(ctx, "MIDI Map: ")
        ImGui.SameLine(ctx)
        ImGui.Text(ctx, current_scene)
        ImGui.Dummy(ctx, 0, 10)



        if ImGui.Button(ctx, 'LOAD SCENE') then
            load_scene()
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "SAVE SCENE AS...") then
            save_lua_table()
        end
        ImGui.Dummy(ctx, 0, 10)

        if ImGui.Button(ctx, 'ADD') then
            aggiungi_riga()
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "SORT") then
            ordina_tabella()
        end
        ImGui.SameLine(ctx)

        if ImGui.Button(ctx, "DELETE SELECTED") then
            for i = #parsed_data, 1, -1 do       -- Iteriamo al contrario per evitare problemi con gli indici durante l'eliminazione
                if selected_rows[i] then
                    table.remove(parsed_data, i) -- Rimuove la riga dalla tabella
                end
            end
            selected_rows = {}
        end



        -----------Inizio Sezione MIDI Mapping----------------

        if #parsed_data > 0 then
            if ImGui.BeginTable(ctx, "Table", 5, ImGui.TableFlags_Borders, 800) then
                ImGui.TableSetupColumn(ctx, "", ImGui.TableColumnFlags_WidthFixed)
                ImGui.TableSetupColumn(ctx, "   TrackNum   ", ImGui.TableColumnFlags_WidthFixed)
                ImGui.TableSetupColumn(ctx, "   Track name   ", ImGui.TableColumnFlags_WidthFixed)
                ImGui.TableSetupColumn(ctx, " MIDI value (0-127) ", ImGui.TableColumnFlags_WidthFixed)
                ImGui.TableSetupColumn(ctx, " Nome (Select) ", ImGui.TableColumnFlags_WidthFixed, 600)
                ImGui.TableHeadersRow(ctx)

                for i, row in ipairs(parsed_data) do
                    ImGui.TableNextRow(ctx)

                    ImGui.TableSetColumnIndex(ctx, 0)
                    ImGui.SetNextItemWidth(ctx, -1)
                    local isChecked = selected_rows[i] or false -- Verifica se la riga è selezionata
                    if ImGui.Checkbox(ctx, "##checkbox" .. i, isChecked) then
                        selected_rows[i] = not isChecked        -- Cambia lo stato della selezione
                    end


                    ImGui.TableSetColumnIndex(ctx, 1)
                    ImGui.SetNextItemWidth(ctx, -1)

                    local changed1, new_value1 = ImGui.InputInt(ctx, "##track" .. i, row.TrackNum)
                    if changed1 then
                        row.TrackNum = new_value1 -- Aggiorna il valore
                    end

                    ImGui.TableSetColumnIndex(ctx, 2)
                    ImGui.SetNextItemWidth(ctx, -1)
                    local _curr_track = reaper.GetTrack(0,row.TrackNum)
                    if _curr_track then
                        local _, _name = reaper.GetTrackName(_curr_track)
                        ImGui.Text(ctx, _name)
                    else
                        ImGui.Text(ctx, "N/A")
                    end
         

                    ImGui.TableSetColumnIndex(ctx, 3)
                    ImGui.SetNextItemWidth(ctx, -1)

                    local changed2, new_value2 = ImGui.InputInt(ctx, "##pc" .. i, row.PCNum)
                    if changed2 then
                        row.PCNum = new_value2 -- Aggiorna il valore
                    end


                    ImGui.TableSetColumnIndex(ctx, 4)
                    ImGui.SetNextItemWidth(ctx, -1)

                    -- Durante la visualizzazione:
                    local currentName = parsed_data[i].Nome
                    local currentIndex = findIndexByName(nome_options, currentName)

                    -- Se currentIndex è nil, visualizziamo una stringa vuota:
                    local comboLabel = currentIndex and nome_options[currentIndex] or ""

                    if ImGui.BeginCombo(ctx, "##combo" .. i, comboLabel) then
                        for idx, option in ipairs(nome_options) do
                            local selected = (currentIndex == idx)
                            if ImGui.Selectable(ctx, option, selected) then
                                parsed_data[i].Nome = option
                            end
                        end
                        ImGui.EndCombo(ctx)
                    end
                end
                ImGui.EndTable(ctx)
            end
        else
            ImGui.Text(ctx, "Nessun dato disponibile.")
        end


        ImGui.End(ctx)
    end
    ImGui.PopFont(ctx)
    if open then
        reaper.defer(loop)
    end
end



local function find_preset_name(trackNum, pcNum)
    for _, row in ipairs(parsed_data) do
        if row.TrackNum == trackNum and row.PCNum == pcNum then
            return row.Nome
        end
    end
    return nil -- Restituisce nil se non trova una corrispondenza
end



function manage_midi_events()
    for i = 1, reaper.CountTracks(0) do
        current_midi_value = math.tointeger(reaper.gmem_read(1000 + i))

        if current_midi_value ~= memory_commands_tbl[i] then -- New number midi_value arrived
            --reaper.ShowConsoleMsg("Value received on track " .. i .. " : " .. current_midi_value .. "\n")
            target_preset = find_preset_name(i, current_midi_value)

            if target_preset ~= nil then
                --reaper.ShowConsoleMsg("Preset:" .. target_preset .. "\n")
                --local _ = reaper.TrackFX_SetOffline(reaper.GetTrack(0, i - 1), 0, true) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
                local _ = reaper.TrackFX_SetEnabled(reaper.GetTrack(0, i - 1), 0|0x1000000, false) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
                local _ = reaper.TrackFX_SetPreset(reaper.GetTrack(0, i - 1), 0|0x1000000, target_preset)
                local _ = reaper.TrackFX_SetEnabled(reaper.GetTrack(0, i - 1), 0|0x1000000, true)  -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
                -- local _ = reaper.TrackFX_SetOffline(reaper.GetTrack(0, i - 1), 0, false) -- 0 è il primo effetto output FX / 0|0x1000000 è il primo insert FX
            end
            memory_commands_tbl[i] = current_midi_value -- aggiorno comandi = last = new
        end
    end
end

-----------------------------------
-- Main code
-----------------------------------

--------------------------
-- Initialize memory
--------------------------
reaper.gmem_attach("MyBandNS")
sep = package.config:sub(1, 1)
current_scene = ""
memory_commands_tbl = {}

read_stored_presets()
parsed_data = {}
selected_rows = {}
package.path = reaper.ImGui_GetBuiltinPath() .. sep .. '?.lua'
ImGui = require 'imgui' '0.9.3'
-- Inizializza ReaImGui
ctx = ImGui.CreateContext('Finestra ReaImGui')
font = ImGui.CreateFont('sans-serif', 20)
ImGui.Attach(ctx, font)

-- Avvia la GUI
loop()
