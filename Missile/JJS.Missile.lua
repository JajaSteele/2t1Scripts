if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Missile requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Missile/JJS.Missile.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Missile.lua"

        local file1 = io.open(path, "r")
        local curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Missile",nil,0x00AAFF)
            local choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Missile",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Missile",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Missile",nil,0xFF00FF)
            print("Update HTTP for JJS Missile: "..code)
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


local handheld_thread

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Missile","parent",0)

local handheld_mode_value = 0

local hominglauncher_hash = gameplay.get_hash_key("weapon_hominglauncher")

local missile_speed = 1650.0

local enable_handheld = menu.add_feature("Handheld Missiles Upgrade","toggle", main_menu.id, function(ft)
    if ft.on then
        handheld_thread = menu.create_thread(function()
            while true do
                local local_player = player.player_id()
                local local_ped = player.get_player_ped(local_player)
                local is_aiming = player.is_player_free_aiming(local_player)
                local weapon =  ped.get_current_ped_weapon(local_ped)
                local player_pos = player.get_player_coords(local_player)
                local player_heading = player.get_player_heading(local_player)

                local spawn_pos = front_of_pos(player_pos+v3(0,0,0.5), cam.get_gameplay_cam_rot(), 0.25)
                local spawn_pos2 = front_of_pos(player_pos+v3(0,0,0.5), cam.get_gameplay_cam_rot(), 0.5)

                local target

                if handheld_mode_value == 0 then
                    local target_buffer = native.ByteBuffer16()
                    native.call(0x13EDE1A5DBF797C9, local_player, target_buffer)
                    target = target_buffer:__tointeger()
                elseif handheld_mode_value == 1 then
                    target = player.get_entity_player_is_aiming_at(local_player)

                    if weapon == hominglauncher_hash then
                        local w = 2/graphics.get_screen_width()
                        local h = 2/graphics.get_screen_height()

                        ui.draw_rect(0.5-w, 0.5-h, w, h, 255, 0, 255, 255)
                    end
                end

                if target ~= 0 and weapon == hominglauncher_hash then
                    ui.draw_line(spawn_pos, entity.get_entity_coords(target), 255, 0, 255, 255)
                end

                if weapon == hominglauncher_hash and target ~= 0 and controls.is_control_pressed(0, 24) then
                    system.yield(2)

                    native.call(0xFC52E0F37E446528, hominglauncher_hash, false)

                    system.yield(0)

                    native.call(0xBFE5756E7407064A, spawn_pos, spawn_pos2, 5000, true, gameplay.get_hash_key("VEHICLE_WEAPON_DELUXO_MISSILE"), local_ped, true, false, missile_speed, local_ped, true, false, target, true, 1, 0, 1)
                end
                system.yield(0)
            end
        end)
    else
        menu.delete_thread(handheld_thread)
    end
end)

local handheld_mode = menu.add_feature("Handheld Missiles Mode","autoaction_value_str", main_menu.id, function(ft)
    handheld_mode_value = ft.value
end)
handheld_mode:set_str_data({"Lock-on","Aiming At"})

local missile_speed_menu = menu.add_feature("Speed = [1650]", "action", main_menu.id, function(ft)
    local status = 1
    local temp_speed
    while status == 1 do
        status, temp_speed = input.get("Hash Input","",15,3)
        system.yield(0)
    end
    missile_speed = tonumber(temp_speed)+0.00001

    ft.name = "Speed = ["..temp_speed.."]"

end)
missile_speed_menu.hint = "Choose the speed of the missile. Default is 1650"


if false then -- DEBUG
    local missile_test = menu.add_feature("Test Missile","action",main_menu.id, function()
        local local_player = player.player_id()
        local player_pos = player.get_player_coords(local_player)
        local player_ped = player.get_player_ped(local_player)
        local player_veh = ped.get_vehicle_ped_is_using(player_ped)
        local veh_pos = entity.get_entity_coords(player_veh)
        local veh_rot = entity.get_entity_rotation(player_veh)

        local spawn_pos = front_of_pos(veh_pos, cam.get_gameplay_cam_rot(), 500)
        local spawn_pos2 = front_of_pos(veh_pos, cam.get_gameplay_cam_rot(), 450)

        native.call(0xBFE5756E7407064A, spawn_pos, spawn_pos2, 5000, true, gameplay.get_hash_key("VEHICLE_WEAPON_DELUXO_MISSILE"), local_ped, true, false, missile_speed, local_ped, true, false, player_veh, true, 1, 0, 1)
    end)
end