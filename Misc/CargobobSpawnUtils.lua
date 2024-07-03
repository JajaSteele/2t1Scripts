if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("Cargobob Spawn Utils requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
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

function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

local cargo_hash = gameplay.get_hash_key("cargobob")

local vehicle_feature = menu.get_feature_by_hierarchy_key("spawn.vehicles.saved_vehicles")

local cargobob_autoenter = menu.add_integrated_feature_after("Cargobob Auto-Enter", "toggle", vehicle_feature)
cargobob_autoenter.hint = "Toggles whether the player is teleported in driver seat after spawning cargobob"
cargobob_autoenter.on = true

local spawn_cargobob = menu.add_integrated_feature_after("Spawn Cargobob", "action_value_str", vehicle_feature, function(ft)
    local player_id = player.player_id()
    local player_pos = player.get_player_coords(player_id)
    local player_heading = player.get_player_heading(player_id)

    local new_cargobob
    if cargobob_autoenter.on then
        new_cargobob = vehicle.create_vehicle(cargo_hash, player_pos+v3(0, 0, 5), player_heading, true, false)
        vehicle.set_heli_blades_full_speed(new_cargobob)
        ped.set_ped_into_vehicle(player.get_player_ped(player_id), new_cargobob, -1)
    else
        local spawn_pos = front_of_pos(player_pos, v3(0, 0, player_heading), 10)
        new_cargobob = vehicle.create_vehicle(cargo_hash, spawn_pos+v3(0, 0, 1), player_heading, true, false)
    end

    native.call(0x7BEB0C7A235F6F3B, new_cargobob, ft.value)
end)
spawn_cargobob:set_str_data({"Hook","Magnet"})
spawn_cargobob.hint = "Spawns a cargobob"