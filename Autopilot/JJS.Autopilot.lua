if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS Autopilot requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Autopilot/JJS.Autopilot.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Autopilot.lua"

        local file1 = io.open(path, "r")
        local curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Autopilot",nil,0x00AAFF)
            local choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Autopilot",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Autopilot",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Autopilot",nil,0xFF00FF)
            print("Update HTTP for JJS Autopilot: "..code)
        end
    end)
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

local veh_pilot = 0
local blips = {}

local veh = 0

local autopilot_active = false

local vehicle_drive = 1076632110
local vehicle_drive_close = 1076632111

local autopilot_speed = 25

local last_drive = {}

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

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    entity.delete_entity(veh_pilot or 0)

    autopilot_active = false
    
    veh_pilot = 0
end

event.add_event_listener("exit", clear_all_noyield)

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

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Autopilot","parent",0)

local select_veh_type = menu.add_feature("Select Autopilot Vehicle", "action_value_str", main_menu.id, function(ft)
    if ft.value == 0 then
        veh = find_veh(632) or 0
    elseif ft.value == 1 then
        veh = find_veh(564) or 0
    elseif ft.value == 2 then
        veh = find_veh(840) or 0
    end
    if veh ~= 0 then
        menu.notify("Selected vehicle "..veh, "JJS Autopilot", nil, 0xFF00FF00)
    else
        menu.notify("No vehicle found", "JJS Autopilot", nil, 0xFF0000FF)
    end
end)
select_veh_type:set_str_data({"Terrorbyte", "MOC", "Acid Lab"})

local select_dest = menu.add_feature("Destination", "action_value_str", main_menu.id)
select_dest:set_str_data({"Waypoint", "Current"})
select_dest.hint = "Choose which vehicle to autopilot, then use \"Select\" to register it."

local function resume_last_drive()
    native.call(0xE1EF3C1216AFF2CD, veh_pilot)
    ai.task_vehicle_drive_to_coord_longrange(last_drive.driver, last_drive.veh, v3(last_drive.dest.x, last_drive.dest.y, last_drive.dest.z), last_drive.speed, vehicle_drive, last_drive.dist)
    print(last_drive.driver, last_drive.veh, v3(last_drive.dest.x, last_drive.dest.y, last_drive.dest.z), last_drive.speed, vehicle_drive, last_drive.dist)
end

local autopilot_speed_choose = menu.add_feature("Speed = [25]", "action", main_menu.id, function(ft)
    local status = 1
    local temp_speed
    while status == 1 do
        status, temp_speed = input.get("Speed Input","",15,3)
        system.yield(0)
    end
    autopilot_speed = tonumber(temp_speed)

    ft.name = "Speed = ["..temp_speed.."]"
    
    menu.notify("Speed updated to "..autopilot_speed,"Updated Speed", nil, 0x00FF00)
    last_drive["speed"] = autopilot_speed
    resume_last_drive()
end)
autopilot_speed_choose.hint = "Choose the speed of the autopilot driver. Default is 25"

local activate_autopilot = menu.add_feature("Activate Autopilot", "action", main_menu.id, function(ft)
    request_model(ped_hash)
    local veh_pos = entity.get_entity_coords(veh or 0)
 
    veh_pilot = ped.create_ped(0, ped_hash, veh_pos+v3(0,0,1), 0, true, false)

    request_control(veh_pilot)
    ped.set_ped_into_vehicle(veh_pilot, veh, -1)
    native.call(0x9F8AA94D6D97DBF4, veh_pilot, true)
    native.call(0x1913FE4CBF41C463, veh_pilot, 255, true)
    native.call(0x1913FE4CBF41C463, veh_pilot, 251, true)

    local dest_v3

    if select_dest.value == 0 then
        local dest_pos = ui.get_waypoint_coord()
        local dest_z = get_ground(dest_pos)
        dest_v3 = v3(dest_pos.x, dest_pos.y, dest_z)
    elseif select_dest.value == 1 then
        local local_player = player.player_id()
        dest_v3 = player.get_player_coords(local_player)
    end

    request_control(veh_pilot)
    request_control(veh)
    ai.task_vehicle_drive_to_coord_longrange(veh_pilot, veh, dest_v3, autopilot_speed, vehicle_drive, 15)

    last_drive = {
        driver=veh_pilot,
        veh=veh,
        dest={
            x=dest_v3.x,
            y=dest_v3.y,
            z=dest_v3.z
        },
        speed=autopilot_speed,
        mode=vehicle_drive,
        dist=15
    }

    system.yield(10)

    repeat
        local posautopilot = entity.get_entity_coords(veh)

        local dist_x = math.abs(posautopilot.x - dest_v3.x)
        local dist_y = math.abs(posautopilot.y - dest_v3.y)
        local dist_z = math.abs(posautopilot.z - dest_v3.z)

        local speed = entity.get_entity_velocity(veh)
        local hori_speed = math.abs(speed.x) + math.abs(speed.y)

        local hori_dist = dist_x+dist_y

        system.yield(0)
    until hori_dist < 40 and dist_z < 5 and hori_speed < 2

    menu.notify("Arrived to Dest!", "JJS Autopilot", nil, 0xFF00FF00)
    print("Arrived to Dest")

    request_control(veh_pilot)
    ai.task_leave_vehicle(veh_pilot, veh, 64)

    repeat
        system.yield(0)
    until ped.get_vehicle_ped_is_using(veh_pilot) == 0

    native.call(0xDE564951F95E09ED, veh_pilot, true, true)
    system.yield(2000)
    clear_all_noyield()

    request_control(veh)
    vehicle.set_vehicle_engine_on(veh, false, true, false)
end)

if false then --DEBUG SHIT
    local debug_menu = menu.add_feature("Debug Menu", "parent", main_menu.id)
    menu.add_feature("Get blip from current vehicle", "action", debug_menu.id, function()
        local local_player = player.player_id()
        local player_ped = player.get_player_ped(local_player)

        local player_veh = native.call(0xF92691AED837A5FC, player_ped):__tointeger()
        local blip = ui.get_blip_from_entity(player_veh)
        local blipsprite = native.call(0x1FC877464A04FC4F, blip):__tointeger()
        menu.notify("Current Vehicle's blip\nID: "..blip.."\nSprite ID: "..blipsprite)
    end)
end