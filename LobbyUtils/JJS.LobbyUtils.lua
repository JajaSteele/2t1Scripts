local mx = 1920
local my = 1080

local function draw_rect(x,y, w,h, r,g,b,a)
    w = w/1920
    h = h/1080

    x = (x/1920)+(w/2)
    y = (y/1080)+(h/2)

    ui.draw_rect(x,y, w,h, r,g,b,a)
end

local function draw_text(x,y, str)
    x = (x/1920)
    y = (y/1080)

    ui.draw_text(str, v2(x,y))
end

local setting_ini = IniParser("scripts/JJS.LobbyUtils.ini")
if setting_ini:read() then
    menu.notify("Loaded Settings!", "JJS.LobbyUtils")
end

local function ini(ini, val_type, section, key, fallback)
    local exists, val = ini["get_"..val_type](ini, section, key)
    if exists then
        return val
    else
        ini["set_"..val_type](ini, section, key, fallback)
        return fallback
    end
end

local max_player = ini(setting_ini, "i", "Limiter", "limiter_max", 31)
max_player = max_player or 31
local auto_limiter_enabled = ini(setting_ini, "b", "Limiter", "auto_limiter", false)

local block_all_feat = menu.get_feature_by_hierarchy_key("online.join_timeout.block_all")

local join_leave_func = function()
    if auto_limiter_enabled then
        local player_count = player.player_count()
        if player_count >= max_player and not block_all_feat.on then
            block_all_feat.on = true
            menu.notify("Limit Reached: "..player_count.." >= "..max_player..", Block-All Enabled!", "JJS.LobbyLimiter")
        elseif block_all_feat.on then
            block_all_feat.on = false
            menu.notify("Below limit: "..player_count.." < "..max_player..", Block-All Disabled!", "JJS.LobbyLimiter")
        end
    end
end


local listener_join = event.add_event_listener("player_join", join_leave_func)
local listener_leave = event.add_event_listener("player_leave", join_leave_func)

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Lobby Utils","parent",0)


local limiter_menu = menu.add_feature("Player Count Limiter","parent",main_menu.id)

local auto_limiter = menu.add_feature("Auto-Limiter","toggle", limiter_menu.id,function(feat)
    auto_limiter_enabled = feat.on
    menu.notify("Auto-Limiter State: "..tostring(auto_limiter_enabled))
end)
auto_limiter.hint = "Automatically enables 'Online >  Join Timeout > Block-All' when the player count is above or equal to the limit"
auto_limiter.on = auto_limiter_enabled


local limit = menu.add_feature("Size Limit","autoaction_value_str", limiter_menu.id,function(feat)
    max_player = feat.value+1
    setting_ini:set_i("Limiter", "limiter_max", feat.value+1)
    join_leave_func()
end)
limit.hint = "Sets the limit for the Auto-Limiter"
local player_count_list = {}
for i1=1, 31 do
    player_count_list[#player_count_list+1] = i1
end
limit:set_str_data(player_count_list)
limit.value = max_player-1


local misc_menu = menu.add_feature("Miscellaneous","parent",main_menu.id)

local host_display = menu.add_feature("Host Display","toggle", misc_menu.id,function(feat)
    while feat.on do
        if native.call(0x83CD99A1E6061AB5):__tointeger() == 1 then
            ui.set_text_color(128,255,128,255)
            ui.set_text_scale(0.5)
            draw_text(2, 1080-55-30, "S")
        end
        
        if network.network_is_host() then
            ui.set_text_color(128,192,255,255)
            ui.set_text_scale(0.5)
            draw_text(0, 1080-55, "H")
        end

        system.yield()
    end
end)
host_display.hint = "Displays if you're Host or Script-Host on the bottom left (next to minimap)"
host_display.on =  ini(setting_ini, "b", "Misc", "host_display", true)

local god_display = menu.add_feature("Godmode Display","toggle", misc_menu.id,function(feat)
    local pl_god = menu.get_feature_by_hierarchy_key("local.player_options.god")
    local veh_god = menu.get_feature_by_hierarchy_key("local.vehicle_options.god")
    while feat.on do
        if pl_god.on then
            ui.set_text_color(255,16,64,255)
            ui.set_text_scale(0.5)
            draw_text(1, 1080-55-90-15, "P")
        end

        if veh_god.on then
            ui.set_text_color(255,16,64,255)
            ui.set_text_scale(0.5)
            draw_text(1, 1080-55-60-15, "V")
        end
        system.yield()
    end
end)
god_display.hint = "Displays if you're Godmode or Vehicle-Godmode on the bottom left (next to minimap)"
god_display.on = ini(setting_ini, "b", "Misc", "god_display", false)


local save_settings = menu.add_feature("Save Settings","action", main_menu.id,function(feat)
    setting_ini:set_b("Misc", "host_display", host_display.on)
    setting_ini:set_b("Misc", "god_display", god_display.on)
    setting_ini:set_b("Limiter", "auto_limiter", auto_limiter.on)

    setting_ini:write()
    menu.notify("Saved Settings!", "JJS.LobbyUtils")
end)