if not menu.is_trusted_mode_enabled(1 << 3) then
    menu.notify("JJS Translator requires \"HTTP\" Trust flag", "Trust Error", nil, 0x0000FF)
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
        local url = "https://raw.githubusercontent.com/JJS-Laboratories/2t1Scripts/main/Translator/JJS.Translator.lua"
        local code, body, headers = web.request(url)

        local path = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Translator.lua"

        local file1 = io.open(path, "r")
        curr_file = file1:read("*a")
        file1:close()

        if curr_file ~= body and code == 200 and body:len() > 0 then
            menu.notify("Update detected!\nPress 'Enter' to download or 'Backspace' to cancel\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Translator",nil,0x00AAFF)
            choice = question(201, 202)
            if choice then
                menu.notify("Downloaded! Please reload the script","JJS Translator",nil,0x00FF00)
                local file2 = io.open(path, "w")
                file2:write(body)
                file2:close()
                menu.exit()
            else
                menu.notify("Update Cancelled","JJS Translator",nil,0x0000FF)
            end
        else
            menu.notify("No update detected\n#FF00AAFF#To disable updates, disable Trusted HTTP","JJS Translator",nil,0xFF00FF)
            print("Update HTTP for JJS Translator: "..code)
        end
    end)
end

local json = require("json")

local active_texts = {}

local target_lang = "en"

local translator_visible = 300

local function RGBAToInt(R, G, B, A) --proddy made this - thank you
    A = A or 255
    return ((R&0x0ff)<<0x00)|((G&0x0ff)<<0x08)|((B&0x0ff)<<0x10)|((A&0x0ff)<<0x18)
end

local function addtext(text,coords)
    translator_visible = 600
    table.insert(active_texts,1,{
        pos={
            x=coords.x,
            y=coords.y
        },
        text=text
    })
end

local function removetext(text)
    for k,v in pairs(active_texts) do
        if v.text == text then
            active_texts[k] = nil
        end
        system.yield(0)
    end
end

local main_menu = menu.add_feature("#FFFFC64D#J#FFFFD375#J#FFFFE1A1#S #FFFFF8EB#Translator", "parent", 0)
local translator = menu.add_feature("Translator", "toggle", main_menu.id, function(feat)
    if feat.on then
        addtext("Enabled Translator",v2(1-0.03, (0.0550*5)-0.59))
    else
        addtext("Disabled Translator",v2(1-0.03, (0.0550*5)-0.59))
        system.yield(3000)
        active_texts = {}
    end
end)

local set_lang = menu.add_feature("Language: [en]", "action", main_menu.id, function(feat)
    local status = 1
    while status == 1 do
        status, target_lang = input.get("Target Language: (Example: en,fr,ru)","",2,1)
        system.yield(0)
    end
    feat.name = "Language: ["..target_lang.."]"
end)

local ignore_self = menu.add_feature("Ignore Self", "toggle", main_menu.id)
ignore_self.on = true


local send_lang = "en"

local send_menu = menu.add_feature("Send Msg", "parent",main_menu.id)

local msg_lang = menu.add_feature("Msg Language: [en]", "action", send_menu.id, function(feat)
    local status = 1
    while status == 1 do
        status, send_lang = input.get("Language: (Example: en,fr,ru)","",2,1)
        system.yield(0)
    end
    feat.name = "Msg Language: ["..send_lang.."]"
end)

local msg_org_toggle = menu.add_feature("Org/Team only", "toggle", send_menu.id)

local send_msg = menu.add_feature("Send Message", "action", send_menu.id, function(feat)
    local status = 1
    local msg_raw = ""
    while status == 1 do
        status, msg_raw = input.get("Message to Translate:","",250,0)
        system.yield(0)
    end
    local json_body = json.encode({
        source = "auto",
        text = msg_raw,
        target = send_lang,
    })
    local res_code, res_body, res_headers = web.request("https://deep-translator-api.azurewebsites.net/google/", {
        method = "POST",
        data = json_body,
        headers = {"Content-Type: application/json"},
    })
    if res_code == 200 then
        local res_table = json.decode(res_body)
        if res_table.translation ~= nil and res_table.translation ~= "" then
            network.send_chat_message(res_table.translation, msg_org_toggle.on)
        end
    else
        print("ERROR "..res_code)
    end
end)



event.add_event_listener("chat", function(msg)
    if translator.on then
        if msg.body:len() > 0 and (msg.sender ~= player.player_id() or ignore_self.on == false) then
            local json_body = json.encode({
                source = "auto",
                text = msg.body,
                target = target_lang,
            })
            local res_code, res_body, res_headers = web.request("https://deep-translator-api.azurewebsites.net/google/", {
                method = "POST",
                data = json_body,
                headers = {"Content-Type: application/json"},
            })
            if res_code == 200 then
                local res_table = json.decode(res_body)
                local username = player.get_player_name(msg.sender)
                if res_table.translation ~= nil and res_table.translation ~= "" then
                    addtext(username..": "..res_table.translation.."  ",v2(1-0.03, (0.0550*5)-0.59))
                end
            else
                print("ERROR "..res_code)
            end
        end
    end
end)

menu.create_thread(function()
    while true do
        if #active_texts > 0 and translator_visible > 0 then
            for i1=1, #active_texts do
                if i1 > 5 then
                    active_texts[#active_texts] = nil
                else
                    local curr = active_texts[i1]
                    local text_pos = v2(curr.pos.x,curr.pos.y) + v2(0, 0.0550*(i1-1))
                    local shadow_pos = text_pos + v2(0.0025, -0.0025)
                    scriptdraw.draw_text(curr.text, shadow_pos, shadow_pos, 0.8, RGBAToInt(0,0,0,200), (1<<4), nil) --Shadowy
                    scriptdraw.draw_text(curr.text, text_pos, text_pos, 0.8, 0xFFFFFFFF, (1<<4), nil) --White text
                end
            end
        end
        system.yield(0)
    end
end)

menu.create_thread(function()
    while true do
        if translator_visible > 0 then
            translator_visible = translator_visible-1
        end
        if controls.is_control_pressed(0,245) or controls.is_control_pressed(0,246) then
            translator_visible = 600
        end
        system.yield(0)
    end
end)