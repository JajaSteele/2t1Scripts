local ini = require("lib/lip")
local data = ini.load("2Take1Menu.ini")
for k,v in pairs(data["Keys"]) do
    print(k.." > "..v)
end

local drawui_thread = 0

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

local function is_vk_down(_key)
	local key = MenuKey()
	key:push_vk(_key)
	return key:is_down_stepped()
end

local function clamp(x,min,max)
    if x < min then
        return min
    elseif x > max then
        return max
    else
        return x
    end
end

local floor = math.floor

local mode = 0
local draw_order = {}
local fetch_thread = 0
local scroll = 0
local max_drawn = 0

local switch_mode = true

local main_menu = menu.add_feature("Keybind Viewer", "parent", 0)

local function update_controls()
    menu.delete_thread(fetch_thread)
    fetch_thread = menu.create_thread(function()
        draw_order = {}
        for k,v in pairs(data["Keys"]) do
            local feat = menu.get_feature_by_hierarchy_key(k)
            if ((mode == 0 and (menu.get_feature_by_hierarchy_key(k) or {name=false}).name) or (mode == 1 and not (menu.get_feature_by_hierarchy_key(k) or {name=false}).name)) and v ~= "none" then
                draw_order[#draw_order+1] = {
                    action = (menu.get_feature_by_hierarchy_key(k) or {name=false}).name or k,
                    keybind = v:gsub("NOMOD%+",""):gsub("%+", " + "),
                    parent = ((feat or {}).parent or {}).name or "?"
                }
            end
        end
        local function sort_func(a,b)
            return a.action < b.action
        end

        table.sort(draw_order, sort_func)
    end)
end

update_controls()

local toggle_controls = menu.add_feature("Enable", "toggle", main_menu.id, function(ft)
    if ft.on then
        menu.notify("Keybind Viewer On, Press 'Alt GR' to open")
        drawui_thread = menu.create_thread(function()
            local alphamult = 0
            while true do
                if is_vk_down(0xA5) or alphamult > 0 then
                    print(max_drawn)
                    draw_rect(50,50, mx-100,my-100, 0,0,0,math.ceil(225 * alphamult))
                    local inc = 0
                    for i1=1, #draw_order do
                        local data1 = draw_order[i1+math.floor(scroll)]
                        if data1 == nil then
                            break
                        end
                        local ypos = 55+(35*inc)
                        if ypos < my-80 then
                            if inc % 4 < 2 then
                                draw_rect(60, ypos+3, mx-120, 35, 42,42,42,math.ceil(92 * alphamult))
                            end
                            
                            ui.set_text_color(255,255,255,math.ceil(255 * alphamult))
                            ui.set_text_font(0)
                            ui.set_text_scale(0.45)
                            draw_text(60, ypos, data1.parent)

                            ui.set_text_color(255,255,255,math.ceil(255 * alphamult))
                            ui.set_text_font(0)
                            ui.set_text_scale(0.45)
                            draw_text(400, ypos, data1.action)

                            ui.set_text_color(255,255,255,math.ceil(255 * alphamult))
                            ui.set_text_font(0)
                            ui.set_text_scale(0.45)
                            draw_text(850, ypos, data1.keybind)

                            draw_rect(70, ypos+19, mx-140, 3, 64,64,64,math.ceil(92 * alphamult))
                            if max_drawn < inc then
                                max_drawn = inc
                            end
                        end
                        inc=inc+1
                    end
                    draw_rect(50, 14, mx-100, 35, 0,0,0,math.ceil(255 * alphamult))
                    local title_r, title_g, title_b = 0,0,0
                    if mode == 0 then
                        title_r, title_g, title_b = 160,255,142
                    elseif mode == 1 then
                        title_r, title_g, title_b = 255,142,160
                    end
                    ui.set_text_color(title_r,title_g,title_b,math.ceil(255 * alphamult))
                    ui.set_text_font(1)
                    ui.set_text_scale(0.6)
                    draw_text(60+15, 13, "PARENT")

                    ui.set_text_color(title_r,title_g,title_b,math.ceil(255 * alphamult))
                    ui.set_text_font(1)
                    ui.set_text_scale(0.6)
                    draw_text(400+15, 13, "ACTION")

                    ui.set_text_color(title_r,title_g,title_b,math.ceil(255 * alphamult))
                    ui.set_text_font(1)
                    ui.set_text_scale(0.6)
                    draw_text(850+15, 13, "KEYBIND")

                    draw_rect(50, my-49, mx-100, 35, 0,0,0,math.ceil(255 * alphamult))

                    ui.set_text_color(floor(title_r/2),floor(title_g/2),floor(title_b/2),math.ceil(255 * alphamult))
                    ui.set_text_font(1)
                    ui.set_text_scale(0.5)
                    draw_text(60, my-47, "RSHIFT/RCTRL = Scroll")

                    ui.set_text_color(floor(title_r/2),floor(title_g/2),floor(title_b/2),math.ceil(255 * alphamult))
                    ui.set_text_font(1)
                    ui.set_text_scale(0.5)
                    draw_text(500, my-47, "BACKSPACE = Switch Tab")

                    ui.set_text_color(title_r,title_g,title_b,math.ceil(255 * alphamult))
                    ui.set_text_font(1)
                    ui.set_text_scale(0.6)
                    if mode == 0 then
                        draw_text(mx-345, my-49, "CUSTOM KEYBINDS TAB")
                    else
                        draw_text(mx-280, my-49, "2T1 KEYBINDS TAB")
                    end
                end
                if is_vk_down(0xA5) then
                    if is_vk_down(0x08) then
                        if switch_mode then
                            if mode == 0 then
                                mode = 1
                            else
                                mode = 0
                            end
                            update_controls()
                            switch_mode = false
                        end
                    else
                        switch_mode = true
                    end

                    if is_vk_down(0xA1) then
                        scroll = clamp(scroll-0.25,0,#draw_order-max_drawn)
                    elseif is_vk_down(0xA3) then
                        scroll = clamp(scroll+0.25,0,#draw_order-max_drawn)
                    end
                    alphamult = clamp(alphamult+0.04,0,1)
                else
                    alphamult = clamp(alphamult-0.1,0,1)
                end
                system.yield(0)
            end
        end)
    else
        menu.delete_thread(drawui_thread or 0)
        menu.notify("Keybind Viewer Off")
    end
end)

toggle_controls.on = true