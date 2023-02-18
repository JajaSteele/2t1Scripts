local sp = require("serpent")

local kick_list = {}

local autokick_features_list = {}

local show_list

local function find_kick_entry(name, scid)
    for k,v in ipairs(kick_list) do
        if v.name == (name or "") or v.scid == (scid or 0) then
            return k
        end
    end
end



local function save_list()
    local template_file = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Autokick.save.txt"
    local file1 = io.open(template_file,"w")
    file1:write(sp.dump(kick_list)) 
    file1:close()
end

local function load_list()
    local template_file = utils.get_appdata_path("PopstarDevs","").."\\2Take1Menu\\scripts\\JJS.Autokick.save.txt"
    if utils.file_exists(template_file) then
            
        local file1 = io.open(template_file,"r")
        local file_content = file1:read("*a")
        _, kick_list = sp.load(file_content)
        file1:close()
    end
end

local function update_list()
    for k,v in ipairs(autokick_features_list) do
        menu.delete_feature(v.id or 0)
    end

    autokick_features_list = {}

    for k,v in ipairs(kick_list) do
        autokick_features_list[#autokick_features_list+1] = menu.add_feature(v.name, "action_value_str", show_list.id, function(ft)
            if ft.value == 0 then
                local key = find_kick_entry(ft.name)
                table.remove(kick_list, key)
                save_list()
                menu.delete_feature(ft.id)
            end
        end)
        autokick_features_list[#autokick_features_list]:set_str_data({"Remove"})
        autokick_features_list[#autokick_features_list].hint = "Name: "..v.name.."\nSCID: "..v.scid
    end
    if #kick_list == 0 then
        autokick_features_list[#autokick_features_list+1] = menu.add_feature("List is Empty", "action", show_list.id, nil)
    end
end

show_list = menu.add_feature("JJS Autokick List", "parent", 0, update_list)

load_list()
update_list()

event.add_event_listener("player_join", function(event)
    for k,v in pairs(kick_list) do
        local curr_name = player.get_player_name(event.player)
        local curr_scid = player.get_player_scid(event.player)
        if v.name == curr_name or v.scid == curr_scid then
            network.force_remove_player(event.player)
            menu.notify("Autokicked player:\nName: "..curr_name.."\nSCID: "..curr_scid, "Autokicked Player", nil, 0xFF0000FF)
            print("JJS.Autokick: Kicked player \n Name: "..curr_name.."\n SCID: "..curr_scid)
            break
        end
    end
end)

local add_to_list = menu.add_player_feature("Add to Autokick List", "action", 0, function(ft,ply,data)
    load_list()
    kick_list[#kick_list+1] = {
        name = player.get_player_name(ply),
        scid = player.get_player_scid(ply)
    }
    save_list()
    load_list()
    update_list()
    menu.notify("Added Player to Autokick list:\nName: "..(kick_list[#kick_list].name).."\nSCID: "..(kick_list[#kick_list].scid), "Added to List", nil, 0xFF00FF00)
end)
add_to_list.hint = "Add the player to the Autokick list\nWill not kick the player out, just prevent them from rejoining."
