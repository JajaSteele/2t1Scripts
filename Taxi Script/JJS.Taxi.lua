if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Taxi requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Taxi%20Script/JJS.Taxi.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Taxi.lua"

        local file1 = io.open(path, "r")
        curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Taxi",nil,0x00AAFF)
            choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Taxi",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Taxi",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Taxi",nil,0xFF00FF)
            print("Update HTTP for JJS Taxi: "..code)
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

local function ent_check(ent,dead)
    if dead then
        if ent ~= nil and type(ent) == "number" and entity.is_an_entity(ent) and not entity.is_entity_dead(ent) then
            return true
        else
            return false
        end
    else
        if ent ~= nil and type(ent) == "number" and entity.is_an_entity(ent) then
            return true
        else
            return false
        end
    end
end

local function GET_STREET_NAME_FROM_HASH_KEY(hash)
    return native.call(0xD0EF8A959B8A4CB9, hash):__tostring(true)
end

local function GET_STREET_NAME_AT_COORD(x, y, z)
    local streetInfo = {name = "", crossingRoad = ""}

    local bufferN = native.ByteBuffer8()
    local bufferC = native.ByteBuffer8()

    native.call(0x2EB41072B4C1E4C0, x, y, z, bufferN, bufferC)

    streetInfo.name = GET_STREET_NAME_FROM_HASH_KEY(bufferN:__tointeger())
    streetInfo.crossingRoad = GET_STREET_NAME_FROM_HASH_KEY(bufferC:__tointeger())

    return streetInfo
end
    

local function table_random(table1)
    local table_len = #table1
    local random_table = math.random(0,table_len)
    return table1[random_table]
end

local radio_stations = {
    {id="RADIO_11_TALK_02", name="Blaine County Radio"},
    {id="RADIO_12_REGGAE", name="The Blue Ark"},
    {id="RADIO_13_JAZZ", name="Worldwide FM"},
    {id="RADIO_14_DANCE_02", name="FlyLo FM"},
    {id="RADIO_15_MOTOWN", name="The Lowdown 9.11"},
    {id="RADIO_20_THELAB", name="The Lab"},
    {id="RADIO_16_SILVERLAKE", name="Radio Mirror Park"},
    {id="RADIO_17_FUNK", name="Space 103.2"},
    {id="RADIO_18_90S_ROCK", name="Vinewood Boulevard Radio"},
    {id="RADIO_21_DLC_XM17", name="Blonded LS 97.8 FM"},
    {id="RADIO_22_DLC_BATTLE_MIX1_RADIO", name="LS Underground Radio"},
    {id="RADIO_23_DLC_XM19_RADIO", name="iFruit Radio"},
    {id="RADIO_19_USER", name="Self Radio"},
    {id="RADIO_01_CLASS_ROCK", name="LS Rock Radio"},
    {id="RADIO_02_POP", name="Non-Stop-Pop FM"},
    {id="RADIO_03_HIPHOP_NEW", name="Radio LS"},
    {id="RADIO_04_PUNK", name="Channel X"},
    {id="RADIO_05_TALK_01", name="West Coast Talk"},
    {id="RADIO_06_COUNTRY", name="Rebel Radio"},
    {id="RADIO_07_DANCE_01", name="Soulwax FM"},
    {id="RADIO_08_MEXICAN", name="East Los FM"},
    {id="RADIO_09_HIPHOP_OLD", name="West Coast Classics"},
    {id="RADIO_36_AUDIOPLAYER", name="Media Player"},
    {id="RADIO_35_DLC_HEI4_MLR", name="The Music Locker"},
    {id="RADIO_34_DLC_HEI4_KULT", name="Kult FM"},
    {id="RADIO_27_DLC_PRHEI4", name="Still Slipping LS"},
}

local radio_data = {}
for k,v in ipairs(radio_stations) do
    radio_data[#radio_data+1] = v.name
end

function vector_to_heading(_target,_start)
    return math.atan((_target.x - _start.x), (_target.y - _start.y)) * -180 / math.pi
end

local ground_check = {900}
repeat
    ground_check[#ground_check+1] = ground_check[#ground_check] - 25
until ground_check[#ground_check] < 26

local vehicle_hash = gameplay.get_hash_key("nightshark")
local vehicle_name = "nightshark"
local ped_hash = 988062523
local vehicle_drive = 1076632110
local vehicle_drive_close = 1076632111
local exit_lsia_drive = 1093409295
local exit_lsia_drive_path = 1076632127
local vehicle_speed = 23
local taxi_dist = 65

local lsia_exit = {
    {x=-1123.1683349609, y=-3069.9182128906, z=13.944445610046, mode=exit_lsia_drive_path, speed=23},
    {x=-1049.4349365234, y=-2952.9375, z=13.96454334259, mode=exit_lsia_drive, speed=15},
    {x=-961.80718994141, y=-2805.4265136719, z=13.964538574219, mode=exit_lsia_drive, speed=15},
    {x=-905.31848144531, y=-2680.9377441406, z=13.796699523926, mode=exit_lsia_drive, speed=15},
}

local blips = {}
local taxi_driver
local taxi_veh

local is_taxi_active = false

local last_drive = {}

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

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Taxi", "parent", 0)
local player_menu = menu.add_player_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Taxi", "parent", 0)

local taxi_vehicle = menu.add_feature("Taxi Vehicle = [nightshark]", "action", main_menu.id, function(ft)
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
        ft.name = "Taxi Vehicle = [#FF0000FF#ERROR#DEFAULT#]"
        return
    end

    ft.name = "Taxi Vehicle = ["..vehicle_name.."]"
end)
taxi_vehicle.hint = "Choose the vehicle model for the taxi, must be a ground vehicle (maybe boat but idk tbh)"

local taxi_ped = menu.add_feature("Taxi Ped = [cs_fbisuit_01]", "action", main_menu.id, function(ft)
    local status = 1
    local ped_name
    while status == 1 do
        status, ped_name = input.get("Name/Hash Input","",15,2)
        system.yield(0)
    end
    ped_hash = gameplay.get_hash_key(ped_name)

    if not streaming.is_model_a_ped(ped_hash) then
        ped_hash = tonumber(ped_name)
    end

    if not streaming.is_model_a_ped(ped_hash) then
        menu.notify("Warning! Ped model doesn't exist!","!WARNING!",nil,0x0000FF)
        ft.name = "Taxi Ped = [#FF0000FF#ERROR#DEFAULT#]"
        return
    end

    ft.name = "Taxi Ped = ["..ped_name.."]"
end)
taxi_ped.hint = "Choose the ped model for the taxi driver"


local function resume_last_drive()
    if last_drive.type == "goto" then
        request_model(vehicle_hash)
        ai.task_vehicle_drive_to_coord(last_drive.driver, last_drive.veh, v3(last_drive.dest.x, last_drive.dest.y, last_drive.dest.z), last_drive.speed, 0, vehicle_hash, vehicle_drive, last_drive.dist, 10)
        streaming.set_model_as_no_longer_needed(vehicle_hash)
    elseif last_drive.type == "follow" then
        ai.task_vehicle_follow(last_drive.driver, last_drive.veh, last_drive.dest, last_drive.speed, vehicle_drive, last_drive.dist)
    end
end

local taxi_speed = menu.add_feature("Speed = [23]", "action", main_menu.id, function(ft)
    local status = 1
    local temp_speed
    while status == 1 do
        status, temp_speed = input.get("Hash Input","",15,3)
        system.yield(0)
    end
    vehicle_speed = tonumber(temp_speed)

    ft.name = "Speed = ["..temp_speed.."]"
    
    if is_taxi_active then
        menu.notify("Speed updated to "..vehicle_speed,"Updated Speed", nil, 0x00FF00)
        last_drive["speed"] = vehicle_speed
        resume_last_drive()
    end
end)
taxi_speed.hint = "Choose the speed of the driver. Default is 23 (same as a taxi with quick mode)"

local taxi_dist_feat = menu.add_feature("Dist = [65]", "action", main_menu.id, function(ft)
    local status = 1
    local temp_dist
    while status == 1 do
        status, temp_dist = input.get("Hash Input","",15,3)
        system.yield(0)
    end
    taxi_dist = tonumber(temp_dist)

    ft.name = "Dist = ["..temp_dist.."]"
    
    if is_taxi_active then
        menu.notify("Distance updated to "..taxi_dist,"Updated Dist", nil, 0x00FF00)
        last_drive["dist"] = taxi_dist/2
        resume_last_drive()
    end
end)
taxi_dist_feat.hint = "Choose the stop distance around destination. Default is 65"

local taxi_conv = menu.add_feature("Convertible Preference","autoaction_value_str",main_menu.id, function(ft)
    if is_taxi_active and entity.is_an_entity(taxi_veh) then
        if ft.value == 0 then
            if is_vehicle_conv and native.call(0x96695E368AD855F3):__tonumber() < 0.1 then
                native.call(0x5C9B84BD7D31D908, taxi_driver, 10)

                repeat
                    system.yield(250)
                until entity.get_entity_speed(taxi_veh) < 11

                native.call(0xDED51F703D0FA83D, taxi_veh, false) --opens roof
                repeat
                    system.yield(250)
                until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 2
                resume_last_drive()
            elseif native.call(0x96695E368AD855F3):__tonumber() > 0.1 then
                native.call(0x5C9B84BD7D31D908, taxi_driver, 10)

                repeat
                    system.yield(250)
                until entity.get_entity_speed(taxi_veh) < 11

                native.call(0x8F5FB35D7E88FC70, taxi_veh, false) --closes roof
                repeat
                    system.yield(250)
                until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 0
                resume_last_drive()
            end
        elseif ft.value == 1 then
            if is_vehicle_conv then
                native.call(0x5C9B84BD7D31D908, taxi_driver, 10)

                repeat
                    system.yield(250)
                until entity.get_entity_speed(taxi_veh) < 11

                native.call(0xDED51F703D0FA83D, taxi_veh, false) --opens roof
                repeat
                    system.yield(250)
                until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 2
                resume_last_drive()
            end
        elseif ft.value == 2 then
            if is_vehicle_conv then
                native.call(0x5C9B84BD7D31D908, taxi_driver, 10)

                repeat
                    system.yield(250)
                until entity.get_entity_speed(taxi_veh) < 11

                native.call(0x8F5FB35D7E88FC70, taxi_veh, false) --closes roof
                repeat
                    system.yield(250)
                until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 0
                resume_last_drive()
            end
        end
    end
end)
taxi_conv:set_str_data({"Open if no rain","Open","Close"})
taxi_conv.hint = "Choose the mode of vehicles with convertible roof"

local radio_menu = menu.add_feature("Radio","parent",main_menu.id)

local taxi_radio = menu.add_feature("Station","action_value_str",radio_menu.id,function(ft)
    if is_taxi_active and entity.is_an_entity(taxi_veh or 0) then
        native.call(0x1B9C0099CB942AC6, taxi_veh, radio_stations[ft.value+1].id)
        menu.notify("Set radio to "..radio_stations[ft.value+1].name.."("..radio_stations[ft.value+1].id..")","Radio",nil,0xFF00FF)
    end
end)
taxi_radio.hint = "Choose the radio station to use!\nYou must 'Select' the radio after choosing the one you want."
taxi_radio:set_str_data(radio_data)

local taxi_radio_toggle = menu.add_feature("Enable","toggle",radio_menu.id,function(ft)
    if is_taxi_active and entity.is_an_entity(taxi_veh or 0) then
        native.call(0x3B988190C0AA6C0B, taxi_veh, ft.on)
    end
end)
taxi_radio_toggle.hint = "Toggle the radio ON or OFF"

local taxi_allowfront = menu.add_feature("Allow Front Passenger", "toggle", main_menu.id, function(ft)
    if is_taxi_active and ft.on then
        native.call(0xBE70724027F85BCD, taxi_veh or 0, 1, 1)
    end
end)
taxi_allowfront.hint = "Allows the player to enter front passenger seat in a 3+ seats vehicles (not needed for 2 seats vehicles)"

local taxi_per_veh = menu.add_feature("Use personal vehicle", "toggle", main_menu.id, function(ft)
end)
taxi_per_veh.hint = "Use the player's personal vehicle instead of a new one"

local taxi_ignoreheight = menu.add_feature("Ignore Height", "toggle", main_menu.id, function(ft)
end)
taxi_ignoreheight.hint = "When this is enabled, the taxi won't check the height and just the horizontal distance\nUseful for the casino since highest point is roof terrace and not the entry path."

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    print("Deleting",taxi_driver)
    entity.delete_entity(taxi_driver or 0)
    
    if not taxi_per_veh.on then
        entity.delete_entity(taxi_veh or 0)
    end

    is_taxi_active = false
    
    merc_peds = {}
    taxi_veh = 0
end

local function clear_all(delay,peds,vehicles)
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

    if peds and taxi_driver ~= nil then
        request_control(taxi_driver)
        repeat
            entity.delete_entity(taxi_driver)
            system.yield(0)
            attempts = attempts+1
        until not entity.is_an_entity(taxi_driver) or attempts > 100
    end

    local attempts = 0

    if vehicles and taxi_veh ~= nil and not taxi_per_veh.on then
        request_control(taxi_veh)
        repeat
            entity.delete_entity(taxi_veh)
            attempts = attempts+1
            system.yield(0)
        until not entity.is_an_entity(taxi_veh) or attempts > 100
        taxi_veh = 0
    elseif taxi_per_veh.on and entity.is_an_entity(taxi_veh) then
        vehicle.set_vehicle_doors_locked(taxi_veh, 1)

        native.call(0x684785568EF26A22, taxi_veh, false)
        native.call(0xE4E2FD323574965C, taxi_veh, false)
    end

    if vehicles and peds then
        is_taxi_active = false
    end
end

local taxi_spawn = menu.add_feature("Spawn Taxi", "action", main_menu.id, function(ft)

    if is_taxi_active then
        menu.notify("A taxi is already active.", "Error", nil, 0x0000FF)
        return
    else
        is_taxi_active = true
    end

    local found, spawn_point
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)

    local points = {}
    
    for i1=1, 360 do
        found, spawn_point = gameplay.find_spawn_point_in_direction(player_pos, v3(0,0,i1-180), 30)
        if found then
            points[#points+1] = {
                pos= {
                    x=spawn_point.x,
                    y=spawn_point.y,
                    z=spawn_point.z
                },
                rot=i1-180
            }
        end
        system.yield(0)
    end

    if taxi_per_veh.on then
        vehicle_hash = entity.get_entity_model_hash(player.get_personal_vehicle())
    else
        vehicle_hash = gameplay.get_hash_key(vehicle_name)

        if not streaming.is_model_a_vehicle(vehicle_hash) then
            vehicle_hash = tonumber(vehicle_name)
        end
    end



    request_model(vehicle_hash)

    local seat_count = vehicle.get_vehicle_model_number_of_seats(vehicle_hash)

    local s_point = table_random(points)
    local s_pos = v3(s_point.pos.x,s_point.pos.y,s_point.pos.z)
    --s_pos = player_pos + v3(5,0,0)

    if not taxi_per_veh.on then
        taxi_veh = vehicle.create_vehicle(vehicle_hash, s_pos + v3(0,0,2), vector_to_heading(player_pos, s_pos), true, false)
    else
        taxi_veh = player.get_personal_vehicle()
    end

    system.yield(0)
    if ent_check(taxi_veh,true) then
        blips.taxi_veh = ui.add_blip_for_entity(taxi_veh)
        ui.set_blip_sprite(blips.taxi_veh, 198)
        ui.set_blip_colour(blips.taxi_veh, 2)
    end
    
    if not taxi_per_veh.on then
        native.call(0x1F4ED342ACEFE62D, taxi_veh, true, true)
        vehicle.set_vehicle_mod_kit_type(taxi_veh, 0)

        vehicle.set_vehicle_colors(taxi_veh, 12, 12)
        vehicle.set_vehicle_extra_colors(taxi_veh, 64, 62)
        vehicle.set_vehicle_window_tint(taxi_veh, 1)

        vehicle.set_vehicle_mod(taxi_veh, 11, 3)
        vehicle.set_vehicle_mod(taxi_veh, 15, 3)
        vehicle.set_vehicle_mod(taxi_veh, 16, 4)
        vehicle.set_vehicle_mod(taxi_veh, 12, 2)
        vehicle.set_vehicle_mod(taxi_veh, 18, 1)
    end

    if seat_count > 2 and not taxi_allowfront.on then
        native.call(0xBE70724027F85BCD, taxi_veh, 0, 3)
        native.call(0xBE70724027F85BCD, taxi_veh, 1, 3)
    else
        native.call(0xBE70724027F85BCD, taxi_veh, 0, 3)
        native.call(0xBE70724027F85BCD, taxi_veh, 1, 0)
    end


    local vehicle_conv = native.call(0x52F357A30698BCCE, taxi_veh, false):__tointeger()

    if vehicle_conv == 1 then
        is_vehicle_conv = true
        print("Taxi vehicle is convertible")
    else
        is_vehicle_conv = false
        print("Taxi vehicle isn't convertible")
    end

    print(seat_count)

    request_model(ped_hash)
    taxi_driver = ped.create_ped(0, ped_hash, s_pos+v3(3,0,0), 0, true, false)
    native.call(0x1F4ED342ACEFE62D, taxi_driver, true, true)

    system.yield(0)
    ped.set_ped_into_vehicle(taxi_driver, taxi_veh, -1)

    native.call(0x9F8AA94D6D97DBF4, taxi_driver, true)
    native.call(0x1913FE4CBF41C463, taxi_driver, 255, true)
    native.call(0x1913FE4CBF41C463, taxi_driver, 251, true)

    streaming.set_model_as_no_longer_needed(ped_hash)
    streaming.set_model_as_no_longer_needed(vehicle_hash)

    ai.task_vehicle_follow(taxi_driver, taxi_veh, player_ped, 5, vehicle_drive_close, 10)
    repeat
        system.yield(250)
    until ped.is_ped_in_vehicle(player_ped, taxi_veh) or not is_taxi_active
    menu.notify("Welcome in JJS-Taxi!","Welcome",nil,0x00FF00)

    if taxi_radio_toggle.on then
        native.call(0x3B988190C0AA6C0B, taxi_veh, true)
        native.call(0x1B9C0099CB942AC6, taxi_veh, radio_stations[taxi_radio.value+1].id)
    else
        native.call(0x3B988190C0AA6C0B, taxi_veh, false)
    end

    if is_taxi_active then
        local dest = ui.get_waypoint_coord()
        local ground_level = get_ground(dest)

        destv3_safe = v3(dest.x, dest.y, ground_level)

        menu.notify("Destination: X"..destv3_safe.x.." Y"..destv3_safe.y.." Z"..destv3_safe.z,"Destination",nil,0x00AAFF)
        

        blips.destv3_safe = ui.add_blip_for_coord(destv3_safe)
        ui.set_blip_sprite(blips.destv3_safe, 58)
        ui.set_blip_colour(blips.destv3_safe, 5)
        ui.set_blip_route(blips.destv3_safe, true)
        ui.set_blip_route_color(blips.destv3_safe, 46)
    

        request_control(taxi_driver)
        request_control(taxi_veh)

        request_model(vehicle_hash)

        local taxi_pos1 = entity.get_entity_coords(taxi_veh)

        if GET_STREET_NAME_AT_COORD(taxi_pos1.x, taxi_pos1.y, taxi_pos1.z).name == "Runway1" then
            menu.notify("Detected inside LSIA, exiting first.","LSIA Bullshit Pathing",nil,0x00AAFF)
            --native.call(0x195AEEB13CEFE2EE, taxi_driver, taxi_veh, lsia_exit.x, lsia_exit.y, lsia_exit.z, 30, 156, 5.0)
            for k,v in ipairs(lsia_exit) do
                if is_taxi_active then
                    menu.notify("Exiting LSIA Phase "..k.."/"..#lsia_exit,"LSIA Bullshit Pathing",nil,0x00AAFF)

                    ai.task_vehicle_drive_to_coord(taxi_driver, taxi_veh, v3(v.x, v.y, v.z), v.speed, 0, vehicle_hash, v.mode, 5, 10)
                    repeat
                        local postaxi = entity.get_entity_coords(taxi_veh)
                
                        local dist_x = math.abs(postaxi.x - v.x)
                        local dist_y = math.abs(postaxi.y - v.y)
                        local dist_z = math.abs(postaxi.z - v.z)
                
                        local hori_dist = dist_x+dist_y
                        system.yield(0)
                    until hori_dist < 20 or not is_taxi_active
                    system.yield(500)
                end
            end
            if is_taxi_active then
                menu.notify("Finally out of this mess.. Driving to destination now.","LSIA Bullshit Pathing",nil,0x00FF00)
            end
        end

        ai.task_vehicle_drive_to_coord(taxi_driver, taxi_veh, destv3_safe, 5, 0, vehicle_hash, vehicle_drive, (taxi_dist/2), 10)
        system.yield(250)
        ai.task_vehicle_drive_to_coord(taxi_driver, taxi_veh, destv3_safe, 5, 0, vehicle_hash, vehicle_drive, (taxi_dist/2), 10)
        streaming.set_model_as_no_longer_needed(vehicle_hash)
    else
        destv3_safe = v3(0,0,0)
    end

    last_drive = {
        type="goto",
        driver=taxi_driver,
        veh=taxi_veh,
        dest={
            x=destv3_safe.x,
            y=destv3_safe.y,
            z=destv3_safe.z
        },
        speed=vehicle_speed,
        mode=vehicle_drive,
        dist=(taxi_dist/2)
    }

    if taxi_conv.value == 0 then
        if is_vehicle_conv and native.call(0x96695E368AD855F3):__tonumber() < 0.1 then
            native.call(0xDED51F703D0FA83D, taxi_veh, false)
            repeat
                system.yield(250)
            until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 2
        end
    elseif taxi_conv.value == 1 then
        if is_vehicle_conv then
            native.call(0xDED51F703D0FA83D, taxi_veh, false)
            repeat
                system.yield(250)
            until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 2
        end
    elseif taxi_conv.value == 2 then
        if is_vehicle_conv then
            native.call(0x8F5FB35D7E88FC70, taxi_veh, false)
            repeat
                system.yield(250)
            until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 0
        end
    end

    resume_last_drive()

    while true do
        local postaxi = entity.get_entity_coords(taxi_veh)

        local dist_x = math.abs(postaxi.x - destv3_safe.x)
        local dist_y = math.abs(postaxi.y - destv3_safe.y)
        local dist_z = math.abs(postaxi.z - destv3_safe.z)

        local hori_dist = dist_x+dist_y


        if hori_dist < (last_drive.dist*2) and (dist_z < 5 or taxi_ignoreheight.on) then

            native.call(0x684785568EF26A22, taxi_veh, true)
            native.call(0xE4E2FD323574965C, taxi_veh, true)


            repeat
                system.yield(0)
            until entity.get_entity_speed(taxi_veh) < 8

            menu.notify("Arrived to Destination","Success",nil,0x00FF00)
            print("Taxi Arrived to Destination")

            repeat
                ai.task_leave_vehicle(taxi_driver, taxi_veh, 64)
                system.yield(500)
            until not ped.is_ped_in_vehicle(taxi_driver, taxi_veh)

            vehicle.set_vehicle_engine_on(taxi_veh, false, false, false)
            if is_vehicle_conv then
                native.call(0x8F5FB35D7E88FC70, taxi_veh, false)
                repeat
                    system.yield(250)
                until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 0
            end

            vehicle.start_vehicle_horn(taxi_veh, 1500, 0, false)
            system.yield(300)
            vehicle.start_vehicle_horn(taxi_veh, 1500, 0, false)
            system.yield(300)
            vehicle.start_vehicle_horn(taxi_veh, 1500, 0, false)

            if not taxi_per_veh.on then
                repeat
                    system.yield(0)
                until get_taken_seats(taxi_veh) == 0
            else
                vehicle.set_vehicle_doors_locked(taxi_veh, 1)
            end

            native.call(0x684785568EF26A22, taxi_veh, false)
            native.call(0xE4E2FD323574965C, taxi_veh, false)

            native.call(0x3B988190C0AA6C0B, taxi_veh, true)

            system.yield(3000)

            if not taxi_per_veh.on then
                native.call(0xDE564951F95E09ED, taxi_veh, true, true)
            end 

            native.call(0xDE564951F95E09ED, taxi_driver, true, true)
            system.yield(2000)

            clear_all(nil,true,true)
            menu.notify("Thanks you for using JJS-Taxi!","Thanks You",nil,0xc203fc)
            break
        end
        system.yield(0)
        if not is_taxi_active then break end
    end
end)
taxi_spawn.hint = "Spawns the taxi. Amazing isn't it?"

local taxi_spawn_pl = menu.add_player_feature("Spawn Taxi", "action", player_menu.id, function(ft, tar_player)

    if is_taxi_active then
        menu.notify("A taxi is already active.", "Error", nil, 0x0000FF)
        return
    else
        is_taxi_active = true
    end

    local found, spawn_point
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)

    local tar_player_pos = player.get_player_coords(tar_player)
    local tar_player_ped = player.get_player_ped(tar_player)


    local points = {}
    
    for i1=1, 360 do
        found, spawn_point = gameplay.find_spawn_point_in_direction(player_pos, v3(0,0,i1-180), 30)
        if found then
            points[#points+1] = {
                pos= {
                    x=spawn_point.x,
                    y=spawn_point.y,
                    z=spawn_point.z
                },
                rot=i1-180
            }
        end
        system.yield(0)
    end

    if taxi_per_veh.on then
        vehicle_hash = entity.get_entity_model_hash(player.get_personal_vehicle())
    else
        vehicle_hash = gameplay.get_hash_key(vehicle_name)

        if not streaming.is_model_a_vehicle(vehicle_hash) then
            vehicle_hash = tonumber(vehicle_name)
        end
    end

    request_model(vehicle_hash)

    local seat_count = vehicle.get_vehicle_model_number_of_seats(vehicle_hash)

    local s_point = table_random(points)
    local s_pos
    if not taxi_per_veh.on then
        s_pos = v3(s_point.pos.x,s_point.pos.y,s_point.pos.z)
    else
        s_pos = entity.get_entity_coords(player.get_personal_vehicle())
    end
    --s_pos = player_pos + v3(5,0,0)

    if not taxi_per_veh.on then
        taxi_veh = vehicle.create_vehicle(vehicle_hash, s_pos + v3(0,0,2), vector_to_heading(player_pos, s_pos), true, false)
    else
        taxi_veh = player.get_personal_vehicle()
    end

    system.yield(0)
    if ent_check(taxi_veh,true) then
        blips.taxi_veh = ui.add_blip_for_entity(taxi_veh)
        ui.set_blip_sprite(blips.taxi_veh, 198)
        ui.set_blip_colour(blips.taxi_veh, 2)
    end
    
    if not taxi_per_veh.on then
        vehicle.set_vehicle_mod_kit_type(taxi_veh, 0)

        vehicle.set_vehicle_colors(taxi_veh, 12, 12)
        vehicle.set_vehicle_extra_colors(taxi_veh, 64, 62)
        vehicle.set_vehicle_window_tint(taxi_veh, 1)

        vehicle.set_vehicle_mod(taxi_veh, 11, 3)
        vehicle.set_vehicle_mod(taxi_veh, 15, 3)
        vehicle.set_vehicle_mod(taxi_veh, 16, 4)
        vehicle.set_vehicle_mod(taxi_veh, 12, 2)
        vehicle.set_vehicle_mod(taxi_veh, 18, 1)
    end

    if seat_count > 2 then
        native.call(0xBE70724027F85BCD, taxi_veh, 0, 3)
        native.call(0xBE70724027F85BCD, taxi_veh, 1, 3)
    else
        native.call(0xBE70724027F85BCD, taxi_veh, 0, 3)
        native.call(0xBE70724027F85BCD, taxi_veh, 1, 0)
    end


    local vehicle_conv = native.call(0x52F357A30698BCCE, taxi_veh, false):__tointeger()

    if vehicle_conv == 1 then
        is_vehicle_conv = true
        print("Taxi vehicle is convertible")
    else
        is_vehicle_conv = false
        print("Taxi vehicle isn't convertible")
    end

    request_model(ped_hash)
    taxi_driver = ped.create_ped(0, ped_hash, s_pos+v3(3,0,0), 0, true, false)

    system.yield(0)
    ped.set_ped_into_vehicle(taxi_driver, taxi_veh, -1)

    native.call(0x9F8AA94D6D97DBF4, taxi_driver, true)
    native.call(0x1913FE4CBF41C463, taxi_driver, 255, true)
    native.call(0x1913FE4CBF41C463, taxi_driver, 251, true)

    streaming.set_model_as_no_longer_needed(ped_hash)
    streaming.set_model_as_no_longer_needed(vehicle_hash)

    ai.task_vehicle_follow(taxi_driver, taxi_veh, player_ped, 5, vehicle_drive_close, 10)
    repeat
        system.yield(250)
    until ped.is_ped_in_vehicle(player_ped, taxi_veh) or not is_taxi_active
    menu.notify("Welcome in JJS-Taxi!","Welcome",nil,0x00FF00)

    if taxi_radio_toggle.on then
        native.call(0x3B988190C0AA6C0B, taxi_veh, true)
        native.call(0x1B9C0099CB942AC6, taxi_veh, radio_stations[taxi_radio.value+1].id)
    else
        native.call(0x3B988190C0AA6C0B, taxi_veh, false)
    end

    if is_taxi_active then
        blips.tar_player = ui.add_blip_for_entity(tar_player_ped)
        ui.set_blip_sprite(blips.tar_player, 58)
        ui.set_blip_colour(blips.tar_player, 5)
        ui.set_blip_route(blips.tar_player, true)
        ui.set_blip_route_color(blips.tar_player, 46)


        request_control(taxi_driver)
        request_control(taxi_veh)

        local taxi_pos1 = entity.get_entity_coords(taxi_veh)

        if GET_STREET_NAME_AT_COORD(taxi_pos1.x, taxi_pos1.y, taxi_pos1.z).name == "Runway1" then
            request_model(vehicle_hash)
            menu.notify("Detected inside LSIA, exiting first.","LSIA Bullshit Pathing",nil,0x00AAFF)
            --native.call(0x195AEEB13CEFE2EE, taxi_driver, taxi_veh, lsia_exit.x, lsia_exit.y, lsia_exit.z, 30, 156, 5.0)
            for k,v in ipairs(lsia_exit) do
                if is_taxi_active then
                    menu.notify("Exiting LSIA Phase "..k.."/"..#lsia_exit,"LSIA Bullshit Pathing",nil,0x00AAFF)

                    ai.task_vehicle_drive_to_coord(taxi_driver, taxi_veh, v3(v.x, v.y, v.z), v.speed, 0, vehicle_hash, v.mode, 5, 10)
                    repeat
                        local postaxi = entity.get_entity_coords(taxi_veh)
                
                        local dist_x = math.abs(postaxi.x - v.x)
                        local dist_y = math.abs(postaxi.y - v.y)
                        local dist_z = math.abs(postaxi.z - v.z)
                
                        local hori_dist = dist_x+dist_y
                        system.yield(0)
                    until hori_dist < 20 or not is_taxi_active
                    system.yield(500)
                end
            end
            if is_taxi_active then
                menu.notify("Finally out of this mess.. Driving to destination now.","LSIA Bullshit Pathing",nil,0x00FF00)
            end
            streaming.set_model_as_no_longer_needed(vehicle_hash)
        end

        ai.task_vehicle_follow(taxi_driver, taxi_veh, tar_player_ped, 5, vehicle_drive, (taxi_dist/2))
        system.yield(250)
        ai.task_vehicle_follow(taxi_driver, taxi_veh, tar_player_ped, 5, vehicle_drive, (taxi_dist/2))
    end

    last_drive = {
        type="follow",
        driver=taxi_driver,
        veh=taxi_veh,
        dest=tar_player_ped,
        speed=vehicle_speed,
        mode=vehicle_drive,
        dist=(taxi_dist/2)
    }

    if taxi_conv.value == 0 then
        if is_vehicle_conv and native.call(0x96695E368AD855F3):__tonumber() < 0.1 then
            native.call(0xDED51F703D0FA83D, taxi_veh, false)
            repeat
                system.yield(250)
            until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 2
        end
    elseif taxi_conv.value == 1 then
        if is_vehicle_conv then
            native.call(0xDED51F703D0FA83D, taxi_veh, false)
            repeat
                system.yield(250)
            until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 2
        end
    elseif taxi_conv.value == 2 then
        if is_vehicle_conv then
            native.call(0x8F5FB35D7E88FC70, taxi_veh, false)
            repeat
                system.yield(250)
            until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 0
        end
    end

    resume_last_drive()

    while true do
        local postaxi = entity.get_entity_coords(taxi_veh)

        local dist_x = math.abs(postaxi.x - tar_player_pos.x)
        local dist_y = math.abs(postaxi.y - tar_player_pos.y)
        local dist_z = math.abs(postaxi.z - tar_player_pos.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < (last_drive.dist*2) then

            native.call(0x684785568EF26A22, taxi_veh, true)
            native.call(0xE4E2FD323574965C, taxi_veh, true)


            repeat
                system.yield(0)
            until entity.get_entity_speed(taxi_veh) < 8

            menu.notify("Arrived to Destination","Success",nil,0x00FF00)
            print("Taxi Arrived to Destination")

            repeat
                ai.task_leave_vehicle(taxi_driver, taxi_veh, 64)
                system.yield(500)
            until not ped.is_ped_in_vehicle(taxi_driver, taxi_veh)

            vehicle.set_vehicle_engine_on(taxi_veh, false, false, false)
            if is_vehicle_conv then
                native.call(0x8F5FB35D7E88FC70, taxi_veh, false)
                repeat
                    system.yield(250)
                until native.call(0xF8C397922FC03F41, taxi_veh):__tointeger() == 0
            end

            vehicle.start_vehicle_horn(taxi_veh, 1500, 0, false)
            system.yield(300)
            vehicle.start_vehicle_horn(taxi_veh, 1500, 0, false)
            system.yield(300)
            vehicle.start_vehicle_horn(taxi_veh, 1500, 0, false)

            if not taxi_per_veh.on then
                repeat
                    system.yield(0)
                until get_taken_seats(taxi_veh) == 0
            else
                vehicle.set_vehicle_doors_locked(taxi_veh, 1)
            end

            native.call(0x684785568EF26A22, taxi_veh, false)
            native.call(0xE4E2FD323574965C, taxi_veh, false)

            native.call(0x3B988190C0AA6C0B, taxi_veh, true)

            system.yield(3000)

            if not taxi_per_veh.on then
                native.call(0xDE564951F95E09ED, taxi_veh, true, true)
            end 

            native.call(0xDE564951F95E09ED, taxi_driver, true, true)
            system.yield(2000)

            clear_all(nil,true,true)
            menu.notify("Thanks you for using JJS-Taxi!","Thanks You",nil,0xc203fc)
            break
        end
        system.yield(0)
        if not is_taxi_active then break end
    end
end)
taxi_spawn_pl.hint = ("Spawns the taxi, will try to follow the player")

local taxi_status = menu.add_feature("Status: ", "action", main_menu.id, function()
end)
taxi_status.hint = "The current status of the taxi script"

local status_thread = menu.create_thread(function()
    while true do
        if is_taxi_active then
            taxi_status.name = ("Status: #FF00FF00#Active")
        else
            taxi_status.name = ("Status: #FF0000FF#Inactive")
        end
        system.yield(500)
    end
end)

local taxi_clear = menu.add_feature("Clean All", "action", main_menu.id, function()
    clear_all(nil,true,true)
end)
taxi_clear.hint = "Will try to clear all of the taxi script's stuff (vehicle,driver,blips)"

if false then --ENABLES DEBUG FUNCTIONS
    local taxi_debug = menu.add_feature("debug wp", "action", main_menu.id, function()
        local dest = ui.get_waypoint_coord()

        for k,v in ipairs(ground_check) do
            native.call(0x07503F7948F491A7, v3(dest.x, dest.y, v))
            system.yield(0)
        end

        system.yield(1500)

        for k,v in ipairs(ground_check) do
            local destv3_check = v3(dest.x, dest.y, v)
            local groundz = native.ByteBuffer8()
            native.call(0xC906A7DAB05C8D2B, destv3_check, groundz, false, false)
            print("Height: "..v.." Result: "..groundz:__tonumber())
            system.yield(0)
        end
    end)

    local taxi_debug2 = menu.add_feature("Notif ", "action", main_menu.id, function(ft)
        local status = 1
        local temp_color
        while status == 1 do
            status, temp_color = input.get("Hash Input","",10,0)
            system.yield(0)
        end
        final_color = tonumber(temp_color)

        ft.name = "Notif "..temp_color
        menu.notify("Test","Test",nil,final_color)
    end)

    local taxi_debug3 = menu.add_feature("IsConvertible", "action", main_menu.id, function(ft)
        local local_player = player.player_id()
        local player_pos = player.get_player_coords(local_player)
        local player_ped = player.get_player_ped(local_player)

        local player_veh = ped.get_vehicle_ped_is_using(player_ped)
        print(vehicle.is_vehicle_a_convertible(player_veh))
        if vehicle.is_vehicle_a_convertible(player_veh) then
            menu.notify("Yes, vehicle is convertible","Ye")
        else
            menu.notify("Nope, vehicle isn't convertible","No")
        end

        local conv_res = native.call(0x52F357A30698BCCE, player_veh, false):__tointeger()

        if conv_res == 1 then
            menu.notify("Yes, vehicle is convertible","NATIVE Ye")
        else
            menu.notify("Nope, vehicle isn't convertible","NATIVE No")
        end
    end)

    local taxi_debug4 = menu.add_feature("Get Locked", "action", main_menu.id, function(ft)
        for i1=1, 6 do
            local door = i1-1
            print("Door: "..door.." Status: "..native.call(0xCA4AC3EAAE46EC7B, taxi_veh, door):__tointeger())
            system.yield(0)
        end
    end)

    local street_debug_thread

    local taxi_debug5 = menu.add_feature("Debug Street Info","toggle",main_menu.id, function(ft)
        if ft.on then
            street_debug_thread = menu.create_thread(function()
                local function GET_STREET_NAME_FROM_HASH_KEY(hash)
                    return native.call(0xD0EF8A959B8A4CB9, hash):__tostring(true)
                end
                
                local function GET_STREET_NAME_AT_COORD(x, y, z)
                    local streetInfo = {name = "", crossingRoad = ""}
                
                    local bufferN = native.ByteBuffer8()
                    local bufferC = native.ByteBuffer8()
                
                    native.call(0x2EB41072B4C1E4C0, x, y, z, bufferN, bufferC)
                
                    streetInfo.name = GET_STREET_NAME_FROM_HASH_KEY(bufferN:__tointeger())
                    streetInfo.crossingRoad = GET_STREET_NAME_FROM_HASH_KEY(bufferC:__tointeger())
                
                    return streetInfo
                end
                while true do
                    local local_player = player.player_id()
                    local player_pos = player.get_player_coords(local_player)

                    local street_info = GET_STREET_NAME_AT_COORD(player_pos.x, player_pos.y, player_pos.z)
                    scriptdraw.draw_text(street_info.name, v2(0.2, 0.2), v2(0.2, 0.2), 0.8, 0xDD333333, (1<<4), nil)
                    scriptdraw.draw_text(street_info.name, v2(0.2, 0.2), v2(0.2, 0.2), 0.8, 0xFFFFFFFF, (1<<4), nil) --White text
                    system.yield(0)
                end
            end)
        else
            menu.delete_thread(street_debug_thread)
        end
    end)

    local get_pl = menu.add_feature("Print PL pos","action",main_menu.id,function()
        local local_player = player.player_id()
        local pl_pos = player.get_player_coords(local_player)
        menu.notify("X: "..pl_pos.x.." Y: "..pl_pos.y.." Z: "..pl_pos.z,"Coords",nil,0x00FF00)
        utils.to_clipboard("x="..pl_pos.x..", y="..pl_pos.y..", z="..pl_pos.z)
    end)
end

event.add_event_listener("exit", clear_all_noyield)

