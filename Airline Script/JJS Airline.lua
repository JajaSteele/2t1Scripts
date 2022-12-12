if menu.get_trust_flags() ~= (1 << 2) then
    menu.notify("JJS Airline requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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

function vector_to_heading(_target,_start)
    return math.atan((_target.x - _start.x), (_target.y - _start.y)) * -180 / math.pi
end

local plane_name = "luxor2"
local plane_hash = gameplay.get_hash_key(plane_name)
local ped_hash = 988062523

local blips = {}
local plane_ped = 0
local plane_veh = 0
local is_plane_active = false

local trans_veh_name = "sanchez2"
local trans_veh_hash = gameplay.get_hash_key(trans_veh_name)

local function notify(text,title,dur,color)
    if is_plane_active then
        menu.notify(text,title,dur,color)
    end
end

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

    if peds and plane_ped ~= nil then
        request_control(plane_ped)
        repeat
            entity.delete_entity(plane_ped)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(plane_ped) or attempts > 300
    end

    local attempts = 0

    if vehicle and plane_veh ~= nil then
        request_control(plane_veh)
        repeat
            entity.delete_entity(plane_veh)
            attempts = attempts+1
            system.yield(0)
        until not entity.is_an_entity(plane_veh) or attempts > 300
        plane_veh = 0
    end

    if vehicle and peds and (reset or true) then
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
        start1={x=-1607.3388671875, y=-2792.3530273438, z=13.976312637329}, 
        end1={x=-1037.4422607422, y=-3121.7915039062, z=13.944439888},
        name="LS International Airport"
    },
    {
        start1={x=1080.81640625, y=3084.1984863281, z=39.442565917969}, 
        end1={x=1624.3011474609, y=3230.3825683594, z=39.411560058594},
        name="Sandy Shores Airfield"
    },
    {
        start1={x=2133.5227050781, y=4810.1083984375, z=41.195930480957},
        end1={x=1930.5744628906, y=4713.5478515625, z=41.147357940674},
        name="McKenzie Field (UNSAFE)",
        land_alt_override = 15,
        land_speed_override = 100
    },
    {
        start1={x=-2757.8442382812, y=3295.87109375, z=31.811828613281},
        end1={x=-2052.4370117188, y=2885.2524414062, z=31.810424804688},
        name="Fort Zancudo"
    },
    {
        start1={x=-2088.0224609375, y=-539.79089355469, z=4.1331868171692},
        end1={x=-1886.7368164062, y=-783.20489501953, z=3.5499956607819},
        name="Vespucci Beach"
    },
    {
        start1={x=-617.43798828125, y=6329.6518554688, z=3.4301686286926},
        end1={x=-280.55834960938, y=6537.935546875, z=2.8661694526672},
        name="Procopio Beach"
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
select_strip.hint = "Select the airstrip to land at. \nMcKenzie Field is unsafe cuz too small runway (high risk of crash)\n\nI found out the vehicle 'seabreeze' easily lands at McKenzie!"

local trans_vehicle = menu.add_feature("Transport Vehicle = [sanchez2]","action",main_menu.id,function(ft)
    local status = 1
    while status == 1 do
        status, trans_veh_name = input.get("Name/Hash Input","",15,2)
        system.yield(0)
    end
    trans_veh_hash = gameplay.get_hash_key(trans_veh_name)

    if not streaming.is_model_a_vehicle(trans_veh_hash) then
        trans_veh_hash = tonumber(trans_veh_name)
    end

    if not streaming.is_model_a_vehicle(trans_veh_hash) then
        menu.notify("Warning! Vehicle model doesn't exist!","!WARNING!",nil,0x0000FF)
    end

    ft.name = "Transport Vehicle = ["..trans_veh_name.."]"
end)
trans_vehicle.hint = "Set the model for the Transport Vehicle (See below for explanation)"

local trans_vehicle_toggle = menu.add_feature("Transport Vehicle","autoaction_value_str",main_menu.id,function()
end)
trans_vehicle_toggle.hint = "The Transport Vehicle spawns at your destination, right after the plane itself despawns. \nUseful to get out of airport more easily!"
trans_vehicle_toggle:set_str_data({"None","Spawn","Personal"})

local plane_allowfront = menu.add_feature("Allow Front Passenger", "toggle", main_menu.id, function(ft)
    if is_plane_active then
        if ft.on then
            native.call(0xBE70724027F85BCD, plane_veh or 0, 1, 0)
            native.call(0xBE70724027F85BCD, plane_veh or 0, 0, 0)
        else
            native.call(0xBE70724027F85BCD, plane_veh or 0, 1, 3)
            native.call(0xBE70724027F85BCD, plane_veh or 0, 0, 3)
        end
    end
end)
plane_allowfront.hint = "Allows the player to enter front passenger seat"
plane_allowfront.on = true

local plane_select = menu.add_feature("Plane Model = [luxor2]","action",main_menu.id,function(ft)
    local status = 1
    while status == 1 do
        status, plane_name = input.get("Name/Hash Input","",15,2)
        system.yield(0)
    end
    plane_hash = gameplay.get_hash_key(plane_name)

    if not streaming.is_model_a_vehicle(plane_hash) then
        plane_hash = tonumber(plane_name)
    end

    if not streaming.is_model_a_vehicle(plane_hash) then
        menu.notify("Warning! Vehicle model doesn't exist!","!WARNING!",nil,0x0000FF)
    end

    ft.name = "Plane Model = ["..plane_name.."]"
end)
plane_select.hint = "Set the model for your plane.\nMight not work well with every plane (GTA's AI at fault lol)"

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
    native.call(0x1F4ED342ACEFE62D, plane_veh, true, true)

    system.yield(0)

    vehicle.set_vehicle_on_ground_properly(plane_veh)

    if entity.is_an_entity(plane_veh) then
        blips.private_jet = ui.add_blip_for_entity(plane_veh)
        ui.set_blip_sprite(blips.private_jet, 307)
        ui.set_blip_colour(blips.private_jet, 2)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Your Private Plane")
        native.call(0xBC38B49BCB83BC9B, blips.private_jet)
    end

    request_model(ped_hash)
    plane_ped = ped.create_ped(0, ped_hash, spawn_pos + v3(0,0,2), player_heading, true, false)
    streaming.set_model_as_no_longer_needed(ped_hash)

    native.call(0x1F4ED342ACEFE62D, plane_ped, true, true)

    system.yield(50)

    vehicle.set_vehicle_mod_kit_type(plane_veh, 0)
    vehicle.set_vehicle_colors(plane_veh, 107, 99)
    vehicle.set_vehicle_extra_colors(plane_veh, 36, 0)
    vehicle.set_vehicle_window_tint(plane_veh, 1)

    
    if plane_allowfront.on then
        native.call(0xBE70724027F85BCD, plane_veh, 0, 0)
        native.call(0xBE70724027F85BCD, plane_veh, 1, 0)
    else
        native.call(0xBE70724027F85BCD, plane_veh, 0, 3)
        native.call(0xBE70724027F85BCD, plane_veh, 1, 3)
    end

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

    blips.dest_travel = ui.add_blip_for_coord(landstart_corrected)
    ui.set_blip_sprite(blips.dest_travel, 58)
    ui.set_blip_colour(blips.dest_travel, 5)

    native.call(0xF9113A30DE5C6670, "STRING")
    native.call(0x6C188BE134E074AA, "Destination")
    native.call(0xBC38B49BCB83BC9B, blips.dest_travel)

    ai.task_vehicle_drive_to_coord(plane_ped, plane_veh, take_off_pos, 300, 0, plane_hash, 0, 80,0)

    notify("Taking off now!","Taking off",nil,0x00AAFF)

    while true do
        system.yield(0)
        local plane_pos_live = entity.get_entity_coords(plane_veh)
        if plane_pos_live.z > take_off_pos.z-5 or not is_plane_active then
            break
        end
    end

    ai.task_vehicle_drive_to_coord(plane_ped, plane_veh, landstart_corrected+v3(0,0,200), 300, 0, plane_hash, 0, 200,0)

    request_control(plane_veh)
    vehicle.control_landing_gear(plane_veh, 1)
    notify("Flying toward "..dest.name,"Flying",nil,0x00AAFF)

    

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

    ai.task_vehicle_drive_to_coord(plane_ped, plane_veh, landstart_start+v3(0,0,dest.land_alt_override or 75), dest.land_speed_override or 300, 0, plane_hash, 0, 200,0)
    notify("Preparing to Land at Dest!","Landing Prep",nil,0x00AAFF)

    if blips.dest_travel then
        ui.remove_blip(blips.dest_travel)
        blips.dest_travel = nil
    end

    blips.dest_start = ui.add_blip_for_coord(v3(dest.start1.x, dest.start1.y, dest.start1.z))
    ui.set_blip_sprite(blips.dest_start, 6)
    ui.set_blip_colour(blips.dest_start, 2)
    native.call(0xA8B6AFDAC320AC87, blips.dest_start, vector_to_heading(landend,landstart))
    

    blips.dest_end = ui.add_blip_for_coord(v3(dest.end1.x, dest.end1.y, dest.end1.z))
    ui.set_blip_sprite(blips.dest_end, 6)
    ui.set_blip_colour(blips.dest_end, 1)
    native.call(0xA8B6AFDAC320AC87, blips.dest_end, vector_to_heading(landend,landstart))


    native.call(0xF9113A30DE5C6670, "STRING")
    native.call(0x6C188BE134E074AA, "Runway Start")
    native.call(0xBC38B49BCB83BC9B, blips.dest_start)

    native.call(0xF9113A30DE5C6670, "STRING")
    native.call(0x6C188BE134E074AA, "Runway End")
    native.call(0xBC38B49BCB83BC9B, blips.dest_end)
    


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

    notify("Landing at Dest!","Landing",nil,0x00AAFF)

    request_control(plane_veh)
    native.call(0xBF19721FA34D32C0, plane_ped, plane_veh, landstart, landend)

    while true do
        if entity.get_entity_speed(plane_veh) < 3 then
            vehicle.set_vehicle_engine_on(plane_veh, false, false, true)
            break
        end
        system.yield(0)
    end

    notify("Welcome to "..dest.name.."! Please exit the jet shortly.","Welcome",nil,0x00FF00)

    repeat
        system.yield(0)
        local taken_seats = get_taken_seats(plane_veh)
    until taken_seats <= 1

    system.yield(3000)

    local last_plane_coord = entity.get_entity_coords(plane_veh)
    local last_plane_heading = entity.get_entity_heading(plane_veh)

    native.call(0xDE564951F95E09ED, plane_veh, true, true)
    native.call(0xDE564951F95E09ED, plane_ped, true, true)
    
    notify("Thanks you for using JJS Airline!","Thanks You!",nil,0x00AAFF)

    system.yield(2000) 

    if is_plane_active then
        if trans_vehicle_toggle.value == 1 or (trans_vehicle_toggle.value == 2 and player.get_personal_vehicle() == 0) then
            system.yield(500)

            request_model(trans_veh_hash)
            local trans_veh_veh = vehicle.create_vehicle(trans_veh_hash, last_plane_coord, last_plane_heading, true, false)
            native.call(0x1F4ED342ACEFE62D, trans_veh_veh, true, true)
            system.yield(0)
            vehicle.set_vehicle_on_ground_properly(trans_veh_veh)
            streaming.set_model_as_no_longer_needed(trans_veh_hash)

            menu.notify("Your Transport Vehicle has been delivered!","Delivered",nil,0x00FF00)

            vehicle.set_vehicle_mod_kit_type(trans_veh_veh, 0)

            vehicle.set_vehicle_colors(trans_veh_veh, 12, 12)
            vehicle.set_vehicle_extra_colors(trans_veh_veh, 64, 62)
            vehicle.set_vehicle_window_tint(trans_veh_veh, 1)

            vehicle.set_vehicle_mod(trans_veh_veh, 11, 3)
            vehicle.set_vehicle_mod(trans_veh_veh, 15, 3)
            vehicle.set_vehicle_mod(trans_veh_veh, 16, 4)
            vehicle.set_vehicle_mod(trans_veh_veh, 12, 2)
            vehicle.set_vehicle_mod(trans_veh_veh, 18, 1)
        elseif trans_vehicle_toggle.value == 2 and player.get_personal_vehicle() ~= 0 then
            if not entity.is_an_entity(player.get_personal_vehicle()) or (entity.is_entity_dead(player.get_personal_vehicle())) then
                menu.get_feature_by_hierarchy_key("online.services.personal_vehicles.claim_all_destroyed_vehicles"):toggle()
                system.yield(500)
                menu.get_feature_by_hierarchy_key("online.services.personal_vehicles.request_current_vehicle"):toggle()
                repeat
                    system.yield(20)
                until entity.is_an_entity(player.get_personal_vehicle())
                system.yield(3000)
            end

            system.yield(1000)

            local trans_veh_veh = player.get_personal_vehicle()
            request_control(trans_veh_veh)
            entity.set_entity_coords_no_offset(trans_veh_veh, last_plane_coord)
            entity.set_entity_rotation(trans_veh_veh, v3(0, 0, last_plane_heading))

            native.call(0x1F4ED342ACEFE62D, trans_veh_veh, true, true)
            system.yield(0)
            vehicle.set_vehicle_on_ground_properly(trans_veh_veh)

            menu.notify("Your Personal Transport Vehicle has been delivered!","Delivered",nil,0x00FF00)
        end
    end

    clear_all(nil,true,true)

    is_plane_active = false
end)
spawn_plane.hint = "Spawns your private jet , waiting for you to get inside!"

local plane_status = menu.add_feature("Status: ", "action", main_menu.id, function()
    menu.notify("idk what you expected to happen, but hello","fard",nil,0x00FF00)
end)
plane_status.hint = "The current status of the plane script"

local clean_plane = menu.add_feature("Clear All","action",main_menu.id,function()
    clear_all(nil,true,true,false)
end)
clean_plane.hint = "Clean up plane + pilot"

local status_thread = menu.create_thread(function()
    while true do
        if is_plane_active then
            plane_status.name = ("Status: Active")
        else
            plane_status.name = ("Status: Inactive")
        end
        system.yield(500)
    end
end)

local plane_blip_rot = menu.create_thread(function()
    while true do
        if is_plane_active and native.call(0xA6DB27D19ECBB7DA, blips.private_jet or 0):__tointeger() == 1 and entity.is_an_entity(plane_veh or 0) then
            local curr_heading = entity.get_entity_heading(plane_veh)
            native.call(0xA8B6AFDAC320AC87, blips.private_jet, curr_heading)
        end
        system.yield(0)
    end
end)

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

    local fade_out = menu.add_feature("Fade out plane","action",main_menu.id,function()
        native.call(0xDE564951F95E09ED, plane_veh, true, true)
    end)
end

event.add_event_listener("exit", clear_all_noyield)