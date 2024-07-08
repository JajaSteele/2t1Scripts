local discordRPC = require("discordRPC")
local timer = require("timer")

local http = require('coro-http')
local base64 = require("base64")
local json = require('json')
local sp = require("serpent")

local log_lvl = {
    info = {
        name="Info",
        color="[92m",
        color_dark="[32m",
        text_color = "[97m"
    },
    warn = {
        name="Warn",
        color="[93m",
        color_dark="[33m",
        text_color = "[93m"
    },
    error = {
        name="Error",
        color="[91m",
        color_dark="[31m",
        text_color = "[33m"
    }
}

local max_width = 0

for k,v in pairs(log_lvl) do
    if v.name:len()+2 > max_width then
        max_width = v.name:len()+2
    end
end

local function log(txt, lvl, separate)
    local name_margin = max_width-(lvl.name:len()+2)
    if type(txt) == "string" then
        print('[97m'..os.date("%Y/%m/%d %H:%M:%S")..'[0m | '..lvl.color_dark..'['..lvl.color..lvl.name..lvl.color_dark..']'..string.rep(" ", name_margin)..'[0m | '..lvl.text_color..txt..'[0m')
    elseif type(txt) == "table" then
        for k,v in ipairs(txt) do
            if k == 1 then
                print('[97m'..os.date("%Y/%m/%d %H:%M:%S")..'[0m | '..lvl.color_dark..'['..lvl.color..lvl.name..lvl.color_dark..']'..string.rep(" ", name_margin)..'[0m | '..lvl.text_color..v..'[0m')
            else
                print('[90m'..'┗'..string.rep("━", os.date("%Y/%m/%d %H:%M:%S"):len()-2)..'>'..'[0m | '..lvl.color_dark..'['..lvl.color..lvl.name..lvl.color_dark..']'..string.rep(" ", name_margin)..'[0m | '..lvl.text_color..v..'[0m')
            end
        end
    end
    if separate then
        print("\x1b[19C | \x1b["..max_width.."C | ")
    end
end

local function stringSplit(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

local function decodeArg(arg)
    return querystring.urldecode(arg)
end


function discordRPC.ready(userId, username, discriminator, avatar)
    print(string.format("Discord: ready (%s, %s, %s, %s)", userId, username, discriminator, avatar))
end

function discordRPC.disconnected(errorCode, message)
    print(string.format("Discord: disconnected (%d: %s)", errorCode, message))
end

function discordRPC.errored(errorCode, message)
    print(string.format("Discord: error (%d: %s)", errorCode, message))
end

function discordRPC.joinGame(joinSecret)
    print(string.format("Discord: join (%s)", joinSecret))
end

function discordRPC.spectateGame(spectateSecret)
    print(string.format("Discord: spectate (%s)", spectateSecret))
end

function discordRPC.joinRequest(userId, username, discriminator, avatar)
    print(string.format("Discord: join request (%s, %s, %s, %s)", userId, username, discriminator, avatar))
    discordRPC.respond(userId, "yes")
end

local presence = {
    state = "Testing",
    details = "Nerd shit"
}

local app_id = "1259926413180534875"

discordRPC.initialize(app_id, true, nil)

local res_payload = "Hello!"
local res_headers = {
   {"Content-Length", tostring(#res_payload)}, -- Must always be set if a payload is returned
   {"Content-Type", "text/plain"}, -- Type of the response's payload (res_payload)
   {"Connection", "close"}, -- Whether to keep the connection alive, or close it
   code = 200,
   reason = "OK",
}

http.createServer("127.0.0.1", 1234, function (req, body)
    local update_list = {}
    log({
        "RECEIVED RPC UPDATE",
    }, log_lvl.info)

    local new_presence = json.parse(body)

    for k,v in pairs(new_presence) do
        presence[k] = v
        update_list[#update_list+1] = k.." > "..v
    end

    log(update_list, log_lvl.info)

    return res_headers, res_payload -- respond with this to every request
end)

while true do
    discordRPC.runCallbacks()
    discordRPC.updatePresence(presence)
    timer.sleep(1000)
end