if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Boat requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Private%20Boat/JJS.Boat.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Boat.lua"

        local file1 = io.open(path, "r")
        curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Boat",nil,0x00AAFF)
            choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Boat",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Boat",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Boat",nil,0xFF00FF)
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

local vehicle_hash = gameplay.get_hash_key("marquis")
local vehicle_name = "marquis"
local ped_hash = 3361671816
local vehicle_speed = 20.0
local drive_mode = 61
local drive_mode_direct = 21758525

local blips = {}
local boat_ped
local boat_veh
local boat_jetskis = {}

local driver_alt_seat = 0

local is_boat_active = false
local clearing = false
local clear_ap = false

local function clear_jetskis()
    for k,v in pairs(boat_jetskis) do
        request_control(v)
        entity.delete_entity(v)
        boat_jetskis[k] = nil
    end
end

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

    clear_jetskis()

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
boat_select.hint = "Set the model for your boat.\nDefault is 'marquis'"

local radio_menu = menu.add_feature("Radio","parent",main_menu.id)
radio_menu.hint = "Unfortunately this only works if you're in a passenger seat/driving it :C"

local boat_radio = menu.add_feature("Station","action_value_str",radio_menu.id,function(ft)
    if entity.is_an_entity(boat_veh or 0) then
        native.call(0x1B9C0099CB942AC6, boat_veh, radio_stations[ft.value+1].id)
        menu.notify("Set radio to "..radio_stations[ft.value+1].name.."("..radio_stations[ft.value+1].id..")","Radio",nil,0xFF00FF)
    end
end)
boat_radio.hint = "Choose the radio station to use!\nYou must 'Select' the radio after choosing the one you want."
boat_radio:set_str_data(radio_data)

local boat_radio_toggle = menu.add_feature("Enable","toggle",radio_menu.id,function(ft)
    if entity.is_an_entity(boat_veh or 0) then
        vehicle.set_vehicle_engine_on(boat_veh, true, true, false)
        native.call(0x3B988190C0AA6C0B, boat_veh, ft.on)
        native.call(0x1B9C0099CB942AC6, boat_veh, radio_stations[boat_radio.value+1].id)
    end
end)
boat_radio_toggle.hint = "Toggle the radio ON or OFF"

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

        if boat_radio_toggle.on then
            native.call(0x3B988190C0AA6C0B, boat_veh, true)
            native.call(0x1B9C0099CB942AC6, boat_veh, radio_stations[boat_radio.value+1].id)
        else
            native.call(0x3B988190C0AA6C0B, boat_veh, false)
        end

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

local boat_speed = menu.add_feature("Speed = [20.0]", "action", main_menu.id, function(ft)
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
boat_speed.hint = "Choose the speed of the boat. Default is 20.0"

local autopilot_menu = menu.add_feature("Autopilot","parent",main_menu.id)

local autopilot_mode = menu.add_feature("Mode","autoaction_value_str",autopilot_menu.id)
autopilot_mode:set_str_data({"Pathed","Dynamic","Direct"})
autopilot_mode.hint = "Change which method is used for driving the boat.\n'Direct' will not avoid any objects!"

local function goto_wp()
    if entity.is_an_entity(boat_veh) and entity.is_an_entity(boat_ped) then
        is_boat_active = true
        local wp = ui.get_waypoint_coord()

        native.call(0x75DBEC174AEEAD10, boat_veh, false)

        if autopilot_mode.value == 0 then
            ai.task_vehicle_drive_to_coord_longrange(boat_ped, boat_veh, v3(wp.x, wp.y, 0.0), vehicle_speed, drive_mode, 30)
        elseif autopilot_mode.value == 1 then
            native.call(0x15C86013127CE63F, boat_ped, boat_veh, 0, 0, wp.x, wp.y, 0.0, 4, vehicle_speed, drive_mode, 60, 7)
        elseif autopilot_mode.value == 2 then
            ai.task_vehicle_drive_to_coord_longrange(boat_ped, boat_veh, v3(wp.x, wp.y, 0.0), vehicle_speed, drive_mode_direct, 30)
        end

        repeat
            system.yield(0)
        until vehicle.get_ped_in_vehicle_seat(boat_veh or 0, -1) == boat_ped or clear_ap

        native.call(0x1913FE4CBF41C463, boat_ped, 255, true)
        native.call(0x1913FE4CBF41C463, boat_ped, 251, true)

        while true do
            local boat_pos_live = entity.get_entity_coords(boat_veh)

            local dist_x = math.abs(boat_pos_live.x - wp.x)
            local dist_y = math.abs(boat_pos_live.y - wp.y)

            local hori_dist = dist_x+dist_y
            system.yield(0)
            if hori_dist < 50 then
                if autopilot_mode.value == 0 then
                    ai.task_vehicle_drive_to_coord(boat_ped, boat_veh, v3(wp.x, wp.y, 0.0), 0.2, 0, 0, drive_mode, 30, 0)
                elseif autopilot_mode.value == 1 then
                    native.call(0x15C86013127CE63F, boat_ped, boat_veh, 0, 0, wp.x, wp.y, 0.0, 4, 0.2, drive_mode, 60, 7)
                elseif autopilot_mode.value == 2 then
                    ai.task_vehicle_drive_to_coord(boat_ped, boat_veh, v3(wp.x, wp.y, 0.0), 0.2, 0, 0, drive_mode_direct, 30, 0)
                end
                menu.notify("Arrived to Dest!","Arrived",nil,0x00FF00)
                repeat
                    system.yield(0)
                until entity.get_entity_speed(boat_veh) < 1 or not entity.is_an_entity(boat_veh) or clear_ap
                break
            end
            if not entity.is_an_entity(boat_veh) or clear_ap then
                break
            end
        end
        native.call(0x75DBEC174AEEAD10, boat_veh, true)

        local seat_count = vehicle.get_vehicle_model_number_of_seats(vehicle_hash)
        
        if seat_count > 1 then
            ai.task_enter_vehicle(boat_ped, boat_veh, 10000, driver_alt_seat, 1, 1, 0)
        else
            ai.task_leave_vehicle(boat_ped, boat_veh, 64)
        end

        repeat
            system.yield(0)
        until ped.get_vehicle_ped_is_using(boat_ped) ~= boat_veh
        vehicle.set_vehicle_engine_on(boat_veh, false, true, false)
        is_boat_active = false
        clear_ap = false
    end
end

local autopilot_wp = menu.add_feature("Autopilot to WP","action",autopilot_menu.id, goto_wp)
autopilot_wp.hint = "Will try to go to waypoint, seems to stop working if far from coast\nAlso will get stuck very easily, GTA ai sucks for boats.."

local autopilot_clear = menu.add_feature("Clear Autopilot","action",autopilot_menu.id, function()
    if is_boat_active then
        clear_ap = true
    end
end)

local seat_data = {}

local enter_seat

local enter_seat_menu = menu.add_feature("Enter Seat","parent",main_menu.id,function()
    request_model(vehicle_hash)
    local seat_counts = vehicle.get_vehicle_model_number_of_seats(vehicle_hash)
    seat_data = {}
    for i1=1, seat_counts do
        seat_data[i1] = tostring(i1-2)
        system.yield(0)
    end
    enter_seat:set_str_data(seat_data)
end)

enter_seat = menu.add_feature("Enter Seat","action_value_str",enter_seat_menu.id,function(ft)
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    if entity.is_an_entity(boat_veh) then
        ai.task_enter_vehicle(player_ped, boat_veh, 10000, ft.value-1, 1, 1, 0)
    end
end)
enter_seat.hint = "GTA is weird with boats so you can't always enter the other seats, this should help!"

local clean_boat = menu.add_feature("Clear All","action",main_menu.id,function()
    clear_all(nil,true,true,false)
    clearing = true
end)
clean_boat.hint = "Clean up boat + driver (Might take a while before being inactive)"

local spawn_menu = menu.add_feature("Jetski Menu","parent",main_menu.id)

local spawn_jetski = menu.add_feature("Spawn Jetski","action",spawn_menu.id,function()
    if entity.is_an_entity(boat_veh or 0) then
        local boat_heading = entity.get_entity_heading(boat_veh)
        local boat_pos = entity.get_entity_coords(boat_veh)

        local spawn_pos = front_of_pos(boat_pos,v3(0,0,boat_heading),-16)
        local jetski_hash = gameplay.get_hash_key("seashark")
        request_model(jetski_hash)
        boat_jetskis[#boat_jetskis+1] = vehicle.create_vehicle(jetski_hash, spawn_pos, boat_heading+180, true, false)
    end
end)
spawn_jetski.hint = "Spawns a jetski at the back of the boat"

local clear_jetski = menu.add_feature("Clear Jetskis","action",spawn_menu.id,clear_jetskis)
clear_jetski.hint = "Remove all the jetskis"

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