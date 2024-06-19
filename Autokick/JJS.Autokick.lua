local function question(y,n)
    while true do
        if controls.is_control_pressed(0, y) then
            return true
        elseif controls.is_control_pressed(0, n) then
            return false
        end
        system.yield(0)
    end
end

local sp_check = menu.create_thread(function()
    print("searching for serpent.lua")
    local sp_path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\lib\\serpent.lua"
    if not utils.file_exists(sp_path) then
        print("serpent.lua not found!")
        if menu.is_trusted_mode_enabled(1 << 3) then
            local sp_url = "https://raw.githubusercontent.com/pkulchenko/serpent/0.30/src/serpent.lua"
            local code, body, headers = web.request(sp_url)

            if code == 200 and body:len() > 0 then
                local file2 = io.open(sp_path, "w")
                file2:write(body)
                file2:close()
                menu.notify("Successfully downloaded the serpent library","JJS Autokick",nil,0x00FF00)
            else
                menu.notify("Warning! Unable to download serpent library","JJS Autokick",nil,0x0000FF)
                menu.exit()
            end
        else
            menu.notify("Warning! Unable to download serpent library\nEnable HTTP Trusted once!","JJS Autokick",nil,0x0000FF)
            menu.exit()
        end
    end
end)

if menu.is_trusted_mode_enabled(1 << 3) then
    menu.create_thread(function()
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Autokick/JJS.Autokick.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Autokick.lua"

        local file1 = io.open(path, "r")
        local curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Autokick",nil,0x00AAFF)
            local choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Autokick",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Autokick",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Autokick",nil,0xFF00FF)
            print("Update HTTP for JJS Autokick: "..code)
        end
    end)
end
local sp
local stat, res = pcall(function() return require("serpent") end)
if stat then sp = res else print(res) end

local kick_list = {}

local autokick_features_list = {}

local show_list

local function find_kick_entry(name, scid)
    for k,v in ipairs(kick_list) do
        if v.name == (name or "") or v.scid == (scid or 0) then
            return k
        end
    end
end

if sp then

    local function save_list()
        local template_file = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Autokick.save.txt"
        local file1 = io.open(template_file,"w")
        file1:write(sp.dump(kick_list)) 
        file1:close()
    end

    local function load_list()
        local template_file = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Autokick.save.txt"
        if utils.file_exists(template_file) then
                
            local file1 = io.open(template_file,"r")
            local file_content = file1:read("*a")
            _, kick_list = sp.load(file_content)
            file1:close()
        end
    end

    local function update_list()
        for k,v in ipairs(autokick_features_list) do
            menu.delete_feature(v.id or 0)
        end

        autokick_features_list = {}

        for k,v in ipairs(kick_list) do
            autokick_features_list[#autokick_features_list+1] = menu.add_feature(v.name, "action_value_str", show_list.id, function(ft)
                if ft.value == 0 then
                    local key = find_kick_entry(ft.name)
                    table.remove(kick_list, key)
                    save_list()
                    menu.delete_feature(ft.id)
                end
            end)
            autokick_features_list[#autokick_features_list]:set_str_data({"Remove"})
            autokick_features_list[#autokick_features_list].hint = "Name: "..v.name.."\nSCID: "..v.scid
        end
        if #kick_list == 0 then
            autokick_features_list[#autokick_features_list+1] = menu.add_feature("List is Empty", "action", show_list.id, nil)
        end
    end

    show_list = menu.add_feature("JJS Autokick List", "parent", 0, update_list)

    load_list()
    update_list()

    event.add_event_listener("player_join", function(event)
        for k,v in pairs(kick_list) do
            local curr_name = player.get_player_name(event.player)
            local curr_scid = player.get_player_scid(event.player)
            if v.name == curr_name or v.scid == curr_scid then
                if network.network_is_host() then
                    network.network_session_kick_player(event.player)
                    menu.notify("Autokicked player:\nName: "..curr_name.."\nSCID: "..curr_scid, "Autokicked Player (Host-Kick)", nil, 0xFF0000FF)
                    print("JJS.Autokick: Host-Kicked player\n Name: "..curr_name.."\n SCID: "..curr_scid)
                else
                    network.force_remove_player(event.player)
                    menu.notify("Autokicked player:\nName: "..curr_name.."\nSCID: "..curr_scid, "Autokicked Player", nil, 0xFF0000FF)
                    print("JJS.Autokick: Kicked player \n Name: "..curr_name.."\n SCID: "..curr_scid)
                end
                break
            end
        end
    end)

    local add_to_list = menu.add_player_feature("#FF0000FF#Add to Autokick List", "action_value_str", 0, function(ft,ply,data)
        load_list()
        kick_list[#kick_list+1] = {
            name = player.get_player_name(ply),
            scid = player.get_player_scid(ply)
        }
        save_list()
        load_list()
        update_list()
        if ft.value == 1 then
            if network.network_is_host() then
                network.network_session_kick_player(ply)
                menu.notify("Added (And host-kicked) Player to Autokick list:\nName: "..(kick_list[#kick_list].name).."\nSCID: "..(kick_list[#kick_list].scid), "Added to List", nil, 0xFF00FF00)
            else
                network.force_remove_player(ply)
                menu.notify("Added (And kicked) Player to Autokick list:\nName: "..(kick_list[#kick_list].name).."\nSCID: "..(kick_list[#kick_list].scid), "Added to List", nil, 0xFF00FF00)
            end
        else
            menu.notify("Added Player to Autokick list:\nName: "..(kick_list[#kick_list].name).."\nSCID: "..(kick_list[#kick_list].scid), "Added to List", nil, 0xFF00FF00)
        end
        
    end)
    add_to_list.hint = "Add the player to the Autokick list\nWill not kick the player out, just prevent them from rejoining."
    add_to_list:set_str_data({"#FF0055FF#Add Only#DEFAULT#","#FF0000FF#Add + Kick#DEFAULT#"})
end