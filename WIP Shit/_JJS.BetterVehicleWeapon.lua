if not menu.is_trusted_mode_enabled(1 << 2) then
    menu.notify("JJS BetterVehWp requires \"Natives\" Trust flag", "Trust Error", nil, 0x0000FF)
    menu.exit()
end

local weapon_cache = {}
local previous_weap = 0
local old_weap = 0
local new_weap = 0

local is_enabled = false

local display_weapon_name = ""
local display_weapon_timer = 0

local function get_ped_weapon(ped)
    local weapon_hash = native.ByteBuffer16()
    native.call(0x3A87E44BB9A01D54, ped, weapon_hash)
    
    return weapon_hash:__tointeger()
end

local function is_vk_down(_key)
	local key = MenuKey()
	key:push_vk(_key)
	return key:is_down_stepped()
end

menu.create_thread(function()
    while true do
        if is_enabled then
            local player = player.player_ped()
            new_weap = get_ped_weapon(player)

            if new_weap ~= old_weap and not is_vk_down(0x10) then
                previous_weap = old_weap
                old_weap = new_weap
                if weapon_cache[tostring(new_weap)] == nil then
                    weapon_cache[tostring(new_weap)] = previous_weap
                end
            end
        end
        system.yield(10)
    end
end,nil)

local is_backtab_allowed = true

menu.create_thread(function()
    while true do
        if is_enabled then
            if is_vk_down(0x10) then
                if is_vk_down(0x09) then
                    if is_backtab_allowed then
                        local player = player.player_ped()
                        local weapon_hash = get_ped_weapon(player)
                        local prev_weap = weapon_cache[tostring(weapon_hash)] or 0
                        native.call(0xADF692B254977C0C, player, prev_weap)
                        is_backtab_allowed = false

                        if prev_weap ~= 0 then
                            menu.notify("Selected previous weapon")
                            display_weapon_name = weapon.get_weapon_name(prev_weap or 0)
                            display_weapon_timer = 120
                        end
                    end
                else
                    is_backtab_allowed = true
                end
                ped.set_ped_config_flag(player.player_ped(), 48, 1)
            else
                ped.set_ped_config_flag(player.player_ped(), 48, 0)
            end
        end
        system.yield(1)
    end
end,nil)

menu.create_thread(function()
    while true do
        if ped.get_vehicle_ped_is_using(player.player_ped()) ~= 0 then
            is_enabled = true
        else
            is_enabled = false
            weapon_cache = {}
            ped.set_ped_config_flag(player.player_ped(), 48, 0)
        end
        system.yield(10)
    end
end,nil)

local function draw_text(x,y, str)
    x = (x/1920)
    y = (y/1080)

    ui.draw_text((str or ""), v2(x,y))
end

local function draw_rect(x,y, w,h, r,g,b,a)
    w = w/1920
    h = h/1080

    x = (x/1920)+(w/2)
    y = (y/1080)+(h/2)

    ui.draw_rect(x,y, w,h, r,g,b,a)
end

menu.create_thread(function()
    while true do
        if display_weapon_timer > 0 then
            draw_rect(1920/2, 1080/2, 500, 40, 32, 32, 32, 192)

            ui.set_text_color(255,255,255,255)
            ui.set_text_font(0)
            ui.set_text_scale(0.45)
            draw_text(1920/2, 1080/2, display_weapon_name)
            display_weapon_timer = display_weapon_timer-1
        end
        system.yield(0)
    end
end,nil)

local main_menu = menu.add_feature("JJS weapon wheel thing (WIP)","parent",0,function(ft)
end)

local get = menu.add_feature(".Get Selected Weap","action",main_menu.id,function(ft)
    local player = player.player_ped()
    local weapon_hash = get_ped_weapon(player)
    print("Currently Selected: "..tostring(weapon_hash))
    menu.notify("Currently Selected: "..tostring(weapon_hash))
end)
get.hint = "Prints the selected weapon to console"

local prev = menu.add_feature(".Select Previous","action",main_menu.id,function(ft)
    local player = player.player_ped()
    local weapon_hash = get_ped_weapon(player)
    local prev_weap = weapon_cache[tostring(weapon_hash)]
    native.call(0xADF692B254977C0C, player, prev_weap)

    local weapon_hash = get_ped_weapon(player)
    print("Currently Selected: "..tostring(weapon_hash))
    menu.notify("Currently Selected: "..tostring(weapon_hash))
end)
prev.hint = "Selects the previous weapon"

local clear = menu.add_feature(".Clear History","action",main_menu.id,function(ft)
    weapon_cache = {}
end)
clear.hint = "Clears the previous weapon history"

local show_icon = menu.add_feature(".Show Icon", "action", main_menu.id, function(ft)
    for i1=1, 120 do
        ft.name = ".Show Icon (true)"
        native.call(0x0B4DF1FA60C0E664, 19)
        system.yield(0)
    end
    ft.name = ".Show Icon (false)"
end)