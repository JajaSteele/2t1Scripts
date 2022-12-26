if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Boat requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
    menu.exit()
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

local vehicle_hash = gameplay.get_hash_key("marquis")
local vehicle_name = "marquis"
local ped_hash = 988062523
local vehicle_speed = 35.0
local drive_mode = 787005

local blips = {}
local boat_ped
local boat_veh

local driver_alt_seat = 0

local is_boat_active = false
local clearing = false


local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    print("Deleting",boat_ped)
    entity.delete_entity(boat_ped or 0)

    entity.delete_entity(boat_veh or 0)

    is_boat_active = false
    
    boat_ped = 0
    boat_veh = 0
end

local function clear_all(delay,peds,vehicle,reset)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    menu.create_thread(function()
        local attempts = 0
        for k,v in pairs(blips) do
            repeat
                ui.remove_blip(v)
                attempts = attempts+1
                system.yield(0)
            until native.call(0xE41CA53051197A27, v):__tointeger() == 0 or attempts > 30
            blips = {}
        end
    end)

    menu.create_thread(function()
        local attempts = 0
        if peds and boat_ped ~= nil then
            repeat
                request_control(boat_ped)
                entity.delete_entity(boat_ped)
                system.yield(0)
                attempts = attempts+1
            until not entity.is_an_entity(boat_ped) or attempts > 30
        end
        boat_ped = 0
    end)

    menu.create_thread(function()
        local attempts = 0
        if vehicle and boat_veh ~= nil then
            repeat
                request_control(boat_veh)
                entity.delete_entity(boat_veh)
                attempts = attempts+1
                system.yield(0)
            until not entity.is_an_entity(boat_veh) or attempts > 30
            boat_veh = 0
        end
    end)

    if vehicle and peds and reset then
        is_boat_active = false
    end
end

local function notify(text,title,time,color)
    if is_boat_active and not clearing then
        menu.notify(text,title,time,color)
    end
end

local function yield(num)
    if not clearing then
        system.yield(num)
    end
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


local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Boat", "parent", 0)

local boat_select = menu.add_feature("Boat Model = [marquis]","action",main_menu.id,function(ft)
    local status = 1
    while status == 1 do
        status, vehicle_name = input.get("Name/Hash Input","",15,2)
        system.yield(0)
    end
    vehicle_hash = gameplay.get_hash_key(vehicle_name)

    if not streaming.is_model_a_vehicle(vehicle_hash or 0) then
        vehicle_hash = tonumber(vehicle_name)
    end

    if not streaming.is_model_a_vehicle(vehicle_hash or 0) then
        menu.notify("Warning! Vehicle model doesn't exist!","!WARNING!",nil,0x0000FF)
        ft.name = "Boat Model = [#FF0000FF#ERROR#DEFAULT#]"
        return
    end

    ft.name = "Boat Model = ["..vehicle_name.."]"
end)
boat_select.hint = "Set the model for your boat."

local boat_speed = menu.add_feature("Speed = [35.0]", "action", main_menu.id, function(ft)
    local status = 1
    local temp_speed
    while status == 1 do
        status, temp_speed = input.get("Speed Input","",15,3)
        system.yield(0)
    end
    temp_speed = temp_speed..".0"
    vehicle_speed = tonumber(temp_speed)

    ft.name = "Speed = ["..vehicle_speed.."]"
    
    if is_boat_active then
        menu.notify("Speed updated to "..vehicle_speed,"Updated Speed", nil, 0x00FF00)
        native.call(0x5C9B84BD7D31D908, boat_ped, vehicle_speed)
        native.call(0x404A5AA9B9F0B746, boat_ped, vehicle_speed)
    end
end)
boat_speed.hint = "Choose the speed of the boat. Default is 35.0"

local spawn_boat = menu.add_feature("Spawn Boat","action",main_menu.id,function()
    if not entity.is_an_entity(boat_veh or 0) and not entity.is_an_entity(boat_ped or 0) then
        local local_player = player.player_id()
        local player_pos = player.get_player_coords(local_player)
        local player_ped = player.get_player_ped(local_player)
        local player_heading = player.get_player_heading(local_player)

        local spawn_pos = front_of_pos(player_pos,v3(0,0,player_heading),15)

        request_model(vehicle_hash)
        boat_veh = vehicle.create_vehicle(vehicle_hash, spawn_pos, player_heading, true, false)

        vehicle.set_vehicle_mod_kit_type(boat_veh, 0)
        vehicle.set_vehicle_colors(boat_veh, 12, 141)
        vehicle.set_vehicle_extra_colors(boat_veh, 62, 0)
        vehicle.set_vehicle_window_tint(boat_veh, 1)

        if entity.is_an_entity(boat_veh) then
            blips.boat_veh = ui.add_blip_for_entity(boat_veh)
            ui.set_blip_sprite(blips.boat_veh, 427)
            ui.set_blip_colour(blips.boat_veh, 2)

            native.call(0xF9113A30DE5C6670, "STRING")
            native.call(0x6C188BE134E074AA, "Your Private Boat")
            native.call(0xBC38B49BCB83BC9B, blips.boat_veh)
        end

        request_model(ped_hash)
        boat_ped = ped.create_ped(0, ped_hash, spawn_pos, 0, true, false)

        local seat_count = vehicle.get_vehicle_model_number_of_seats(vehicle_hash)
        if seat_count > 2 then
            driver_alt_seat = 1
        elseif seat_count == 2 then
            driver_alt_seat = 0
        elseif seat_count < 2 then
            driver_alt_seat = -1
        end

        menu.notify("Spawned boat '"..vehicle_name.." with "..seat_count.." seats","Success",nil,0x00FF00)

        ped.set_ped_into_vehicle(boat_ped, boat_veh, driver_alt_seat)

        native.call(0x9F8AA94D6D97DBF4, boat_ped, true)

        native.call(0x1913FE4CBF41C463, boat_ped, 255, true)
        native.call(0x1913FE4CBF41C463, boat_ped, 251, true)
    end
end)

local autpilot_wp = menu.add_feature("Autopilot to WP","action",main_menu.id, function()
    if entity.is_an_entity(boat_veh) and entity.is_an_entity(boat_ped) then
        is_boat_active = true
        local wp = ui.get_waypoint_coord()

        native.call(0x75DBEC174AEEAD10, boat_veh, false)
        ai.task_vehicle_drive_to_coord(boat_ped, boat_veh, v3(wp.x, wp.y, 0.0), vehicle_speed, 0, 0, drive_mode, 60, 0)

        native.call(0x1913FE4CBF41C463, boat_ped, 255, true)
        native.call(0x1913FE4CBF41C463, boat_ped, 251, true)

        while true do
            local boat_pos_live = entity.get_entity_coords(boat_veh)

            local dist_x = math.abs(boat_pos_live.x - wp.x)
            local dist_y = math.abs(boat_pos_live.y - wp.y)

            local hori_dist = dist_x+dist_y
            system.yield(0)
            if hori_dist < 70 then
                repeat
                    system.yield(0)
                until entity.get_entity_speed(boat_veh) < 1 or not entity.is_an_entity(boat_veh)
                break
            end
            if not entity.is_an_entity(boat_veh) then
                break
            end
        end
        native.call(0x75DBEC174AEEAD10, boat_veh, true)

        ai.task_enter_vehicle(boat_ped, boat_veh, 10000, driver_alt_seat, 1, 1, 0)
        is_boat_active = false
    end
end)

local clean_boat = menu.add_feature("Clear All","action",main_menu.id,function()
    clear_all(nil,true,true,false)
    clearing = true
end)
clean_boat.hint = "Clean up boat + driver (Might take a while before being inactive)"

menu.create_thread(function()
    while true do
        if entity.is_an_entity(boat_veh or 0) then
            local curr_heading = entity.get_entity_heading(boat_veh)
            native.call(0xA8B6AFDAC320AC87, blips.boat_veh, curr_heading)
        end
        system.yield(0)
    end
end)

event.add_event_listener("exit", clear_all_noyield)