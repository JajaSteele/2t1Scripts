if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("Cargobob Spawn Utils requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
    menu.exit()
end


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

if menu.is_trusted_mode_enabled(1 << 3) then
    menu.create_thread(function()
        local url = "https://raw.githubusercontent.com/JajaSteele/2t1Scripts/main/Misc/CargobobSpawnUtils.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\CargobobSpawnUtils.lua"

        local file1 = io.open(path, "r")
        local curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","Cargobob Spawning Utils",nil,0x00AAFF)
            local choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","Cargobob Spawning Utils",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","Cargobob Spawning Utils",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","Cargobob Spawning Utils",nil,0xFF00FF)
            print("Update HTTP for Cargobob Spawning Utils: "..code)
        end
    end)
end

local function request_model(_hash)
    if not streaming.has_model_loaded(_hash) then
        streaming.request_model(_hash)
        while (not streaming.has_model_loaded(_hash)) do
            system.yield(10)
        end
    end
end

local function request_control(_ent)
    local attempts = 75
    if not network.has_control_of_entity(_ent) then
        network.request_control_of_entity(_ent)
        while (not network.has_control_of_entity(_ent)) and (attempts > 0) do
            system.yield(0)
            attempts = attempts-1
        end
    end
end

function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

local cargo_hash = gameplay.get_hash_key("cargobob")

local vehicle_feature = menu.get_feature_by_hierarchy_key("spawn.vehicles.saved_vehicles")

local cargobob_autoenter = menu.add_integrated_feature_after("Cargobob Auto-Enter", "toggle", vehicle_feature)
cargobob_autoenter.hint = "Toggles whether the player is teleported in driver seat after spawning cargobob"
cargobob_autoenter.on = true

local cargobob_weak_magnet = menu.add_integrated_feature_after("Cargobob Weak Magnet", "toggle", vehicle_feature)
cargobob_weak_magnet.hint = "Reduces the strength of the magnet, to prevent chaos from attracting all nearby vehicles"
cargobob_weak_magnet.on = true

local cargobob_temporary = menu.add_integrated_feature_after("Cargobob Temporary", "toggle", vehicle_feature)
cargobob_temporary.hint = "After leaving the cargobob, it will be deleted automatically"
cargobob_temporary.on = true

local spawn_cargobob = menu.add_integrated_feature_after("Spawn Cargobob", "action_value_str", vehicle_feature, function(ft)
    local player_id = player.player_id()
    local player_pos = player.get_player_coords(player_id)
    local player_heading = player.get_player_heading(player_id)

    request_model(cargo_hash)
    local new_cargobob
    if cargobob_autoenter.on then
        new_cargobob = vehicle.create_vehicle(cargo_hash, player_pos+v3(0, 0, 5), player_heading, true, false)
        vehicle.set_heli_blades_full_speed(new_cargobob)
        ped.set_ped_into_vehicle(player.get_player_ped(player_id), new_cargobob, -1)
    else
        local spawn_pos = front_of_pos(player_pos, v3(0, 0, player_heading), 10)
        new_cargobob = vehicle.create_vehicle(cargo_hash, spawn_pos+v3(0, 0, 1), player_heading, true, false)
    end

    native.call(0x7BEB0C7A235F6F3B, new_cargobob, ft.value)
    if ft.value == 1 and cargobob_weak_magnet.on then
        native.call(0x66979ACF5102FD2F, new_cargobob, 0.01)
        native.call(0x6D8EAC07506291FB, new_cargobob, 0.01)
    end

    if cargobob_temporary.on then
        menu.create_thread(function()
            local cargobob_to_survey = new_cargobob
            repeat
                system.yield(100)
            until vehicle.get_ped_in_vehicle_seat(cargobob_to_survey, -1) == player.player_ped()
            menu.notify("This is a temporary cargobob!\nIt will get deleted once exited", "Cargobob Spawning Utils", nil, 0x00AAFF)

            while true do
                if vehicle.get_ped_in_vehicle_seat(cargobob_to_survey, -1) ~= player.player_ped() then
                    system.yield(1000)
                    native.call(0xDE564951F95E09ED, cargobob_to_survey, true, false)
                    system.yield(500)
                    request_control(cargobob_to_survey)
                    entity.delete_entity(cargobob_to_survey)
                    menu.notify("Deleted temporary cargobob!", "Cargobob Spawning Utils", nil, 0x0000FF)
                    return
                end
                system.yield(0)
            end
        end,nil)
    end
end)
spawn_cargobob:set_str_data({"Hook","Magnet"})
spawn_cargobob.hint = "Spawns a cargobob"