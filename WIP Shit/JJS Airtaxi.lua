if menu.get_trust_flags() ~= (1 << 2) then
    menu.notify("JJS Airtaxi requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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

local vehicle_hash = gameplay.get_hash_key("swift2")
local vehicle_name = "swift2"
local ped_hash = 988062523

local blips = {}
local heli_ped
local heli_veh

local is_heli_active = false

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    print("Deleting",heli_ped)
    entity.delete_entity(heli_ped or 0)

    entity.delete_entity(heli_veh or 0)

    is_heli_active = false
    
    heli_ped = 0
    heli_veh = 0
end

local function clear_all(delay,peds,vehicle,reset)
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

    if peds and heli_ped ~= nil then
        request_control(heli_ped)
        repeat
            entity.delete_entity(heli_ped)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(heli_ped) or attempts > 300
    end

    local attempts = 0

    if vehicle and heli_veh ~= nil then
        request_control(heli_veh)
        repeat
            entity.delete_entity(heli_veh)
            attempts = attempts+1
            system.yield(0)
        until not entity.is_an_entity(heli_veh) or attempts > 300
        heli_veh = 0
    end

    if vehicle and peds and (reset or true) then
        is_heli_active = false
    end
end

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

local function get_water(pos)

    native.call(0x7E3F55ED251B76D3, 0)
    for k,v in ipairs(ground_check) do
        native.call(0x07503F7948F491A7, v3(pos.x, pos.y, v))
        system.yield(0)
    end

    system.yield(1500)

    for k,v in ipairs(ground_check) do
        local destv3_check = v3(pos.x, pos.y, v)
        local waterz = native.ByteBuffer8()
        native.call(0xF6829842C06AE524, destv3_check, waterz)
        print(waterz:__tonumber())
        if waterz:__tonumber() ~= 0 then
            return waterz:__tonumber()
        end
        system.yield(0)
    end

    return 0
end

local function get_taken_seats(veh)
    local veh_hash = entity.get_entity_model_hash(veh)
    local seat_count = vehicle.get_vehicle_model_number_of_seats(veh_hash)
    local counter = 0
    for i1=1, seat_count do
        local ped_in_seat = vehicle.get_ped_in_vehicle_seat(veh, i1-2)
        if ped_in_seat and ped_in_seat ~= 0 then
            counter = counter+1
        end
    end
    return counter
end

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Airtaxi", "parent", 0)

local heli_allowfront = menu.add_feature("Allow Front Passenger", "toggle", main_menu.id, function(ft)
    if is_heli_active then
        if ft.on then
            native.call(0xBE70724027F85BCD, heli_veh or 0, 1, 0)
            native.call(0xBE70724027F85BCD, heli_veh or 0, 0, 0)
        else
            native.call(0xBE70724027F85BCD, heli_veh or 0, 1, 3)
            native.call(0xBE70724027F85BCD, heli_veh or 0, 0, 3)
        end
    end
end)
heli_allowfront.hint = "Allows the player to enter front passenger seat"
heli_allowfront.on = true

local spawn_heli = menu.add_feature("Spawn Heli", "action", main_menu.id, function()
    is_heli_active = true
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    local spawn_pos = player_pos+v3(0,0,35)

    request_model(vehicle_hash)
    heli_veh = vehicle.create_vehicle(vehicle_hash, spawn_pos, player_heading, true, false)
    vehicle.set_heli_blades_full_speed(heli_veh)
    native.call(0x2311DD7159F00582, heli_veh, true)
    native.call(0xDBC631F109350B8C, heli_veh, true)

    if heli_allowfront.on then
        native.call(0xBE70724027F85BCD, heli_veh, 0, 0)
        native.call(0xBE70724027F85BCD, heli_veh, 1, 0)
    else
        native.call(0xBE70724027F85BCD, heli_veh, 0, 3)
        native.call(0xBE70724027F85BCD, heli_veh, 1, 3)
    end


    request_model(ped_hash)
    heli_ped = ped.create_ped(0, ped_hash, spawn_pos, 0, true, false)
    ped.set_ped_into_vehicle(heli_ped, heli_veh, -1)
    native.call(0x9F8AA94D6D97DBF4, heli_ped, true)
    native.call(0x1913FE4CBF41C463, heli_ped, 255, true)
    native.call(0x1913FE4CBF41C463, heli_ped, 251, true)

    native.call(0x1F4ED342ACEFE62D, heli_ped, true, true)
    native.call(0x1F4ED342ACEFE62D, heli_veh, true, true)

    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, spawn_pos.x, spawn_pos.y, spawn_pos.z, 4, 50, -1, -1, 10, 10, 5.0, 32)

    print("Heli ID: "..heli_veh)
    utils.to_clipboard(heli_veh)

    repeat
        system.yield(0)
        if native.call(0x634148744F385576, heli_veh):__tointeger() == 1 then
            local curr_vel = entity.get_entity_velocity(heli_veh)
            entity.set_entity_velocity(heli_veh, v3(curr_vel.x, curr_vel.y, -0.75))
        end
    until native.call(0x1DD55701034110E5, heli_veh):__tonumber() < 1

    menu.notify("Greetings.\nEnter the helicopter to start.","JJS Airtaxi",nil,0xFF00FF)

    repeat
        system.yield(0)
    until ped.is_ped_in_vehicle(player_ped, heli_veh)

    system.yield(2000)

    local wp = ui.get_waypoint_coord()
    local wpz = get_ground(wp)

    local wp3 = v3(wp.x, wp.y, wpz+100)

    menu.notify("Flying to:\nX: "..wp3.x.." Y: "..wp3.y.." Z: "..wp3.z,"Flying to Dest",nil,0x00AAFF)

    print("Flying to dest")
    request_control(heli_veh)
    request_control(heli_ped)
    native.call(0xE1EF3C1216AFF2CD, heli_ped)
    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, 50, -1, -1, 10, 10, 5.0, 0)

    while true do
        local heli_pos_live = entity.get_entity_coords(heli_veh)

        local dist_x = math.abs(heli_pos_live.x - wp3.x)
        local dist_y = math.abs(heli_pos_live.y - wp3.y)
        local dist_z = math.abs(heli_pos_live.z - wp3.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 100 or not is_heli_active then
            native.call(0x5C9B84BD7D31D908, heli_ped, 40)
            break
        end
        system.yield(0)
    end

    print("Landing to dest")
    request_control(heli_veh)
    request_control(heli_ped)
    native.call(0xE1EF3C1216AFF2CD, heli_ped)
    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3, 4, 80, -1, -1, 10, 10, 5.0, 32)

    repeat
        system.yield(0)
        if native.call(0x634148744F385576, heli_veh):__tointeger() == 1 then
            local curr_vel = entity.get_entity_velocity(heli_veh)
            entity.set_entity_velocity(heli_veh, v3(curr_vel.x, curr_vel.y, -0.75))
        end
    until native.call(0x1DD55701034110E5, heli_veh):__tonumber() < 1

    system.yield(1000)

    menu.notify("Landed at destination! Please exit shortly.","JJS Airtaxi",nil,0x00AAFF)

    repeat
        system.yield(0)
    until get_taken_seats(heli_veh) <= 1

    system.yield(1000)

    native.call(0xDE564951F95E09ED, heli_veh, true, true)
    native.call(0xDE564951F95E09ED, heli_ped, true, true)

    system.yield(2000)

    clear_all(nil,true,true)
    is_heli_active = false
end)

event.add_event_listener("exit", clear_all_noyield)