if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("Pets requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
    menu.exit()
end


local pets_ents = {}
local blips = {}

local ped_hash = gameplay.get_hash_key("A_C_Cow")
print(ped_hash)
print(streaming.is_model_a_ped(ped_hash))

local selected_pet = {short_name="A_C_Cow"}

local function clear_all_noyield(delay)
    if delay and type(delay) == "number" then
        system.yield(delay)
    end

    for k,v in pairs(blips) do
        ui.remove_blip(v)
    end

    for k,v in pairs(pets_ents) do
        entity.delete_entity(v.id or 0)
    end
    
    pets_ents = {}
    blips = {}
end

event.add_event_listener("exit", clear_all_noyield)

local function request_model(_hash)
    if not streaming.has_model_loaded(_hash) then
        streaming.request_model(_hash)
        local attempts = 50
        while (not streaming.has_model_loaded(_hash)) and attempts > 0 do
            system.yield(10)
            attempts = attempts-1
        end

        return streaming.has_model_loaded(_hash)
    else
        return streaming.has_model_loaded(_hash)
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

local function clear_all(delay,peds)
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

    for k,v in pairs(pets_ents) do
        menu.create_thread(function()
            native.call(0xDE564951F95E09ED, v.id, true, true)
            system.yield(1500)
            local attempts = 0
            request_control(v.id)
            repeat
                entity.delete_entity(v.id)
                system.yield(0)
                attempts = attempts+1
            until not entity.is_an_entity(v.id) or attempts > 30
        end)
    end

    pets_ents = {}

    if peds then
        autopilot_active = false
    end
end

function front_of_pos(_pos,_rot,_dist)
    _rot:transformRotToDir()
    _rot = _rot * _dist
    _pos = _pos + _rot
    return _pos
end

local animals_table = {
    {name="A_C_Westy", short_name="Westy"},
    {name="a_c_sharktiger", short_name="Tiger Shark"},
    {name="a_c_shepherd", short_name="Shepherd"},
    {name="A_C_Rottweiler", short_name="Rottweiler"},
    {name="A_C_Rat", short_name="Rat"},
    {name="A_C_Rhesus", short_name="Rhesus"},
    {name="A_C_Retriever", short_name="Retriever"},
    {name="a_c_rabbit_01", short_name="Rabbit"},
    {name="A_C_Rabbit_02", short_name="Giant Rabbit"},
    {name="A_C_Pug", short_name="Pug"},
    {name="A_C_Poodle", short_name="Poodle"},
    {name="A_C_Pigeon", short_name="Pigeon"},
    {name="A_C_Pig", short_name="Pig"},
    {name="a_c_mtlion", short_name="Mountain Lion"},
    {name="A_C_KillerWhale", short_name="Killer Whale"},
    {name="A_C_Husky", short_name="Husky"},
    {name="A_C_Humpback", short_name="Humpback"},
    {name="A_C_Hen", short_name="Hen"},
    {name="A_C_SharkHammer", short_name="Hammer Shark"},
    {name="A_C_Fish", short_name="Fish"},
    {name="A_C_Dolphin", short_name="Dolphin"},
    {name="A_C_Deer", short_name="Deer"},
    {name="A_C_Crow", short_name="Crow"},
    {name="A_C_Coyote", short_name="Coyote"},
    {name="A_C_Cow", short_name="Cow"},
    {name="A_C_Cormorant", short_name="Cormorant"},
    {name="A_C_Chop", short_name="Chop"},
    {name="A_C_Chimp", short_name="Chimp"},
    {name="A_C_ChickenHawk", short_name="Chicken Hawk"},
    {name="A_C_Cat_01", short_name="Cat"},
    {name="A_C_Boar", short_name="Boar"},
}

local preset_data = {}

for k,v in ipairs(animals_table) do
    preset_data[#preset_data+1] = v.short_name
end

local follow_types = {
    "Default",
    "Circle",
    "Circle 2",
    "Line"
}

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Pet","parent",0)

local pet_ped_preset = menu.add_feature("Preset Model","action_value_str",main_menu.id, function(ft)
    selected_pet = animals_table[ft.value+1]
    if selected_pet ~= nil then
        ped_hash = gameplay.get_hash_key(selected_pet.name)
        menu.notify("Set the pet model to "..selected_pet.name.." ("..ped_hash..")","Success",nil,0x00FF00)
    else
        menu.notify("Selected pet is invalid!","Error",nil,0x0000FF)
    end
end)
pet_ped_preset:set_str_data(preset_data)
pet_ped_preset.hint = "Choose the ped model for your pet. \nBirds will walk slowly instead of flying, not sure why"

local pet_ped = menu.add_feature("Custom Model = [A_C_Cow]", "action", main_menu.id, function(ft)
    local status = 1
    local ped_name
    while status == 1 do
        status, ped_name = input.get("Name/Hash Input","",15,0)
        system.yield(0)
    end
    ped_hash = gameplay.get_hash_key(ped_name)

    if not streaming.is_model_a_ped(ped_hash or 0) then
        ped_hash = tonumber(ped_name)
    end

    if not streaming.is_model_a_ped(ped_hash or 0) then
        menu.notify("Warning! Ped model doesn't exist!","!WARNING!",nil,0x0000FF)
        return
    end

    selected_pet = {short_name=ped_name}
    ft.name = "Pet Model = ["..ped_name.."]"
end)
pet_ped.hint = "Choose the custom ped model for your pet."

-- local follow_slider = menu.add_feature("Follow Distance = [15]","autoaction_slider",main_menu.id,function(ft)
--     ft.name = string.format("Follow Distance = [%.0f]",ft.value*50)
-- end)
-- follow_slider.min = 1
-- follow_slider.max = 10
-- follow_slider.value = 3
-- 
-- local apply_follow = menu.add_feature("Apply Follow Dist","action",main_menu.id,function(ft)
--     local local_player = player.player_id()
--     local player_ped = player.get_player_ped(local_player)
--     for k,v in pairs(pets_ents) do
--         ft.name = "Apply Follow Dist ("..k..")"
--         ai.task_follow_to_offset_of_entity(v, player_ped, v3(1,1,0), 5, -1, follow_slider.value*50, true)
--         system.yield(0)
--     end
--     ft.name = "Apply Follow Dist"
-- end)

local follow_type = menu.add_feature("Follow Type","autoaction_value_str",main_menu.id,function(ft)
    local local_player = player.player_id()
    local player_ped = player.get_player_ped(local_player)
    local player_group = player.get_player_group(local_player)

    for k,v in pairs(pets_ents) do
        request_control(v.id)
        ped.set_ped_as_group_member(v.id, player_group)
        system.yield(0)
    end
    ped.set_ped_as_group_leader(player_ped, player_group)

    ped.set_group_formation(player_group, ft.value)
    print("Set group formation to "..ft.value)
end)
follow_type:set_str_data(follow_types)
follow_type.hint = "Set how the pets will follow you (formation)"

local follow_offset = menu.add_feature("Follow Length = [1.5]","autoaction_slider",main_menu.id, function(ft)
    local local_player = player.player_id()
    local player_ped = player.get_player_ped(local_player)
    local player_group = player.get_player_group(local_player)

    for k,v in pairs(pets_ents) do
        request_control(v.id)
        ped.set_ped_as_group_member(v.id, player_group)
        system.yield(0)
    end
    ped.set_ped_as_group_leader(player_ped, player_group)

    ped.set_group_formation_spacing(player_group, ft.value/2, ft.value/2, 0)
    ft.name = string.format("Follow Length = [%.1f]",ft.value/2)
    print("Set group spacing to "..ft.value/2)
end)
follow_offset.min = 1
follow_offset.max = 15
follow_offset.value = 3
follow_offset.hint = "Set the distance at which your pets will follow you"

local pet_godmod = menu.add_feature("God Mode", "toggle", main_menu.id, function(ft)
    for k,v in pairs(pets_ents) do
        entity.set_entity_god_mode(v.id, ft.on)
        system.yield(0)
    end
    menu.notify("Applied god mode '"..tostring(ft.on).."' to all existing pets","Pet God Mode",nil,0x00FF00)
end)
pet_godmod.hint = "Apply god mode to all new and existing pets."
pet_godmod.on = true

local del_bodies = menu.add_feature("Delete Bodies", "toggle", main_menu.id, function(ft)
end)
del_bodies.hint= "Delete bodies when pet dies."

local spawn_pet = menu.add_feature("Spawn Pet","action", main_menu.id, function()
    local local_player = player.player_id()
    local player_pos = player.get_player_coords(local_player)
    local player_ped = player.get_player_ped(local_player)
    local player_heading = player.get_player_heading(local_player)

    local player_group = player.get_player_group(local_player)

    if request_model(ped_hash) then
        local new_pet = ped.create_ped(0, ped_hash, front_of_pos(player_pos, v3(0,0,player_heading), 1.5), player_heading-180, true, false)
        native.call(0x9F8AA94D6D97DBF4, new_pet, true)

        native.call(0x1F4ED342ACEFE62D, new_pet, true, false)
        
        streaming.set_model_as_no_longer_needed(ped_hash)

        pets_ents[#pets_ents+1] = {
            id=new_pet,
            faded=false
        }

        local pet_id = #pets_ents
        local blip_name = "pet_"..pet_id
        

        blips[blip_name] = ui.add_blip_for_entity(new_pet)
        ui.set_blip_sprite(blips[blip_name], 273)
        ui.set_blip_colour(blips[blip_name], 2)

        native.call(0xF9113A30DE5C6670, "STRING")
        native.call(0x6C188BE134E074AA, "Pet "..pet_id.." ("..selected_pet.short_name..")")
        native.call(0xBC38B49BCB83BC9B, blips[blip_name])

        native.call(0xA53ED5520C07654A, new_pet, player_ped, false)

        --ai.task_follow_to_offset_of_entity(new_pet, player_ped, v3(1,1,0), 5, -1, 20, true)

        ped.set_ped_as_group_member(new_pet, player_group)
        ped.set_ped_as_group_leader(player_ped, player_group)

        ped.set_group_formation(player_group, follow_type.value)
        ped.set_group_formation_spacing(player_group, follow_offset.value/2, follow_offset.value/2, 0)

        entity.set_entity_as_mission_entity(new_pet,true,false)

        native.call(0x1913FE4CBF41C463, new_pet, 13, true)

        entity.set_entity_god_mode(new_pet, pet_godmod.on)

        print("New pet n°"..pet_id)
    else
        menu.notify("Failed to load model!","Error",nil,0x0000FF)
    end
end)
spawn_pet.hint = "Spawn a new pet with the selected model"

local tp_pets = menu.add_feature("Teleport Pets","action",main_menu.id, function()
    for k,v in pairs(pets_ents) do
        local local_player = player.player_id()
        local player_pos = player.get_player_coords(local_player)

        request_control(v.id)
        entity.set_entity_coords_no_offset(v.id, player_pos+v3(0,0,0))
        native.call(0x1F4ED342ACEFE62D, v.id, true, false)
        system.yield(0)
    end
end)
tp_pets.hint = "Teleport all your pets to your position"

local clean_pets = menu.add_feature("Clear All (0) Pets","action",main_menu.id, function()
    clear_all(nil,true)
    menu.notify("Cleared Pets and their Blips","Clear Pets",nil,0x00AAFF)
end)
clean_pets.hint = "Delete all the pets"

menu.create_thread(function()
    while true do
        for k,v in pairs(pets_ents) do
            local local_player = player.player_id()
            local player_pos = player.get_player_coords(local_player)
            local player_ped = player.get_player_ped(local_player)

            local pet_pos = entity.get_entity_coords(v.id)

            local dist_x = math.abs(player_pos.x - pet_pos.x)
            local dist_y = math.abs(player_pos.y - pet_pos.y)
            local dist_z = math.abs(player_pos.z - pet_pos.z)

            local full_dist = dist_x+dist_y+dist_z

            if full_dist > 100 and ped.get_vehicle_ped_is_using(player_ped) == 0 then
                request_control(v.id)
                entity.set_entity_coords_no_offset(v.id, player_pos+v3(0,0,0))
                native.call(0x1F4ED342ACEFE62D, v.id, true, false)
                native.call(0xA53ED5520C07654A, v.id, player_ped, false)
            elseif full_dist > 120 and ped.get_vehicle_ped_is_using(player_ped) ~= 0 then
                request_control(v.id)
                native.call(0xDE564951F95E09ED, v.id, true, true)
                pets_ents[k].faded = true
            end

            if full_dist < 80 and v.faded == true then
                request_control(v.id)
                pets_ents[k].faded = false
                native.call(0x1F4ED342ACEFE62D, v.id, true, true)
                native.call(0xA53ED5520C07654A, v.id, player_ped, false)
            end

            if entity.is_entity_dead(v.id) then
                menu.notify("Pet "..k.." died!","Oh no!",nil,0x0000FF)
                ui.remove_blip(blips["pet_"..k])
                if del_bodies.on then
                    request_control(v.id)
                    entity.delete_entity(v.id)
                end
                pets_ents[k] = nil
            end
        end
        clean_pets.name = "Clear All ("..#pets_ents..") Pets"
        system.yield(0)
    end
end)