local json = require("json")

local function GET_STREET_NAME_FROM_HASH_KEY(hash)
    return native.call(0xD0EF8A959B8A4CB9, hash):__tostring(true)
end

local function get_zone_displayname(zone_id_str)
    return native.call(0x7B5280EBA9840C72, zone_id_str):__tostring(true)
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
local main_menu = menu.add_feature("Discord RPC","parent",0,function(feat)
end)

local setting_ini = IniParser("scripts/discord_rpc.ini")
if setting_ini:read() then
    menu.notify("Loaded Settings!", "Discord RPC")
end



local exists, large_text_mode = setting_ini:get_i("Config", "large_text_mode")
if large_text_mode == nil then
    large_text_mode = 1
end
local large_text_mode_list = {
    [0] = "Player Info",
    [1] = "Health/Armor/Ammo"
}

local large_text_selector = menu.add_feature("Large Text Display", "autoaction_value_str", main_menu.id,function(feat)
    large_text_mode = feat.value
    setting_ini:set_i("Config", "large_text_mode", feat.value)
    end)
large_text_selector:set_str_data(large_text_mode_list)
large_text_selector.value = large_text_mode
print("RPC Config: large_text_mode = "..large_text_selector.value)



local exists, update_frequency = setting_ini:get_i("Config", "update_frequency")
if update_frequency == nil then
    update_frequency = 1
end
local update_frequency_list = {
    [0] = "1250",
    [1] = "2500",
    [2] = "5000",
    [3] = "7500"
}

local update_frequency_selector = menu.add_feature("Update Frequency (ms)", "autoaction_value_str", main_menu.id,function(feat)
    update_frequency = feat.value
    setting_ini:set_i("Config", "update_frequency", feat.value)
end)
update_frequency_selector:set_str_data(update_frequency_list)
update_frequency_selector.value = update_frequency
print("RPC Config: update_frequency = "..update_frequency_selector.value)



local save_settings = menu.add_feature("Save Settings","action", main_menu.id,function(feat)
    setting_ini:write()
    menu.notify("Saved Settings!", "Discord RPC")
end)

menu.create_thread(function()
    while true do
        local data = {}
        local lobby_type = "Public"


        local wp = ui.get_waypoint_coord()

        local coords = player.get_player_coords(player.player_id())

        local online_status = "Online"

        if native.call(0xF3929C2379B60CCE):__tointeger() == 1 then
            lobby_type = "Solo"
        elseif native.call(0xCEF70AA5B3F89BA1):__tointeger() == 1 then
            lobby_type = "Invite-Only"
        elseif native.call(0xFBCFA2EA2E206890):__tointeger() == 1 then
            lobby_type = "Friends-Only"
        elseif native.call(0x74732C6CA90DA2B4):__tointeger() == 1 then
            lobby_type = "Crew-Only"
        elseif player.player_count() == 0 then
            lobby_type = "Story Mode"
            online_status = "Offline"
        end

        local lobby_status = "Playing "..online_status.." ("..lobby_type..")"

        data.joinSecret = tostring("SecretsDoesn'tWorkHereLol")
        data.partyId = tostring(player.get_player_scid(player.player_id()))
        data.partySize = player.player_count()
        data.partyMax = 31
        
        local veh =  ped.get_vehicle_ped_is_using(player.player_ped())
        
        if veh and veh ~= 0 then
            data.details = "Using a vehicle: "..vehicle.get_vehicle_brand(veh).." "..vehicle.get_vehicle_model(veh)
        else
            data.details = "On foot with weapon: "..weapon.get_weapon_name(ped.get_current_ped_weapon(player.player_ped()))
        end
                
        if native.call(0x10D0A8F259E93EC9):__tointeger() == 1 then
            data.details = "Currently Loading.."
        end

        data.state = lobby_status
        data.largeImageKey = "gta_logo_blurple"

        if large_text_mode == 0 then
            data.largeImageText = "Player Name: "..player.get_player_name(player.player_id()).."\nPlayer SCID: "..player.get_player_scid(player.player_id())
        elseif large_text_mode == 1 then
            data.largeImageText = "Health: "..string.format("%.1f", player.get_player_health(player.player_id())).."/"..string.format("%.1f", player.get_player_max_health(player.player_id())).."\nArmor: "..string.format("%.1f", player.get_player_armor(player.player_id()))
        end

        data.smallImageKey = "gta_blip_poi"

        data.smallImageText = (get_zone_displayname(native.call(0xCD90657D4C30E1CA, coords.x, coords.y, coords.z):__tostring(true)) or "Unknown")..", "..GET_STREET_NAME_AT_COORD(coords.x, coords.y, coords.z).name
        if wp.x ~= 16000 then
            local wp_level = get_ground(wp)
            data.smallImageText = "Waypoint: "..(get_zone_displayname(native.call(0xCD90657D4C30E1CA, wp.x, wp.y, wp_level):__tostring(true)) or "Unknown")..", "..GET_STREET_NAME_AT_COORD(wp.x, wp.y, wp_level).name
            data.smallImageKey = "gta_blip_waypoint"
        end

        web.request("http://localhost:1234/", {
            headers = {"Beep: Boop", "Content-Type: application/json"},
            method = 'post',
            data = json.encode(data),
            redirects = true,
            verify = false
        })

        system.yield(tonumber(update_frequency_list[update_frequency]))
    end
end)