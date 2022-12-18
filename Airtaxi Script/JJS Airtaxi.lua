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
local vehicle_speed = 90.0
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


local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Airtaxi", "parent", 0)

local heli_select = menu.add_feature("Heli Model = [swift2]","action",main_menu.id,function(ft)
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
        ft.name = "Heli Model = [#FF0000FF#ERROR#DEFAULT#]"
        return
    end

    ft.name = "Heli Model = ["..vehicle_name.."]"
end)
heli_select.hint = "Set the model for your airtaxi helicopter.\nMight not work well with every helis (GTA's AI at fault lol)"

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

local heli_hoveratdest = menu.add_feature("Keep Hovering", "toggle", main_menu.id, function(ft)
end)
heli_hoveratdest.hint = "If enabled the heli won't land, and instead will hover above the destination."

local heli_speed = menu.add_feature("Speed = [90]", "action", main_menu.id, function(ft)
    local status = 1
    local temp_speed
    while status == 1 do
        status, temp_speed = input.get("Speed Input","",15,3)
        system.yield(0)
    end
    temp_speed = temp_speed..".0"
    vehicle_speed = tonumber(temp_speed)

    ft.name = "Speed = ["..vehicle_speed.."]"
    
    if is_heli_active then
        menu.notify("Speed updated to "..vehicle_speed,"Updated Speed", nil, 0x00FF00)
        native.call(0x5C9B84BD7D31D908, heli_ped, vehicle_speed)
        native.call(0x404A5AA9B9F0B746, heli_ped, vehicle_speed)
    end
end)
heli_speed.hint = "Choose the speed of the airtaxi. Default is 90"

local radio_menu = menu.add_feature("Radio","parent",main_menu.id)

local heli_radio = menu.add_feature("Station","action_value_str",radio_menu.id,function(ft)
    if is_heli_active and entity.is_an_entity(heli_veh or 0) then
        native.call(0x1B9C0099CB942AC6, heli_veh, radio_stations[ft.value+1].id)
        menu.notify("Set radio to "..radio_stations[ft.value+1].name.."("..radio_stations[ft.value+1].id..")","Radio",nil,0xFF00FF)
    end
end)
heli_radio.hint = "Choose the radio station to use!\nYou must 'Select' the radio after choosing the one you want."
heli_radio:set_str_data(radio_data)

local heli_radio_toggle = menu.add_feature("Enable","toggle",radio_menu.id,function(ft)
    if is_heli_active and entity.is_an_entity(heli_veh or 0) then
        native.call(0x3B988190C0AA6C0B, heli_veh, ft.on)
        native.call(0x1B9C0099CB942AC6, heli_veh, radio_stations[heli_radio.value+1].id)
    end
end)
heli_radio_toggle.hint = "Toggle the radio ON or OFF"

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

    vehicle.set_vehicle_mod_kit_type(heli_veh, 0)
    vehicle.set_vehicle_colors(heli_veh, 107, 99)
    vehicle.set_vehicle_extra_colors(heli_veh, 36, 0)
    vehicle.set_vehicle_window_tint(heli_veh, 1)

    if heli_radio_toggle.on then
        native.call(0x3B988190C0AA6C0B, heli_veh, true)
        native.call(0x1B9C0099CB942AC6, heli_veh, radio_stations[heli_radio.value+1].id)
    else
        native.call(0x3B988190C0AA6C0B, heli_veh, false)
    end

    if heli_allowfront.on then
        native.call(0xBE70724027F85BCD, heli_veh, 0, 0)
        native.call(0xBE70724027F85BCD, heli_veh, 1, 0)
    else
        native.call(0xBE70724027F85BCD, heli_veh, 0, 3)
        native.call(0xBE70724027F85BCD, heli_veh, 1, 3)
    end

    if entity.is_an_entity(heli_veh) then
        blips.heli_veh = ui.add_blip_for_entity(heli_veh)
        ui.set_blip_sprite(blips.heli_veh, 422)
        ui.set_blip_colour(blips.heli_veh, 2)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Your Airtaxi")
        native.call(0xBC38B49BCB83BC9B, blips.heli_veh)
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
    until native.call(0x1DD55701034110E5, heli_veh):__tonumber() < 10 or not is_heli_active

    menu.notify("Greetings.\nEnter the helicopter to start.","JJS Airtaxi",nil,0xFF00FF)

    repeat
        system.yield(0)
    until ped.is_ped_in_vehicle(player_ped, heli_veh) or not is_heli_active

    system.yield(2000)

    local wp = ui.get_waypoint_coord()
    local wpz = get_ground(wp)

    local wp3 = v3(wp.x, wp.y, wpz+100)

    menu.notify("Flying to:\nX: "..wp3.x.." Y: "..wp3.y.." Z: "..wp3.z,"Flying to Dest",nil,0x00AAFF)

    blips.dest = ui.add_blip_for_coord(wp3)
    ui.set_blip_sprite(blips.dest, 58)
    ui.set_blip_colour(blips.dest, 5)

    native.call(0xF9113A30DE5C6670, "STRING")
    native.call(0x6C188BE134E074AA, "Airtaxi Destination")
    native.call(0xBC38B49BCB83BC9B, blips.dest)

    print("Flying to dest")
    request_control(heli_veh)
    request_control(heli_ped)
    native.call(0xE1EF3C1216AFF2CD, heli_ped)
    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, vehicle_speed, 50.0, -1, 300, 100, 200.0, 0)

    while true do
        local heli_pos_live = entity.get_entity_coords(heli_veh)

        local dist_x = math.abs(heli_pos_live.x - wp3.x)
        local dist_y = math.abs(heli_pos_live.y - wp3.y)
        local dist_z = math.abs(heli_pos_live.z - wp3.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 300 or not is_heli_active then
            print("Slowing Down")
            native.call(0x5C9B84BD7D31D908, heli_ped, 20)
            break
        end
        system.yield(0)
    end

    print("Landing to dest")
    request_control(heli_veh)
    request_control(heli_ped)
    native.call(0xE1EF3C1216AFF2CD, heli_ped)
    native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, 20.0, 10.0, -1, 50, 30, 75.0, 0)

    while true do
        local heli_pos_live = entity.get_entity_coords(heli_veh)

        local dist_x = math.abs(heli_pos_live.x - wp3.x)
        local dist_y = math.abs(heli_pos_live.y - wp3.y)
        local dist_z = math.abs(heli_pos_live.z - wp3.z)

        local hori_dist = dist_x+dist_y

        if hori_dist < 15 or not is_heli_active then
            print("Landing")
            break
        end
        system.yield(0)
    end

    if not heli_hoveratdest.on then
        menu.notify("Landing at dest..","Landing",nil,0x00AAFF)
        request_control(heli_veh)
        request_control(heli_ped)
        native.call(0xE1EF3C1216AFF2CD, heli_ped)
        native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, 60.0, 10.0, -1, 50, 30, 75.0, 32)

        repeat
            system.yield(0)
            if native.call(0x634148744F385576, heli_veh):__tointeger() == 1 then
                local curr_vel = entity.get_entity_velocity(heli_veh)
                entity.set_entity_velocity(heli_veh, v3(curr_vel.x, curr_vel.y, -0.75))
            end
        until native.call(0x1DD55701034110E5, heli_veh):__tonumber() < 10 or not is_heli_active
    else
        menu.notify("Hovering above dest","Hovering",nil,0x00AAFF)
        native.call(0xDAD029E187A2BEB4, heli_ped, heli_veh, 0, 0, wp3.x, wp3.y, wp3.z, 4, 20.0, 10.0, -1, 100, 5, 75.0, 0)
    end

    system.yield(1000)

    menu.notify("Arrived to destination! Please exit shortly.","JJS Airtaxi",nil,0x00FF00)

    repeat
        system.yield(0)
    until get_taken_seats(heli_veh) <= 1 or not is_heli_active

    system.yield(3000)

    native.call(0xDE564951F95E09ED, heli_veh, true, true)
    native.call(0xDE564951F95E09ED, heli_ped, true, true)

    system.yield(2000)

    clear_all(nil,true,true)
    menu.notify("Thanks you for using JJS-Airtaxi!","Thanks You",nil,0xc203fc)
    is_heli_active = false
end)

local heli_status = menu.add_feature("Status: ", "action", main_menu.id, function()
    menu.notify("idk what you expected to happen, but hello","fard",nil,0x00FF00)
end)
heli_status.hint = "The current status of the airtaxi script"

local status_thread = menu.create_thread(function()
    while true do
        if is_heli_active then
            heli_status.name = ("Status: #FF00FF00#Active")
        else
            heli_status.name = ("Status: #FF0000FF#Inactive")
        end
        system.yield(500)
    end
end)

local clean_heli = menu.add_feature("Clear All","action",main_menu.id,function()
    clear_all(nil,true,true,false)
end)
clean_heli.hint = "Clean up heli + pilot"

event.add_event_listener("exit", clear_all_noyield)