if menu.get_trust_flags() ~= (1 << 2) then
    menu.notify("JJS Taxi requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
end

local function request_model(_hash)
    if not streaming.has_model_loaded(_hash) then
        streaming.request_model(_hash)
        while (not streaming.has_model_loaded(_hash)) do
            system.yield(10)
        end
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

local plane_hash = gameplay.get_hash_key("luxor2")
local ped_hash = 988062523

local blips = {}
local plane_ped = 0
local plane_veh = 0
local is_plane_active = false

local function get_free_seats(veh)
    local veh_hash = entity.get_entity_model_hash(veh)
    local seat_count = vehicle.get_vehicle_model_number_of_seats(veh_hash)
    local counter = seat_count
    for i1=1, seat_count do
        local ped_in_seat = vehicle.get_ped_in_vehicle_seat(veh, i1-2)
        if ped_in_seat and ped_in_seat ~= 0 then
            counter = counter-1
        end
    end
    return counter
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

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    print("Deleting",plane_ped)
    entity.delete_entity(plane_ped or 0)
    entity.delete_entity(plane_ped2 or 0)

    entity.delete_entity(plane_veh or 0)

    is_plane_active = false
    
    plane_ped = 0
    plane_veh = 0
end

local function clear_all(delay,peds,vehicle)
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

    if peds and plane_ped ~= nil then
        repeat
            network.request_control_of_entity(plane_ped)
            entity.delete_entity(plane_ped)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(plane_ped) or attempts > 100
    end

    local attempts = 0

    if peds and plane_ped2 ~= nil then
        repeat
            network.request_control_of_entity(plane_ped2)
            entity.delete_entity(plane_ped2)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(plane_ped2) or attempts > 100
    end

    local attempts = 0

    if vehicle and plane_veh ~= nil then
        repeat
            network.request_control_of_entity(plane_veh)
            entity.delete_entity(plane_veh)
            attempts = attempts+1
            system.yield(0)
        until not entity.is_an_entity(plane_veh) or attempts > 100
        plane_veh = 0
    end

    if vehicle and peds then
        is_plane_active = false
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

local airstrips = {
    {
        start1={x=-1572.8286132812, y=-3007.3989257812, z=12.94482421875}, 
        end1={x=-1195.5294189453, y=-3223.857421875, z=12.944519042969},
        name="LS International Airport"
    },
    {
        start1={x=1080.81640625, y=3084.1984863281, z=39.442565917969}, 
        end1={x=1624.3011474609, y=3230.3825683594, z=39.411560058594},
        name="Sandy Shores Airfield"
    },
    {
        start1={x=1930.5744628906, y=4713.5478515625, z=41.147357940674},
        end1={x=2133.5227050781, y=4810.1083984375, z=41.195930480957},
        name="McKenzie Field (UNSAFE)",
        land_alt_override = 30,
        land_speed_override = 100
    },
    {
        start1={x=-2757.8442382812, y=3295.87109375, z=31.811828613281},
        end1={x=-2052.4370117188, y=2885.2524414062, z=31.810424804688},
        name="Fort Zancudo"
    }
}

local select_data = {}
for k,v in ipairs(airstrips) do
    select_data[#select_data+1] = v.name
end


local main_menu = menu.add_feature("JJS Airline", "parent", 0)

local select_strip = menu.add_feature("Destination","autoaction_value_str",main_menu.id,function()
end)
select_strip:set_str_data(select_data)
select_strip.hint = "Select the airstrip to land at. \nMcKenzie Field is unsafe cuz too small runway (high risk of crash)"

local spawn_plane = menu.add_feature("Spawn Plane","action",main_menu.id,function()
    local dest = airstrips[select_strip.value+1]
    is_plane_active = true
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    local spawn_pos = front_of_pos(player_pos, v3(0, 0, player_heading), 10)

    request_model(plane_hash)
    plane_veh = vehicle.create_vehicle(plane_hash, spawn_pos, player_heading, true, false)
    streaming.set_model_as_no_longer_needed(plane_hash)

    system.yield(0)

    vehicle.set_vehicle_on_ground_properly(plane_veh)

    request_model(ped_hash)
    plane_ped = ped.create_ped(0, ped_hash, spawn_pos + v3(0,0,2), player_heading, true, false)
    streaming.set_model_as_no_longer_needed(ped_hash)

    system.yield(50)

    vehicle.set_vehicle_mod_kit_type(plane_veh, 0)
    vehicle.set_vehicle_colors(plane_veh, 107, 99)
    vehicle.set_vehicle_extra_colors(plane_veh, 36, 0)
    vehicle.set_vehicle_window_tint(plane_veh, 1)

    native.call(0xBE70724027F85BCD, plane_veh, 0, 3)
    native.call(0xBE70724027F85BCD, plane_veh, 1, 3)

    native.call(0x2311DD7159F00582, plane_veh, true)
    native.call(0xDBC631F109350B8C, plane_veh, true)

    system.yield(500)

    ped.set_ped_into_vehicle(plane_ped, plane_veh, -1)

    system.yield(0)

    native.call(0x9F8AA94D6D97DBF4, plane_ped, true)
    native.call(0x1913FE4CBF41C463, plane_ped, 255, true)
    native.call(0x1913FE4CBF41C463, plane_ped, 251, true)
    native.call(0x1913FE4CBF41C463, plane_ped, 184, true)
    native.call(0x1913FE4CBF41C463, player_ped, 184, true)

    repeat
        system.yield(0)
    until ped.is_ped_in_vehicle(plane_ped, plane_veh) and ped.is_ped_in_vehicle(player_ped, plane_veh) or not is_plane_active
    vehicle.set_vehicle_engine_on(plane_veh, true, false, true)

    local plane_pos = entity.get_entity_coords(plane_veh)
    local plane_heading = entity.get_entity_rotation(plane_veh)

    local take_off_pos = front_of_pos(plane_pos, plane_heading, 500) + v3(0,0,50)

    local landstart = v3(dest.start1.x, dest.start1.y, dest.start1.z)
    local landend = v3(dest.end1.x, dest.end1.y, dest.end1.z)

    local landstart_corrected = front_of_pos(landstart, v3(0,0,vector_to_heading(landstart,landend)), 2500)
    local landstart_start = front_of_pos(landstart, v3(0,0,vector_to_heading(landstart,landend)), 250)

    ai.task_vehicle_drive_to_coord(plane_ped, plane_veh, take_off_pos, 300, 0, plane_hash, 0, 80,0)
    menu.notify("Taking off now!","Taking off",nil,0x00AAFF)

    while true do
        system.yield(0)
        local plane_pos_live = entity.get_entity_coords(plane_veh)
        if plane_pos_live.z > take_off_pos.z-5 or not is_plane_active then
            break
        end
    end



    vehicle.control_landing_gear(plane_veh, 1)

    menu.notify("Flying toward "..dest.name,"Flying",nil,0x00AAFF)

    ai.task_vehicle_drive_to_coord(plane_ped, plane_veh, landstart_corrected+v3(0,0,200), 300, 0, plane_hash, 0, 200,0)

    while true do
        local plane_pos_live = entity.get_entity_coords(plane_veh)

        local dist_x = math.abs(plane_pos_live.x - landstart_corrected.x)
        local dist_y = math.abs(plane_pos_live.y - landstart_corrected.y)
        local dist_z = math.abs(plane_pos_live.z - landstart_corrected.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 250 or not is_plane_active then
            break
        end
        system.yield(0)
    end

    ai.task_vehicle_drive_to_coord(plane_ped, plane_veh, landstart_start+v3(0,0,dest.land_alt_override or 100), dest.land_speed_override or 300, 0, plane_hash, 0, 200,0)

    menu.notify("Preparing to Land at Dest!","Landing Prep",nil,0x00AAFF)


    while true do
        local plane_pos_live = entity.get_entity_coords(plane_veh)

        local dist_x = math.abs(plane_pos_live.x - landstart_start.x)
        local dist_y = math.abs(plane_pos_live.y - landstart_start.y)
        local dist_z = math.abs(plane_pos_live.z - landstart_start.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 250 or not is_plane_active then
            break
        end
        system.yield(0)
    end

    menu.notify("Landing at Dest!","Landing",nil,0x00AAFF)

    
    native.call(0xBF19721FA34D32C0, plane_ped, plane_veh, landstart, landend)

    while true do
        if entity.get_entity_speed(plane_veh) < 3 then
            vehicle.set_vehicle_engine_on(plane_veh, false, false, true)
            break
        end
        system.yield(0)
    end

    menu.notify("Welcome to "..dest.name.."! Please exit the jet shortly.","Welcome",nil,0x00FF00)

    repeat
        system.yield(0)
        local taken_seats = get_taken_seats(plane_veh)
    until taken_seats <= 1

    system.yield(5000)

    clear_all(nil, true, true)
    
    menu.notify("Thanks you for using JJS Airline!","Thanks You!",nil,0x00AAFF)
    is_plane_active = false
end)
spawn_plane.hint = "Spawns your private jet , waiting for you to get inside!"

local clean_plane = menu.add_feature("Clear All","action",main_menu.id,function()
    clear_all(nil,true,true)
end)
clean_plane.hint = "Clean up plane + pilot"

if false then --ENABLES DEBUG FUNCTIONS

    local get_wp = menu.add_feature("Print WP","action",main_menu.id,function()
        local wp_pos = ui.get_waypoint_coord()
        local groundz = get_ground(wp_pos)
        menu.notify("X: "..wp_pos.x.." Y: "..wp_pos.y.." Z: "..groundz,"Coords",nil,0x00FF00)
        utils.to_clipboard("x="..wp_pos.x..", y="..wp_pos.y..", z="..groundz)
    end)

    local get_pl = menu.add_feature("Print PL pos","action",main_menu.id,function()
        local local_player = player.player_id()
        local pl_pos = player.get_player_coords(local_player)
        menu.notify("X: "..pl_pos.x.." Y: "..pl_pos.y.." Z: "..pl_pos.z,"Coords",nil,0x00FF00)
        utils.to_clipboard("x="..pl_pos.x..", y="..pl_pos.y..", z="..pl_pos.z)
    end)

    local random_test = menu.add_feature("Get seats", "action", main_menu.id, function()
        menu.notify(tostring(vehicle.get_free_seat(plane_veh),"Test",nil,0x00FFFF))
    end)
end

event.add_event_listener("exit", clear_all_noyield)