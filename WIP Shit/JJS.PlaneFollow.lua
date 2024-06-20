if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS AirSupport requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
    menu.exit()
end

local function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

local function vector_to_heading(_target,_start)
    return math.atan((_target.x - _start.x), (_target.y - _start.y)) * -180 / math.pi
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

local function request_control_noyield(_ent)
    for i1=1, 75 do
        network.request_control_of_entity(_ent)
        if network.has_control_of_entity(_ent) then
            break
        end
    end
end

local pilot_ped = 0
local pilot_hash = 988062523

menu.add_player_feature("Follow With Current Plane","action",0,function(feat,pid)
    local plane_vehicle = player.player_vehicle()
    local spawn_pos = entity.get_entity_coords(plane_vehicle)
    local spawn_heading = entity.get_entity_rotation(plane_vehicle)

    request_model(pilot_hash)
    pilot_ped = ped.create_ped(0, pilot_hash, spawn_pos + v3(0,0,2), spawn_heading.y, true, false)
    streaming.set_model_as_no_longer_needed(pilot_hash)

    native.call(0x1F4ED342ACEFE62D, pilot_ped, true, true)

    native.call(0x9F8AA94D6D97DBF4, pilot_ped, true)
    native.call(0x1913FE4CBF41C463, pilot_ped, 255, true)
    native.call(0x1913FE4CBF41C463, pilot_ped, 251, true)
    native.call(0x1913FE4CBF41C463, pilot_ped, 184, true)

    ped.set_ped_into_vehicle(pilot_ped, plane_vehicle, -1)

    native.call(0x2D2386F273FF7A25, pilot_ped, player.get_player_ped(pid))
end)

menu.add_player_feature("Kill Latest Pilot","action",0,function(feat,pid)
    request_control(pilot_ped)
    entity.delete_entity(pilot_ped)
end)

menu.add_player_feature("Kill Current Pilot","action",0,function(feat,pid)
    local plane_vehicle = player.player_vehicle()
    local pilot = vehicle.get_ped_in_vehicle_seat(plane_vehicle, -1)
    if ped.is_ped_a_player(pilot) then
        menu.notify("Couldn't delete pilot!\nPilot is a player.")
        return
    end
    if pilot ~= 0 and pilot ~= nil then
        request_control(pilot)
        entity.delete_entity(pilot)
    end
end)

menu.add_player_feature("Kill Current Pilot & Steal Plane","action",0,function(feat,pid)
    local plane_vehicle = player.player_vehicle()
    local pilot = vehicle.get_ped_in_vehicle_seat(plane_vehicle, -1)
    if ped.is_ped_a_player(pilot) then
        menu.notify("Couldn't delete pilot!\nPilot is a player.")
        return
    end
    if pilot ~= 0 and pilot ~= nil then
        request_control(pilot)
        entity.delete_entity(pilot)
    end

    ped.set_ped_into_vehicle(player.player_ped(), plane_vehicle, -1)
end)