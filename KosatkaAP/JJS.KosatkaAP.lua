if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Kosatka Autopilot requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/KosatkaAP/JJS.KosatkaAP.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.KosatkaAP.lua"

        local file1 = io.open(path, "r")
        local curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS KosatkaAP",nil,0x00AAFF)
            local choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS KosatkaAP",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS KosatkaAP",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS KosatkaAP",nil,0xFF00FF)
            print("Update HTTP for JJS KosatkaAP: "..code)
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

local ped_hash = 988062523
local toreador_hash = gameplay.get_hash_key("toreador")
local boat_hash = gameplay.get_hash_key("dinghy")

local sub_pilot = 0
local toreador_pilot = 0
local toreador = 0

local boat = 0
local boat_pilot = 0

local extboat = 0
local extboat_pilot = 0

local blips = {}

local sub_veh = 0
local vehicle_drive = 1076632110
local vehicle_drive_close = 1076632111
local vehicle_drive_careful = 16777728
local boat_drive = 16777275

local boat_dest_ent = 0
local boat_dest_ent2 = 0
local extboat_dest_ent = 0

local autopilot_speed = 80.0
local autopilot_depth = -2.0

local kosatka_registered = false

local is_diving = false
local is_ap = false

local ini_cfg = IniParser("scripts/JJS.KosatkaAP.ini")
ini_cfg:read()

local ground_check = {900}
repeat
    ground_check[#ground_check+1] = ground_check[#ground_check] - 25
until ground_check[#ground_check] < 26

local beach_locations = {
    {x = 709.8127, y = 6699.7803, z = 0},
    {x = 1551.805, y = 6686.0522, z = 0},
    {x = 3260.507, y = 5309.454, z = 0},
    {x = 3788.334, y = 3812.6934, z = 0},
    {x = 2945.665, y = 1773.1919, z = 0},
    {x = 2866.816, y = -658.5848, z = 0},
    {x = 2342.881, y = -2167.953, z = 0},
    {x = 1215.167, y = -2728.054, z = 0},
    {x = 1305.229, y = -3364.572, z = 0},
    {x = 293.8953, y = -3361.616, z = 0},
    {x = -484.948, y = -2940.643, z = 0},
    {x = -1387.61, y = -1704.374, z = 0},
    {x = -1566.04, y = -1312.232, z = 0},
    {x = -1920.23, y = -849.6466, z = 0},
    {x = -2876.76, y = -74.3269, z = 0},
    {x = -3133.45, y = 604.7179, z = 0},
    {x = -3286.57, y = 1285.3721, z = 0},
    {x = -3205.53, y = 3285.1995, z = 0},
    {x = -2520.42, y = 4240.6714, z = 0},
    {x = -909.632, y = 5830.909, z = 0},
    {x = -325.109, y = 6584.622, z = 0},
    {x = -325.109, y = 6584.622, z = 0},
    {x = -2775.0, y = 2597.0, z = 0},
    {x = -2950.2946777344, y = 3003.8515625, z = 0.0},
    {x = -2606.4995117188, y = 3896.0046386719, z = 0.0},
    {x = -617.99377441406, y = 6421.396484375, z = 0.0},
    {x = 2491.4553222656, y = 6645.892578125, z = 0.0},
    {x = 3980.8193359375, y = 4010.240234375, z = 0.0},
    {x = 3235.1391601562, y = 2053.9506835938, z = 0.0},
    {x = 2983.0793457031, y = 714.33325195312, z = 0.0},
    {x = -2127.4680175781, y = -602.19708251953, z = 0.0},
    {x = -2545.6918945312, y = -292.43606567383, z = 0.0},
}

local function sort_by_dist(a,b)
    return (a.dist < b.dist)
end

local function find_closest_beach(pos)
    local results = {}
    for k,v in pairs(beach_locations) do
        results[#results+1] = {dist = pos:magnitude(v3(v.x, v.y, v.z)), key = k}
    end
    table.sort(results, sort_by_dist)
    local res = beach_locations[results[1].key]
    return v3(res.x, res.y, res.z)
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

local function find_veh(blipicon)
    local counter = 0
    while true do
        local veh_blip
        if counter == 0 then
            veh_blip = native.call(0x1BEDE233E6CD2A1F, blipicon):__tointeger()
        else
            veh_blip = native.call(0x14F96AA50D6FBEA7, blipicon):__tointeger()
        end

        if veh_blip == 0 then
            return 0
        end

        if native.call(0xDA5F8727EB75B926, veh_blip):__tointeger() == 0 then
            return ui.get_entity_from_blip(veh_blip)
        end

        counter = counter+1
        system.yield(0)
    end
end
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

local function vector_to_heading(_target,_start)
    return math.atan((_target.x - _start.x), (_target.y - _start.y)) * -180 / math.pi
end

local function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

local main = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Kosatka AP","parent",0)
local ap_kosatka = menu.add_feature("Kosatka AP", "parent", main.id)
local ap_toreador = menu.add_feature("Toreador AP", "parent", main.id)
local ap_boat = menu.add_feature("Boarding-Boat AP", "parent", main.id)
local ap_boat2 = menu.add_feature("Exit-Boat AP", "parent", main.id)

local register_sub = menu.add_feature("Register Kosatka [0]", "action", main.id, function(ft)
    local find = find_veh(760)
    if not (entity.is_an_entity(sub_veh) and not entity.is_entity_dead(sub_veh)) and (entity.is_an_entity(find) and not entity.is_entity_dead(find)) then
        sub_veh = find
    end
    ft.name = "Register Kosatka ["..sub_veh.."]"
end)
register_sub.hint = "Searches and registers your kosatka's vehicle ID, \n#FF00AAFF#REQUIRED FOR SCRIPT TO WORK, \n#FF4400FF#REQUIRED AT EVERY RESTART \nOR LOBBY RELOG \nOR KOSATKA RETURN"

local auto_register = menu.add_feature("Auto-Register Kosatka", "toggle", main.id, function(ft)
    ini_cfg:set_b("Toggles", "auto_reg", ft.on)
    ini_cfg:write()
end)

local exists, val = ini_cfg:get_b("Toggles", "auto_reg")
if not exists then
    ini_cfg:set_b("Toggles", "auto_reg", false)
    auto_register.on = false
    ini_cfg:write()
    print("set to false")
else
    auto_register.on = val
end

menu.create_thread(function()
    sub_veh = find_veh(760) or 0
    register_sub.name = "Register Kosatka ["..sub_veh.."]"
    if not (entity.is_an_entity(sub_veh) and not entity.is_entity_dead(sub_veh)) and not auto_register.on then
        menu.notify("#FF00AAFF#Unable to find Kosatka!","JJS.KosatkaAP", nil, 0x0000FF)
    end
end)

local reg_notify = false

menu.create_thread(function()
    while true do
        system.yield(0)
        if entity.is_an_entity(sub_veh) and not entity.is_entity_dead(sub_veh) then
            register_sub.name = "#FF00AA00#Register Kosatka ["..sub_veh.."]"
            kosatka_registered = true
            reg_notify = true
        else
            register_sub.name = "#FF0000FF#Register Kosatka ["..sub_veh.."]"
            kosatka_registered = false
            if auto_register.on then
                sub_veh = find_veh(760)
                if entity.is_an_entity(sub_veh) and not entity.is_entity_dead(sub_veh) then
                    menu.notify("Auto-Registered your Kosatka!","JJS.KosatkaAP", nil, 0x00FF00)
                end
            end
            if reg_notify then
                if auto_register.on then
                    menu.notify("#FF00AAFF#Kosatka un-registered! (Entity died/got removed)\n#FF0077CC#(Auto-Register is enabled, your kosatka will be automatically registered after being requested and detected!)","JJS.KosatkaAP", nil, 0x0000FF)
                else
                    menu.notify("#FF00AAFF#Kosatka un-registered! (Entity died/got removed)","JJS.KosatkaAP", nil, 0x0000FF)
                end
                reg_notify = false
            end
        end
    end
end)

local depth_options = {
    -2.0,
    -5.0,
    -18.0
}

local depth_option = menu.add_feature("AP Depth", "action_value_str", ap_kosatka.id, function(ft)
    autopilot_depth = depth_options[ft.value+1]
end)
depth_option:set_str_data({"High Surface","Low Surface","Underwater"})

local speed_override = menu.add_feature("Speed Override", "toggle", ap_kosatka.id)

local ap_wp_start = menu.add_feature("AP to WP", "action", ap_kosatka.id, function(ft)
    if kosatka_registered then
        if not is_diving then
            is_ap = true
            request_model(ped_hash)
            ped.clear_ped_tasks_immediately(vehicle.get_ped_in_vehicle_seat(sub_veh, -1) or 0)
            system.yield(0)
            sub_pilot = native.call(0x7DD959874C1FD534, sub_veh, 0, ped_hash, -1, true, false):__tointeger()
            native.call(0x9F8AA94D6D97DBF4, sub_pilot, true)
            system.yield(0)
            local dest_pos = ui.get_waypoint_coord()
            local dest_z = get_ground(dest_pos)
            local dest_v3 = v3(dest_pos.x, dest_pos.y, autopilot_depth)
            request_control(sub_pilot)
            request_control(sub_veh)
            --native.call(0xE2A2AA2F659D77A7, sub_pilot, sub_veh, dest_v3.x, dest_v3.y, -4.0, 100.0, 0, entity.get_entity_model_hash(sub_veh), vehicle_drive, 100.0, 10.0)
            --native.call(0x15C86013127CE63F, sub_pilot, sub_veh, 0, 0, dest_v3.x, dest_v3.y, -4.0, 4, autopilot_speed, vehicle_drive, 50.0, 0)
            native.call(0xC22B40579A498CA4, sub_pilot, sub_veh, dest_v3.x, dest_v3.y, autopilot_depth, true)
            system.yield(0)
            native.call(0x5C9B84BD7D31D908, sub_pilot, 300.0)
            if speed_override.on then
                native.call(0xBAA045B4E42F3C06, sub_veh, 300.0)
                native.call(0x0E46A3FCBDE2A1B1, sub_veh, 300.0)

            else
                native.call(0xBAA045B4E42F3C06, sub_veh, 0.0)
            end
            native.call(0x75DBEC174AEEAD10, sub_veh, false)
            native.call(0xC67DB108A9ADE3BE, sub_veh, true)
            local sub_pos = entity.get_entity_coords(sub_veh)
            vehicle.set_vehicle_forward_speed(sub_veh, 20)
            entity.freeze_entity(sub_veh, true)
            system.yield(0)
            entity.freeze_entity(sub_veh, false)
            menu.create_thread(function()
                local dest = dest_v3
                while true do
                    local sub_pos = entity.get_entity_coords(sub_veh)
                    if sub_pos:magnitude(dest) < 100 and entity.get_entity_speed(sub_veh) < 5 then
                        break
                    end
                    system.yield(0)
                end
                local pilot = vehicle.get_ped_in_vehicle_seat(sub_veh, -1) or 0
                request_control(sub_pilot)
                ped.clear_ped_tasks_immediately(pilot)
                system.yield(0)
                entity.delete_entity(pilot)
                menu.notify("Kosatka reached destination", "KosatkaAP")
                native.call(0xBAA045B4E42F3C06, sub_veh, 0.0)
            end)
        else
            menu.notify("#FF00AAFF#Couldn't start AP: Kosatka is busy! (diving)","JJS.KosatkaAP", nil, 0x0000FF)
        end
    else
        menu.notify("#FF00AAFF#Kosatka isn't registered properly!","JJS.KosatkaAP", nil, 0x0000FF)
    end
end)
ap_wp_start.hint = "Auto-pilots the submarine to the coords\nWILL NOT AVOID OBSTACLES"

local ap_dive = menu.add_feature("Dive Underwater", "action", ap_kosatka.id, function(ft)
    if kosatka_registered then
        if not is_ap then
            is_diving = true
            request_model(ped_hash)
            ped.clear_ped_tasks_immediately(vehicle.get_ped_in_vehicle_seat(sub_veh, -1) or 0)
            system.yield(0)
            sub_pilot = native.call(0x7DD959874C1FD534, sub_veh, 0, ped_hash, -1, true, false):__tointeger()
            native.call(0x9F8AA94D6D97DBF4, sub_pilot, true)

            local sub_pos = entity.get_entity_coords(sub_veh)

            request_control(sub_pilot)
            request_control(sub_veh)

            local dist = math.abs(sub_pos.z-(-22.0))

            native.call(0xC22B40579A498CA4, sub_pilot, sub_veh, sub_pos.x, sub_pos.y, -22.0, true)
            native.call(0xB088E9A47AE6EDD5, sub_veh, true)
            native.call(0x76D26A22750E849E, sub_veh)
            system.yield(0)
            native.call(0x5C9B84BD7D31D908, sub_pilot, 0.0)

            native.call(0x75DBEC174AEEAD10, sub_veh, false)
            native.call(0xC67DB108A9ADE3BE, sub_veh, true)
            vehicle.set_vehicle_forward_speed(sub_veh, 20)
            entity.freeze_entity(sub_veh, true)
            system.yield(0)
            entity.freeze_entity(sub_veh, false)

            menu.create_thread(function()
                dist = dist
                for i1=1, 180 do
                    local sub_pos = entity.get_entity_coords(sub_veh)
                    entity.set_entity_coords_no_offset(sub_veh, v3(sub_pos.x, sub_pos.y, sub_pos.z-(dist/180)))
                    system.yield(5)
                end
            end)
        else
            menu.notify("#FF00AAFF#Couldn't start Diving: Kosatka is busy! (AP)","JJS.KosatkaAP", nil, 0x0000FF)
        end
    else
        menu.notify("#FF00AAFF#Kosatka isn't registered properly!","JJS.KosatkaAP", nil, 0x0000FF)
    end
end)

ap_dive.hint = "Kinda broken lol"

local kill_pilot = menu.add_feature("Kill AP", "action", ap_kosatka.id, function(ft)
    native.call(0xBAA045B4E42F3C06, sub_veh, 0.0)
    local sub_pos = entity.get_entity_coords(sub_veh)
    local pilot = vehicle.get_ped_in_vehicle_seat(sub_veh, -1) or 0

    native.call(0x9F8AA94D6D97DBF4, sub_pilot, false)

    ped.clear_ped_tasks_immediately(pilot)
    native.call(0xDBBC7A2432524127, sub_veh)
    system.yield(0)
    entity.delete_entity(pilot)
    is_diving = false
    is_ap = false
end)

local toreador_ap_start = menu.add_feature("Toreador to Player", "action", ap_toreador.id, function(ft)
    if kosatka_registered then
        request_model(ped_hash)
        request_model(toreador_hash)
        local local_player = player.player_id()
        local sub_pos = entity.get_entity_coords(sub_veh)
        local pl_pos = player.get_player_coords(local_player)
        local spawn_dir = vector_to_heading(pl_pos, sub_pos)
        local spawn_pos = front_of_pos(sub_pos, v3(0,0,spawn_dir), 100)
        spawn_pos = v3(spawn_pos.x, spawn_pos.y, 0)
        toreador = vehicle.create_vehicle(toreador_hash, spawn_pos, spawn_dir, true, false)

        native.call(0x1F4ED342ACEFE62D, toreador, true, true)
        vehicle.set_vehicle_mod_kit_type(toreador, 0)

        vehicle.set_vehicle_colors(toreador, 12, 12)
        vehicle.set_vehicle_extra_colors(toreador, 64, 62)
        vehicle.set_vehicle_window_tint(toreador, 1)

        vehicle.set_vehicle_mod(toreador, 11, 3)
        vehicle.set_vehicle_mod(toreador, 15, 3)
        vehicle.set_vehicle_mod(toreador, 16, 4)
        vehicle.set_vehicle_mod(toreador, 12, 2)
        vehicle.set_vehicle_mod(toreador, 18, 1)

        native.call(0xBE70724027F85BCD, toreador, 0, 3)
        native.call(0xBE70724027F85BCD, toreador, 1, 3)

        toreador_pilot = native.call(0x7DD959874C1FD534, toreador, 0, ped_hash, -1, true, false):__tointeger()

        native.call(0x1F4ED342ACEFE62D, toreador_pilot, true, true)

        native.call(0x9F8AA94D6D97DBF4, toreador_pilot, true)
        native.call(0x1913FE4CBF41C463, toreador_pilot, 255, true)
        native.call(0x1913FE4CBF41C463, toreador_pilot, 251, true)

        native.call(0xBE4C854FFDB6EEBE, toreador, false)
        native.call(0xE2A2AA2F659D77A7, toreador_pilot, toreador, pl_pos.x, pl_pos.y, pl_pos.z, 18.0, 0, toreador_hash, vehicle_drive_careful, 10.0, 5.0)
        native.call(0x81E1552E35DC3839, toreador, true)
        native.call(0x33506883545AC0DF, toreador, true)
        --native.call(0xC22B40579A498CA4, toreador_pilot, toreador, pl_pos.x, pl_pos.y, pl_pos.z, true)

        blips.toreador = ui.add_blip_for_entity(toreador)
        ui.set_blip_sprite(blips.toreador, 773)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Spawned Toreador (prob gona get stuck lmao)")
        native.call(0xBC38B49BCB83BC9B, blips.toreador)

        menu.create_thread(function()
            local toreador = toreador
            while entity.is_an_entity(toreador) do
                local heading = entity.get_entity_heading(toreador)
                native.call(0xA8B6AFDAC320AC87, blips.toreador, heading)
                system.yield(0)
            end
        end)

        menu.create_thread(function()
            local toreador = toreador
            local pl_pos = pl_pos
            local toreador_pilot = toreador_pilot
            local counter = 0
            while true do
                system.yield(0)
                if native.call(0xCFB0A0D8EDD145A3, toreador):__tointeger() == 0 then
                    counter = counter+1
                end
                if counter > 120 then
                    break
                end
            end
            native.call(0x2A69FFD1B42BFF9E, toreador, false)
            local counter = 0
            while true do
                local toreador_pos = entity.get_entity_coords(toreador)
                system.yield(0)
                if toreador_pos:magnitude(pl_pos) < 30 and entity.get_entity_speed(toreador) < 1 then
                    counter = counter+1
                end
                if counter > 60 then
                    break
                end
            end
            native.call(0x7C65DAC73C35C862, toreador, 2, false, false)
            native.call(0x7C65DAC73C35C862, toreador, 3, false, false)
            while true do
                local local_player = player.player_id()
                local player_ped = player.get_player_ped(local_player)
                system.yield(0)
                if ped.is_ped_in_vehicle(player_ped, toreador) then
                    break
                end
            end
            native.call(0x781B3D62BB013EF5, toreador, false)
            local sub_pos = entity.get_entity_coords(sub_veh)
            native.call(0xE2A2AA2F659D77A7, toreador_pilot, toreador, sub_pos.x, sub_pos.y, sub_pos.z, 12.0, 0, toreador_hash, vehicle_drive_careful, 100.0, 5.0)
            native.call(0x33506883545AC0DF, toreador, true)
            local counter = 0
            while true do
                system.yield(0)
                if native.call(0xCFB0A0D8EDD145A3, toreador):__tointeger() == 1 then
                    counter = counter+1
                end
                if counter > 60 then
                    break
                end
            end
            native.call(0xBE4C854FFDB6EEBE, toreador, false)
            native.call(0x81E1552E35DC3839, toreador, true)
            while true do
                local local_player = player.player_id()
                local player_ped = player.get_player_ped(local_player)
                local toreador_pos = entity.get_entity_coords(toreador)
                system.yield(0)
                if toreador_pos:magnitude(sub_pos) < 90 then
                    native.call(0x260BE8F09E326A20, toreador, 5.0, 1, true)
                end
                if toreador_pos:magnitude(sub_pos) < 100 and not ped.is_ped_in_vehicle(player_ped, toreador) then
                    break
                end
            end
            system.yield(500)
            entity.delete_entity(toreador)
            entity.delete_entity(toreador_pilot)
        end)
    else
        menu.notify("#FF00AAFF#Kosatka isn't registered properly!","JJS.KosatkaAP", nil, 0x0000FF)
    end
end)
toreador_ap_start.hint = "Broken AF lmao don't expect much from this"

local kill_toreador = menu.add_feature("Kill Toreador", "action", ap_toreador.id, function(ft)
    entity.delete_entity(vehicle.get_ped_in_vehicle_seat(toreador, -1) or 0)
    entity.delete_entity(toreador)
end)

local spawn_boat_ap = menu.add_feature("Call Boat", "action", ap_boat.id, function(ft)
    if kosatka_registered then
        local sub_pos = entity.get_entity_coords(sub_veh)
        local sub_dir = entity.get_entity_heading(sub_veh)

        local local_player = player.player_id()
        local player_ped = player.get_player_ped(local_player)
        local pl_pos = player.get_player_coords(local_player)

        local closest_node = find_closest_beach(pl_pos)

        local spawn_pos = front_of_pos(sub_pos, v3(0,0,vector_to_heading(closest_node, sub_pos)), 90)
        request_model(boat_hash)
        boat = vehicle.create_vehicle(boat_hash, spawn_pos, sub_dir, true, false)

        native.call(0x1F4ED342ACEFE62D, boat, true, true)
        vehicle.set_vehicle_mod_kit_type(boat, 0)

        vehicle.set_vehicle_colors(boat, 112, 12)
        vehicle.set_vehicle_extra_colors(boat, 67, 62)
        vehicle.set_vehicle_window_tint(boat, 1)

        vehicle.set_vehicle_mod(boat, 11, 3)
        vehicle.set_vehicle_mod(boat, 15, 3)
        vehicle.set_vehicle_mod(boat, 16, 4)
        vehicle.set_vehicle_mod(boat, 12, 2)
        vehicle.set_vehicle_mod(boat, 18, 1)

        blips.boat = ui.add_blip_for_entity(boat)
        ui.set_blip_sprite(blips.boat, 427)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Kosatka Boarding Boat")
        native.call(0xBC38B49BCB83BC9B, blips.boat)

        menu.create_thread(function()
            local boat = boat
            while entity.is_an_entity(boat) do
                local heading = entity.get_entity_heading(boat)
                native.call(0xA8B6AFDAC320AC87, blips.boat, heading)
                system.yield(0)
            end
        end)

        request_model(ped_hash)
        boat_pilot = native.call(0x7DD959874C1FD534, boat, 0, ped_hash, -1, true, false):__tointeger()

        native.call(0x1F4ED342ACEFE62D, boat_pilot, true, true)

        native.call(0x9F8AA94D6D97DBF4, boat_pilot, true)
        native.call(0x1913FE4CBF41C463, boat_pilot, 255, true)
        native.call(0x1913FE4CBF41C463, boat_pilot, 251, true)

        print("Closest Node: X"..closest_node.x.." Y"..closest_node.y.." Z"..closest_node.z)

        entity.delete_entity(boat_dest_ent)

        local dest_ent_hash = gameplay.get_hash_key("prop_dock_float_1b")
        boat_dest_ent = object.create_object(dest_ent_hash, closest_node, true, true)

        blips.boat_dest_ent = ui.add_blip_for_entity(boat_dest_ent)
        ui.set_blip_sprite(blips.boat_dest_ent, 432)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Boat Pick-up Location")
        native.call(0xBC38B49BCB83BC9B, blips.boat_dest_ent)

        ai.task_vehicle_follow(boat_pilot, boat, boat_dest_ent, 30.0, boat_drive, 15)
        menu.create_thread(function()
            local boat = boat
            local dest = closest_node
            local player_ped = player_ped
            while true do
                system.yield(0)
                if entity.get_entity_coords(boat):magnitude(dest) < 15 then
                    break
                end
            end

            local flare_gun = gameplay.get_hash_key("weapon_flaregun")
            gameplay.shoot_single_bullet_between_coords(closest_node+v3(0,0,5), closest_node+v3(0,0,10), 0, flare_gun, player_ped, false, false, 0.25)

            local counter = 0
            while true do
                system.yield(0)
                if ped.is_ped_in_vehicle(player_ped, boat) then
                    counter = counter+1
                else
                    counter = 0
                end
                if counter > 120 then
                    break
                end
            end

            request_control(boat_dest_ent)
            entity.delete_entity(boat_dest_ent)


            local sub_pos = entity.get_entity_coords(sub_veh)
            local sub_dir = entity.get_entity_heading(sub_veh)

            entity.delete_entity(boat_dest_ent2)

            local dest_ent_hash = gameplay.get_hash_key("prop_dock_float_1b")
            boat_dest_ent2 = object.create_object(dest_ent_hash, front_of_pos(sub_pos, v3(0,0,sub_dir), 60), true, true)

            blips.boat_dest_ent2 = ui.add_blip_for_entity(boat_dest_ent2)
            ui.set_blip_sprite(blips.boat_dest_ent2, 432)

            native.call(0xF9113A30DE5C6670, "STRING")
            native.call(0x6C188BE134E074AA, "Boat Drop-off Location")
            native.call(0xBC38B49BCB83BC9B, blips.boat_dest_ent2)

            ai.task_vehicle_follow(boat_pilot, boat, boat_dest_ent2, 30.0, boat_drive, 15)
            while true do
                system.yield(0)
                if entity.get_entity_coords(boat):magnitude(entity.get_entity_coords(boat_dest_ent2)) < 20 and get_taken_seats(boat) == 1 then
                    break
                end
            end
            system.yield(2000)

            request_control(boat_dest_ent2)
            entity.delete_entity(boat_dest_ent2)

            request_control(boat)
            request_control(boat_pilot)
            native.call(0xDE564951F95E09ED, boat, true, true)
            native.call(0xDE564951F95E09ED, boat_pilot, true, true)
            system.yield(2000)
            request_control(boat)
            request_control(boat_pilot)
            entity.delete_entity(boat_pilot)
            entity.delete_entity(boat)
        end)
    else
        menu.notify("#FF00AAFF#Kosatka isn't registered properly!","JJS.KosatkaAP", nil, 0x0000FF)
    end
end)
spawn_boat_ap.hint = "Spawns a boat that goes to nearest shore, then back to kosatka once you're seated"

local kill_boat = menu.add_feature("Kill Boat", "action", ap_boat.id, function(ft)
    entity.delete_entity(vehicle.get_ped_in_vehicle_seat(boat, -1) or 0)
    entity.delete_entity(boat)
    entity.delete_entity(boat_dest_ent)
    entity.delete_entity(boat_dest_ent2)
end)

local spawn_extboat_ap = menu.add_feature("Boat to WP", "action", ap_boat2.id, function(ft)
    if kosatka_registered then
        local sub_pos = entity.get_entity_coords(sub_veh)
        local sub_dir = entity.get_entity_heading(sub_veh)

        local local_player = player.player_id()
        local player_ped = player.get_player_ped(local_player)
        local pl_pos = player.get_player_coords(local_player)

        local spawn_pos = front_of_pos(sub_pos, v3(0,0,sub_dir), 60)
        request_model(boat_hash)
        extboat = vehicle.create_vehicle(boat_hash, spawn_pos, sub_dir, true, false)

        native.call(0x1F4ED342ACEFE62D, extboat, true, true)
        vehicle.set_vehicle_mod_kit_type(extboat, 0)

        vehicle.set_vehicle_colors(extboat, 112, 12)
        vehicle.set_vehicle_extra_colors(extboat, 67, 62)
        vehicle.set_vehicle_window_tint(extboat, 1)

        vehicle.set_vehicle_mod(extboat, 11, 3)
        vehicle.set_vehicle_mod(extboat, 15, 3)
        vehicle.set_vehicle_mod(extboat, 16, 4)
        vehicle.set_vehicle_mod(extboat, 12, 2)
        vehicle.set_vehicle_mod(extboat, 18, 1)

        blips.extboat = ui.add_blip_for_entity(extboat)
        ui.set_blip_sprite(blips.extboat, 427)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Kosatka Travel Boat")
        native.call(0xBC38B49BCB83BC9B, blips.extboat)

        menu.create_thread(function()
            local extboat = extboat
            while entity.is_an_entity(extboat) do
                local heading = entity.get_entity_heading(extboat)
                native.call(0xA8B6AFDAC320AC87, blips.extboat, heading)
                system.yield(0)
            end
        end)

        request_model(ped_hash)
        extboat_pilot = native.call(0x7DD959874C1FD534, extboat, 0, ped_hash, -1, true, false):__tointeger()

        native.call(0x1F4ED342ACEFE62D, extboat_pilot, true, true)

        native.call(0x9F8AA94D6D97DBF4, extboat_pilot, true)
        native.call(0x1913FE4CBF41C463, extboat_pilot, 255, true)
        native.call(0x1913FE4CBF41C463, extboat_pilot, 251, true)

        menu.create_thread(function()
            local extboat = extboat
            local player_ped = player_ped

            local counter = 0
            while true do
                system.yield(0)
                if ped.is_ped_in_vehicle(player_ped, extboat) then
                    counter = counter+1
                else
                    counter = 0
                end
                if counter > 120 then
                    break
                end
            end

            local wp = ui.get_waypoint_coord()

            if wp == v2(16000.0, 16000.0) then
                repeat
                    system.yield(0)
                    wp = ui.get_waypoint_coord()
                until wp ~= v2(16000.0, 16000.0)
            end

            local wp3 = v3(wp.x, wp.y, 0)

            entity.delete_entity(extboat_dest_ent)

            local dest_ent_hash = gameplay.get_hash_key("prop_dock_float_1b")
            extboat_dest_ent = object.create_object(dest_ent_hash, wp3, true, true)

            blips.extboat_dest_ent = ui.add_blip_for_entity(extboat_dest_ent)
            ui.set_blip_sprite(blips.extboat_dest_ent, 432)

            native.call(0xF9113A30DE5C6670, "STRING")
            native.call(0x6C188BE134E074AA, "Boat Destination")
            native.call(0xBC38B49BCB83BC9B, blips.extboat_dest_ent)

            request_control(extboat_pilot)
            ai.task_vehicle_follow(extboat_pilot, extboat, extboat_dest_ent, 30.0, boat_drive, 10)

            while true do
                system.yield(0)
                if entity.get_entity_coords(extboat):magnitude(entity.get_entity_coords(extboat_dest_ent)) < 10 and get_taken_seats(extboat) == 1 then
                    break
                end
            end
            request_control(extboat_dest_ent)
            entity.delete_entity(extboat_dest_ent)
            system.yield(2000)
            request_control(extboat)
            request_control(extboat_pilot)
            native.call(0xDE564951F95E09ED, extboat, true, true)
            native.call(0xDE564951F95E09ED, extboat_pilot, true, true)
            system.yield(2000)
            request_control(extboat)
            request_control(extboat_pilot)
            entity.delete_entity(extboat_pilot)
            entity.delete_entity(extboat)
        end)
    else
        menu.notify("#FF00AAFF#Kosatka isn't registered properly!","JJS.KosatkaAP", nil, 0x0000FF)
    end
end)
spawn_extboat_ap.hint = "Spawns a boat in front of the kosatka, it will drive to your waypoint"

local kill_extboat = menu.add_feature("Kill Boat", "action", ap_boat2.id, function(ft)
    entity.delete_entity(vehicle.get_ped_in_vehicle_seat(extboat, -1) or 0)
    entity.delete_entity(extboat)
    entity.delete_entity(extboat_dest_ent)
end)

if ini_cfg:get_b("Toggles","debug_menu") then
    local debug = menu.add_feature("Debug", "parent", main.id)
    local show_all_shores = menu.add_feature("Show all beaches", "action", debug.id, function()
        for k,v in pairs(beach_locations) do
            local new_blip = ui.add_blip_for_coord(v3(v.x, v.y, v.z))
            ui.set_blip_sprite(new_blip, 432)
            native.call(0xF9113A30DE5C6670, "STRING")
            native.call(0x6C188BE134E074AA, "Beach Location n°"..k)
            native.call(0xBC38B49BCB83BC9B, new_blip)
        end
    end)
    local coord_to_cb = menu.add_feature("Put coords to Clipboard", "action", debug.id, function()
        local local_player = player.player_id()
        local pl_pos = player.get_player_coords(local_player)

        utils.to_clipboard("{x = "..pl_pos.x..", y = "..pl_pos.y..", z = "..pl_pos.z.."},")
    end)
    local coord_to_cb0 = menu.add_feature("Put coords to Clipboard (Z = 0)", "action", debug.id, function()
        local local_player = player.player_id()
        local pl_pos = player.get_player_coords(local_player)

        utils.to_clipboard("{x = "..pl_pos.x..", y = "..pl_pos.y..", z = "..(0.0).."},")
    end)
end