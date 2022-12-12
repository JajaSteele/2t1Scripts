if menu.get_trust_flags() ~= (1 << 2) then
    menu.notify("Avenger Utils requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
end

local ped_hash = 988062523

local avenger_pilot = 0
local blips = {}

local avenger = 0

local autopilot_active = false

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    entity.delete_entity(avenger_pilot or 0)

    autopilot_active = false
    
    avenger_pilot = 0
    avenger = 0
end

event.add_event_listener("exit", clear_all_noyield)

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

local function find_avenger()
    local counter = 0
    while true do
        local avenger_blip
        if counter == 0 then
            avenger_blip = native.call(0x1BEDE233E6CD2A1F, 589):__tointeger()
        else
            avenger_blip = native.call(0x14F96AA50D6FBEA7, 589):__tointeger()
        end

        if avenger_blip == 0 then
            return 0
        end

        if native.call(0xDA5F8727EB75B926, avenger_blip):__tointeger() == 0 then
            return ui.get_entity_from_blip(avenger_blip)
        end

        counter = counter+1
        system.yield(0)
    end
end

menu.create_thread(function()
    avenger = find_avenger()
    if avenger ~= 0 then
        menu.notify("Automatically registered your Avenger!","Success",nil,0x00FF00)
    else
        menu.notify("Unable to register your Avenger! Call it, then use the 'Find and Register Avenger' action.","Warning",nil,0x00AAFF)
    end
end)

local ground_check = {900}
repeat
    ground_check[#ground_check+1] = ground_check[#ground_check] - 25
until ground_check[#ground_check] < 26

local function get_ground(pos)
    for k,v in ipairs(ground_check) do
        native.call(0x07503F7948F491A7, v3(pos.x, pos.y, v))
        system.yield(0)
    end

    system.yield(1500)

    for k,v in ipairs(ground_check) do
        local destv3_check = v3(pos.x, pos.y, v)
        local groundz = native.ByteBuffer8()
        native.call(0xC906A7DAB05C8D2B, destv3_check, groundz, false, false)
        if groundz:__tonumber() ~= 0 then
            return groundz:__tonumber()
        end
        system.yield(0)
    end
    return 50
end

function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

function vector_to_heading(_target,_start)
    return math.atan((_target.x - _start.x), (_target.y - _start.y)) * -180 / math.pi
end

local function clear_all(delay,peds)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        repeat
            ui.remove_blip(v)
            system.yield(0)
        until native.call(0xE41CA53051197A27, v):__tointeger() == 0
        blips = {}
    end

    local attempts = 0

    if peds and avenger_pilot ~= nil then
        request_control(avenger_pilot)
        repeat
            entity.delete_entity(avenger_pilot)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(avenger_pilot) or attempts > 100
    end

    if peds then
        autopilot_active = false
    end
end

local main_menu = menu.add_feature("Avenger utils","parent",0)

local register_avenger = menu.add_feature("Registered Avenger: ","action",main_menu.id,function()
    avenger = find_avenger()
    if avenger ~= 0 then
        menu.notify("Successfully registered your Avenger!","Success",nil,0x00FF00)
    else
        menu.notify("Error! Unable to register your Avenger!","Error",nil,0x0000FF)
    end
end)
register_avenger.hint = "Use this to register your avenger. \nWill only work if your Avenger's blip is visible (So must be outside of the avenger)"


if false then --DISABLED CUZ ITS GLITCHY AF
    local autopilot_avenger = menu.add_feature("Move Avenger to WP","action",main_menu.id,function()
        if not autopilot_active then
            if avenger ~= 0 then
                menu.notify("Pilot Spawned","Spawned",nil,0x00FF00)
                autopilot_active = true
                local avenger_pos = entity.get_entity_coords(avenger)
                local dest_pos = ui.get_waypoint_coord()
                local dest_z = get_ground(dest_pos)
                local dest_v3 = v3(dest_pos.x, dest_pos.y, dest_z)

                local dist_x = math.abs(avenger_pos.x - dest_v3.x)
                local dist_y = math.abs(avenger_pos.y - dest_v3.y)
                local travel_dist = dist_x+dist_y

                local forward_heading = vector_to_heading(dest_v3, avenger_pos)
                
                request_model(ped_hash)
                avenger_pilot = ped.create_ped(0, ped_hash, avenger_pos+v3(0,0,3),0, true, false)
                streaming.set_model_as_no_longer_needed(ped_hash)

                entity.set_entity_as_mission_entity(avenger_pilot, true, true)

                native.call(0xCE2B43770B655F8F, avenger, true)
                native.call(0x9F8AA94D6D97DBF4, avenger_pilot, true)
                ped.set_ped_into_vehicle(avenger_pilot, avenger, -1)
                native.call(0x1F4ED342ACEFE62D, avenger_pilot, true, false)
                
                native.call(0x1913FE4CBF41C463, avenger_pilot, 251, true)

                local avenger_hash = entity.get_entity_model_hash(avenger)
                request_model(avenger_hash)

                --native.call(0xF7F9DCCA89E7505B, avenger_pilot, avenger, dest_v3.x, dest_v3.y, dest_v3.z, 150, false, 0, true) -- Doesn't work (TASK_PLANE_GOTO_PRECISE_VTOL)

                --ai.task_vehicle_drive_to_coord(avenger_pilot, avenger, dest_v3+v3(0,0,200), 75, 0, avenger_hash, 2, 25, 0) -- Doesn't work either

                --native.call(0xF7F9DCCA89E7505B, avenger_pilot, avenger, dest_v3, 150, false, 0, false)

                repeat
                    system.yield(0)
                    local curr_av_pos = entity.get_entity_coords(avenger)
                until curr_av_pos.z > (avenger_pos.z+15)

                request_control(avenger)
                vehicle.control_landing_gear(avenger, 1)

                if travel_dist > 2500 then
                    menu.notify(travel_dist.." > 2500, Changing VTOL Mode!","VTOL",nil,0x00AAFF)

                    native.call(0xF7F9DCCA89E7505B, avenger_pilot, avenger, avenger_pos+v3(0,0,50), math.ceil(avenger_pos.z+250), 200, true, forward_heading, true)

                    repeat
                        local curr_heading = entity.get_entity_heading(avenger)
                        local curr_height = entity.get_entity_coords(avenger).z
                        system.yield(0)
                    until ((curr_heading > forward_heading-5) and (curr_heading < forward_heading+5) and curr_height > (avenger_pos.z+80) ) or (not autopilot_active)
                    
                    native.call(0xCE2B43770B655F8F, avenger, false)
                    for i1=1, 60 do
                        native.call(0x9AA47FFF660CB932, avenger, (60-i1)/60)
                        system.yield(0)
                    end
                    native.call(0xCE2B43770B655F8F, avenger, true)

                    request_control(avenger)
                    request_control(avenger_pilot)
                    ai.task_vehicle_drive_to_coord(avenger_pilot, avenger, dest_v3+v3(0,0,150), 300, 0, avenger_hash, 2, 25, 0)
                    menu.notify("Avenger autopilot enabled!\nFlying to\nX:"..dest_v3.x.." Y:"..dest_v3.y.." Z:"..dest_v3.z,"Flying",nil,0x00FF00)
                    print("Avenger flying to \nX:"..dest_v3.x.." Y:"..dest_v3.y.." Z:"..dest_v3.z)

                    while true do
                        local avenger_pos_live = entity.get_entity_coords(avenger)

                        local dist_x = math.abs(avenger_pos_live.x - dest_v3.x)
                        local dist_y = math.abs(avenger_pos_live.y - dest_v3.y)

                        local hori_dist = dist_x+dist_y

                        if hori_dist < 750 then
                            request_control(avenger)
                            print("Preparing to Land")
                            menu.notify("Avenger preparing to land","Preparing",nil,0x00FF00)
                            native.call(0xCE2B43770B655F8F, avenger, false)
                            for i1=1, 60 do
                                native.call(0x9AA47FFF660CB932, avenger, i1/60)
                                system.yield(0)
                            end
                            native.call(0xCE2B43770B655F8F, avenger, true)
                            break
                        end
                        if not autopilot_active then
                            break
                        end
                        system.yield(0)
                    end

                    request_control(avenger)
                    request_control(avenger_pilot)

                    native.call(0xE1EF3C1216AFF2CD, avenger_pilot)

                    native.call(0xF7F9DCCA89E7505B, avenger_pilot, avenger, dest_v3, math.ceil(dest_z+50), 40, true, forward_heading, true)
                else
                    menu.notify(travel_dist.." < 2500, Keeping current VTOL Mode!","VTOL",nil,0x00AAFF)

                    request_control(avenger)
                    request_control(avenger_pilot)
                    native.call(0xF7F9DCCA89E7505B, avenger_pilot, avenger, dest_v3, math.ceil(dest_z+100), 150, true, forward_heading, true)
                end
                
                while true do
                    local avenger_pos_live = entity.get_entity_coords(avenger)

                    local dist_x = math.abs(avenger_pos_live.x - dest_v3.x)
                    local dist_y = math.abs(avenger_pos_live.y - dest_v3.y)

                    local hori_dist = dist_x+dist_y

                    if hori_dist < 10 and entity.get_entity_speed(avenger) < 4 then
                        break
                    end
                    if not autopilot_active then
                        break
                    end
                    system.yield(0)
                end

                request_control(avenger)
                request_control(avenger_pilot)
                native.call(0xF7F9DCCA89E7505B, avenger_pilot, avenger, dest_v3, 0, 0, true, forward_heading, true)
                vehicle.control_landing_gear(avenger, 2)
                menu.notify("Avenger Landing..","Landing",nil,0x00AAFF)

                repeat
                    system.yield(0)
                    local height = native.call(0x1DD55701034110E5, avenger):__tonumber()
                until height < 2.8 or not autopilot_active

                menu.notify("Avenger has Landed!","Landed Successfully",nil,0x00FF00)
                system.yield(2000)

                native.call(0xDBBC7A2432524127, avenger)
                
                ai.task_leave_vehicle(avenger_pilot, avenger, 64)
                native.call(0xCE2B43770B655F8F, avenger, false)

                repeat
                    system.yield(0)
                until ped.get_vehicle_ped_is_using(avenger_pilot) == 0 or not autopilot_active

                native.call(0xDE564951F95E09ED, avenger_pilot, true, true)

                system.yield(2000)

                clear_all(nil, true)
            else
                menu.notify("No Avenger registered!\nUse 'Find and Register Avenger' to register it","ERROR",nil,0x0000FF)
            end
        else
            menu.notify("A pilot is already active.","ERROR",nil,0x0000FF)
        end
    end)
    autopilot_avenger.hint = "Will spawn a pilot to drive the Avenger to your Waypoint\nWONT WORK IF AVENGER IS IN THE AIR WITH AUTOPILOT ENABLED"

    local avenger_clear = menu.add_feature("Clean All", "action", main_menu.id, function()
        native.call(0xCE2B43770B655F8F, avenger, false)
        clear_all(nil,true)
    
        native.call(0xDBBC7A2432524127, avenger)
        menu.notify("Cleared! You might want to get in the cockpit or it'll crash down.","Clear",nil,0x0000FF)
        autopilot_active = false
    end)
    avenger_clear.hint = "Will try to clear all of Avenger Utils's stuff (pilot,blips)"
end

local tp_avenger_menu = menu.add_feature("TP Features","parent",main_menu.id)

local tp_avenger = menu.add_feature("TP on Avenger","action",tp_avenger_menu.id, function()
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    if avenger ~= 0 then
        menu.notify("Avenger found!","Success",nil,0x00FF00)
        entity.set_entity_coords_no_offset(player_ped, entity.get_entity_coords(avenger) + v3(0,0,3))
    else
        menu.notify("No Avenger registered!\nUse 'Find and Register Avenger' to register it","ERROR",nil,0x0000FF)
    end
end)
tp_avenger.hint = "Teleports you on top of your Avenger"

local tp_avenger_inside = menu.add_feature("TP inside Avenger","action",tp_avenger_menu.id, function()
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    if avenger ~= 0 then
        menu.notify("Avenger found!","Success",nil,0x00FF00)
        entity.set_entity_coords_no_offset(player_ped, entity.get_entity_coords(avenger) + v3(0,0,3))
        
        clear_all(nil,true)

        system.yield(50)

        ped.set_ped_into_vehicle(player_ped, avenger, -1)
    else
        menu.notify("No Avenger registered!\nUse 'Find and Register Avenger' to register it","ERROR",nil,0x0000FF)
    end
end)
tp_avenger_inside.hint = "Teleports you inside your Avenger as pilot (Will kill the script's pilot if you do that)"

local tp_avenger_inside_passenger = menu.add_feature("TP inside Avenger as Passenger","action",tp_avenger_menu.id, function()
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    if avenger ~= 0 then
        menu.notify("Avenger found!","Success",nil,0x00FF00)
        entity.set_entity_coords_no_offset(player_ped, entity.get_entity_coords(avenger) + v3(0,0,3))

        system.yield(50)

        ped.set_ped_into_vehicle(player_ped, avenger, 0)
    else
        menu.notify("No Avenger registered!\nUse 'Find and Register Avenger' to register it","ERROR",nil,0x0000FF)
    end
end)
tp_avenger_inside.hint = "Teleports you inside your Avenger as passenger"

local force_avenger_down = menu.add_feature("Force Avenger to Land","action",main_menu.id, function()
    if avenger ~= 0 then
        menu.notify("Forcing Avenger to go Land..","Avenger Utils",nil,0x00AAFF)
        while true do
            local avenger_vel = entity.get_entity_velocity(avenger)
            entity.set_entity_velocity(avenger,v3(avenger_vel.x, avenger_vel.y, -10))
            local height = native.call(0x1DD55701034110E5, avenger):__tonumber()
            system.yield(0)
            if height < 2.8 then
                menu.notify("Avenger touched the floor!","Avenger Utils",nil,0x0FF00)
                vehicle.set_vehicle_engine_on(avenger, false, false, true)
                break
            end
            if not entity.is_an_entity(avenger) then
                break
            end
        end
    else
        menu.notify("No Avenger registered!\nUse 'Find and Register Avenger' to register it","ERROR",nil,0x0000FF)
    end
end)

menu.create_thread(function()
    while true do
        if entity.is_an_entity(avenger or 0) then
            register_avenger.name = "Registered Avenger: "..avenger
        else
            register_avenger.name = "Registered Avenger: ! NONE !"
        end
        system.yield(50)
    end
end)

    

if false then
    local debug_menu = menu.add_feature("Debug","parent",main_menu.id)

    local debug_get_vtol = menu.add_feature("Get VTOL", "action", debug_menu.id, function()
        local local_player = player.player_id()
        local player_pos = player.get_player_coords(local_player)
        local player_ped = player.get_player_ped(local_player)
        local player_heading = player.get_player_heading(local_player)

        local curr_veh = ped.get_vehicle_ped_is_using(player_ped)

        menu.notify("Debug: VTOL: "..native.call(0xDA62027C8BDB326E, curr_veh):__tonumber())
    end)

    local debug_set_vtol = menu.add_feature("Set VTOL", "action_slider", debug_menu.id, function(ft)
        local local_player = player.player_id()
        local player_pos = player.get_player_coords(local_player)
        local player_ped = player.get_player_ped(local_player)
        local player_heading = player.get_player_heading(local_player)

        local curr_veh = ped.get_vehicle_ped_is_using(player_ped)

        native.call(0x30D779DE7C4F6DD3, curr_veh, ft.value)

        menu.notify("Debug: Set VTOL to "..ft.value)
    end)
    debug_set_vtol.min = 0
    debug_set_vtol.max = 90
end