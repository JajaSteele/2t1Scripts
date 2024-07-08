if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Snowballs requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Snowballs/JJS.Snowballs.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Snowballs.lua"

        local file1 = io.open(path, "r")
        local curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Snowballs",nil,0x00AAFF)
            local choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Snowballs",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Snowballs",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Snowballs",nil,0xFF00FF)
            print("Update HTTP for JJS Snowballs: "..code)
        end
    end)
end

local player_hit_timer = {}

local snowball_hash = gameplay.get_hash_key("weapon_snowball")
local snowball_launcher_hash = gameplay.get_hash_key("weapon_snowlauncher")
local snowball_projectile = gameplay.get_hash_key("w_ex_snowball")
local snowball_mode = 0
local snowball_mode_list = {
    [0]="None",
    [1]="Kick",
    [2]="Fireworks",
    [3]="Zap",
    [4]="Stun",
    [5]="Mega Molotov",
    [6]="Mega Molotov 2",
    [7]="Fireworks Rain",
    [8]="Zap Repeated",
    [9]="Zap Repeated x2"
}

local detect_mode = 1
local detect_mode_list = {
    [0]="Ped Hit Time",
    [1]="Last Touched Entity"
}
local detection_thread
local reset_thread

local firework_hash = gameplay.get_hash_key("weapon_firework")
local zap_hash = gameplay.get_hash_key("weapon_raypistol")
local stun_hash = gameplay.get_hash_key("weapon_stungun")
local molotov_hash = gameplay.get_hash_key("weapon_molotov")

local stun_ptfx_group = "des_tv_smash"
local stun_ptfx_name = "ent_sht_electrical_box_sp"

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Snowballs","parent",0)

local sb_function = menu.add_feature("Set Snowball Function","action_value_str",main_menu.id, function(ft)
    snowball_mode = ft.value
    menu.notify("Set snowball to '"..snowball_mode_list[ft.value].."'", "JJS.Snowballs")
end)
sb_function:set_str_data(snowball_mode_list)
sb_function.hint = "Changes the function of the snowball"

local sb_detect_mode = menu.add_feature("Set Detection Mode","action_value_str",main_menu.id, function(ft)
    detect_mode = ft.value
    menu.notify("Set detection to '"..detect_mode_list[ft.value].."'", "JJS.Snowballs")
    if detection_thread and not menu.has_thread_finished(detection_thread) then
        menu.delete_thread(detection_thread)
    end
    reset_thread()
end)
sb_detect_mode:set_str_data(detect_mode_list)
sb_detect_mode.hint = "Ped Hit Time: More reliable, but doesn't work on peds in vehicles or on god-modded peds/players\n\nLast Touched Entity: A bit less stable, but: works on peds in cars, works on godmodded players, and can use Snowball Launcher!"
sb_detect_mode.value = 1

reset_thread = function()
    if detect_mode == 0 then
        detection_thread = menu.create_thread(function()
            menu.notify("Restarted detection thread: "..detect_mode_list[detect_mode], "JJS.Snowballs")
            while true do
                for k,ped_id in pairs(ped.get_all_peds()) do
                    local got_hit = native.call(0xC86D67D52A707CF8, ped_id, player.player_ped(), true):__tointeger()
                    if got_hit == 1 then
                        local by_snowball = native.call(0x36B77BB84687C318, ped_id, snowball_hash):__tointeger()
                        local game_time = native.call(0x9CD27B0045628463):__tointeger()
                        if by_snowball >= game_time-50 and by_snowball <= game_time+50 then
                            print(by_snowball.." >= "..(game_time-50).." <= "..game_time+50)
                            table.insert(player_hit_timer, {timer=15, id=ped_id})
                            print("Hit the ped "..ped_id.." with snowball")    
                        end
                    end
                end
                system.yield(0)
            end
        end,nil)
    elseif detect_mode == 1 then
        detection_thread = menu.create_thread(function()
            menu.notify("Restarted detection thread: "..detect_mode_list[detect_mode], "JJS.Snowballs")
            while true do
                local all_obj = object.get_all_objects()
                for k,obj in pairs(all_obj) do
                    if network.has_control_of_entity(obj) then
                        if not entity.is_entity_dead(obj) and entity.get_entity_model_hash(obj) == 1297482736 and native.call(0xB1632E9A5F988D11, obj):__tointeger() == 0 then -- w_ex_snowball
                            for k, ped_id in ipairs(ped.get_all_peds()) do
                                local last_hit = native.call(0xA75EE4F689B85391, obj):__tointeger()
                                if last_hit ~= 0 then
                                    if entity.is_entity_a_ped(last_hit) then
                                        table.insert(player_hit_timer, {timer=15, id=last_hit})
                                        print("Added Ped: "..last_hit)
                                    elseif entity.is_entity_a_vehicle(last_hit) then
                                        local driver = vehicle.get_ped_in_vehicle_seat(last_hit, -1)
                                        if driver and driver ~= 0 then
                                            table.insert(player_hit_timer, {timer=15, id=driver})
                                            print("Added Ped from vehicle: "..driver)
                                        end
                                    end
                                    system.yield(0)
                                end
                            end
                        end
                    end
                end
                system.yield(0)
            end
        end,nil)
    end
end

reset_thread()

menu.create_thread(function()
    while true do
        local to_remove = {}
        for key,data in pairs(player_hit_timer) do
            if data.timer > 0 then
                if snowball_mode == 1 then
                    system.yield(250)
                    if ped.is_ped_a_player(data.id) then
                        for i1=1, player.player_count()-1 do
                            if player.get_player_ped(i1) == data.id then
                                local curr_name = player.get_player_name(i1)
                                local curr_scid = player.get_player_scid(i1)
                                native.call(0x2206BF9A37B7F724, "REDMISTOUT", 2000, false)

                                if network.network_is_host() then
                                    network.network_session_kick_player(i1)
                                    menu.notify("Snowball-kicked player:\nName: "..curr_name.."\nSCID: "..curr_scid, "Snowball-kicked Player (Host-Kick)", nil, 0xFF0000FF)
                                    print("JJS.Snowballs: Host-Kicked player\n Name: "..curr_name.."\n SCID: "..curr_scid)
                                else
                                    network.force_remove_player(i1)
                                    menu.notify("Snowball-kicked player:\nName: "..curr_name.."\nSCID: "..curr_scid, "Snowball-kicked Player", nil, 0xFF0000FF)
                                    print("JJS.Snowballs: Snowball-kicked player \n Name: "..curr_name.."\n SCID: "..curr_scid)
                                end
                            end
                        end
                        system.yield(500)
                        native.call(0xDE564951F95E09ED, data.id, true, true)
                        system.yield(1500)
                        entity.delete_entity(data.id)
                    else
                        ped.set_ped_to_ragdoll(data.id, 10000, 10000, 0)
                        native.call(0x2206BF9A37B7F724, "lectroKERSOut", 500, false)
                        system.yield(500)
                        native.call(0xDE564951F95E09ED, data.id, true, true)
                        system.yield(1500)
                        entity.delete_entity(data.id)
                    end
                    to_remove[#to_remove+1] = key
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 2 then
                    local player_coords = entity.get_entity_coords(data.id)
                    gameplay.shoot_single_bullet_between_coords(player_coords, player_coords+v3(0.0, 0.0, -0.1), 0, firework_hash, 0, true, false, 10.0)
                    to_remove[#to_remove+1] = key
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 3 then
                    local player_coords = entity.get_entity_coords(data.id)
                    gameplay.shoot_single_bullet_between_coords(player_coords, player_coords+v3(0.0, 0.0, -0.1), 0, zap_hash, 0, true, false, 10.0)
                    to_remove[#to_remove+1] = key
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 4 then
                    local player_coords = entity.get_entity_coords(data.id)

                    menu.create_thread(function()
                        for i1=1, 60 do
                            local randomX = math.random(-20,20)/100
                            local randomY = math.random(-20,20)/100
                            local randomZ = math.random(-70,70)/100
                            if ped.is_ped_ragdoll(data.id) or ped.is_ped_in_any_vehicle(data.id) then
                                randomX = math.random(-70,70)/100
                                randomY = math.random(-70,70)/100
                                randomZ = math.random(-70,70)/100
                            end
                            graphics.set_next_ptfx_asset(stun_ptfx_group)
                            graphics.start_networked_ptfx_non_looped_on_entity(stun_ptfx_name, data.id, v3(randomX,randomY,randomZ), v3(0,0,0), 1.0)
                            system.yield(50)
                        end
                    end)
                    for x=-0.5, 0.5, 0.125 do
                        for y=-0.5, 0.5, 0.125 do
                            player_coords = entity.get_entity_coords(data.id)
                            gameplay.shoot_single_bullet_between_coords(player_coords+v3(x, y, 0.5), player_coords+v3(x, y, 0.4), 0, stun_hash, 0, true, false, 10.0) 
                        end
                    end
                    to_remove[#to_remove+1] = key
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 5 then
                    for x=-1, 1, 0.25 do
                        for y=-1, 1, 0.25 do
                            local player_coords = entity.get_entity_coords(data.id)
                            gameplay.shoot_single_bullet_between_coords(player_coords+v3(x, y, 0.1), player_coords+v3(x, y, 0.0), 0, molotov_hash, 0, true, false, 10.0) 
                        end
                    end
                    to_remove[#to_remove+1] = key
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 6 then
                    for x=-2, 2, 1 do
                        for y=-2, 2, 1 do
                            local player_coords = entity.get_entity_coords(data.id)
                            gameplay.shoot_single_bullet_between_coords(player_coords+v3(x*0.6, y*0.6, 0.0), player_coords+v3(x, y, 0.1), 0, molotov_hash, 0, true, false, 100.0) 
                            system.yield(0)
                        end
                    end
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 7 then
                    for x=-3, 3, 1 do
                        for y=-3, 3, 1 do
                            local player_coords = entity.get_entity_coords(data.id)
                            gameplay.shoot_single_bullet_between_coords(player_coords+v3(x*0.6, y*0.6, 40.0), player_coords+v3(x, y, 30.0), 0, firework_hash, 0, true, false, 100.0) 
                        end
                        system.yield(0)
                    end
                    system.yield(250)
                    player_hit_timer[key].timer = data.timer-2
                elseif snowball_mode == 8 then
                    local player_coords = entity.get_entity_coords(data.id)
                    gameplay.shoot_single_bullet_between_coords(player_coords, player_coords+v3(0.0, 0.0, -0.1), 0, zap_hash, 0, true, false, 10.0)
                    player_hit_timer[key].timer = data.timer-1
                elseif snowball_mode == 9 then
                    local player_coords = entity.get_entity_coords(data.id)
                    gameplay.shoot_single_bullet_between_coords(player_coords, player_coords+v3(0.0, 0.0, -0.1), 0, zap_hash, 0, true, false, 10.0)
                    player_hit_timer[key].timer = data.timer-0.5
                end
            else
                to_remove[#to_remove+1] = key
            end
        end

        for k,v in pairs(to_remove) do
            local data = table.remove(player_hit_timer, v)
            print("Removed: "..(data or {id="UNKNOWN"}).id)
        end
        system.yield(0)
    end
end,nil)

menu.create_thread(function()
    while true do
        if not weapon.has_ped_got_weapon(player.player_ped(), snowball_hash) then
            weapon.give_delayed_weapon_to_ped(player.player_ped(), snowball_hash, 0, false)
            menu.notify("Snowballs added to player inventory!")
        end
        if not weapon.has_ped_got_weapon(player.player_ped(), snowball_launcher_hash) and detect_mode == 1 then
            weapon.give_delayed_weapon_to_ped(player.player_ped(), snowball_launcher_hash, 0, false)
            menu.notify("Snowball Launcher added to player inventory!")
        end
        system.yield(2000)
    end
end)