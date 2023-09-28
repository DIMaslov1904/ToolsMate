script_name('ToolsMate[ListFriends]')
script_author('DIMaslov1904')
script_version("0.1.0")
script_url("https://t.me/ToolsMate")
script_description [[
    Список друзей. Отоброжает онлайн и друзей рядом
]]


-------------------------
-- Зависимости
-------------------------
local not_found = {}
require 'moonloader'
local wm = require 'windows.message'
local vkeys = require 'vkeys'
local ffi = require 'ffi'
local inicfg = require 'inicfg'
local _, sampev = xpcall(require, function() table.insert(not_found, 'SAMP.Lua') end, 'samp.events')
local _, imgui = xpcall(require, function() table.insert(not_found, 'MimGui') end, 'mimgui')
local isUpdater, updater = pcall(require, ('ToolsMate[Updater]'))
local _, tmLib = xpcall(require, function()
    table.insert(not_found, 'ToolsMate_lib')
    lua_thread.create(function()
        if isUpdater then
            updater.download:run({
                name = 'tm-lib',
                path_script = getWorkingDirectory() .. '\\ToolsMate\\lib.lua',
                url_script = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/lib.lua',
            })
            while updater.download:status() ~= 'dead' do wait(1000) end
            thisScript():reload()
        end
    end)
end, 'ToolsMate.lib')

xpcall(require, function()
    table.insert(not_found, 'ToolsMate_expansion')
    lua_thread.create(function()
        if isUpdater then
            updater.download:run({
                name = 'tm-expansion',
                path_script = getWorkingDirectory() .. '\\ToolsMate\\expansion.lua',
                url_script = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/expansion.lua',
            })
            while updater.download:status() ~= 'dead' do wait(1000) end
            thisScript():reload()
        end
    end)
end, 'ToolsMate.expansion')

if #not_found > 0 then
    if not isSampLoaded() or not isSampfuncsLoaded() or not isSampAvailable() then return end
    sampAddChatMessage(
        script.this.name .. 'выгружен. Библиотеки [' ..
        table.concat(not_found, ', ') .. '] не установлены!', 0xD87093)
    thisScript():unload()
    return
end


-------------------------
-- Сокращения
-------------------------
local u8 = tmLib.u8
local new = imgui.new


-------------------------
-- Переменные
-------------------------
local renderWindow = new.bool()
local renderWindowMembers = new.bool(true)
local sizeX, sizeY = getScreenResolution()
local list_friends_file_name = c({ getWorkingDirectory(), 'config', script.this.name .. '.json' }, '/')
local list_friends = {}
local input_nickname = new.char[100]('')
local input_id = new.char[100]('')
local members = {}
local count_online = 0
local marker_data = {}
local ini_name = script.this.name .. '.ini'
local ini = inicfg.load({
    main = {
        marker = nil
    },
}, ini_name)



local function saveIni()
    inicfg.save(ini, ini_name)
end


local function saveList()
    tmLib.json(list_friends_file_name):Save(list_friends)
end

local function loadList()
    list_friends = tmLib.json(list_friends_file_name):Load(list_friends)
end

local function getValidId(msg)
    local id_str = string.match(msg, '[%d]*')
    if #id_str < 1 then return '' end
    if tonumber(id_str) > 1003 then return '1003' end
    if tonumber(id_str) < 0 then return '0' end
    return id_str
end

local function addFreand()
    local nickname = tmLib.getValueImgut(input_nickname, nil)
    local id = tmLib.getValueImgutNumber(input_id, nil)

    if id then nickname = sampGetPlayerNickname(id) end

    if #nickname > 0 then
        list_friends[nickname] = {}
        saveList()
        imgui.StrCopy(input_nickname, '')
        imgui.StrCopy(input_id, '')
    end
end

local function getItemUser(data)
    local text = b(data.nickname, ' [', data.id, ']')
    if not data.coordinates then
        text = b(text, ' [далеко]')
    end
    return text
end

local function setMarker(data)
    marker_data.coordinates = {data.coordinates.x, data.coordinates.y, data.coordinates.z}
    marker_data.nickname = data.nickname
    marker_data.marker = addSpriteBlipForContactPoint(data.coordinates.x, data.coordinates.y, data.coordinates.z, 61)
    ini.main.marker = marker_data.marker
    saveIni()
end

local function removeMarker()
    removeBlip(ini.main.marker)
    marker_data.marker = nil
    ini.main.marker = nil
    saveIni()
end

local function getMarker()
    while true do
        wait(1000)

        local user =  members[marker_data.nickname]
        if not user.id then
            removeMarker()
            return
        end
        if not marker_data.marker then
            return
        end

        if user.coordinates and tmLib.getDist2(
            user.coordinates.x, user.coordinates.y, user.coordinates.z,
            table.unpack(marker_data.coordinates)
        ) > 2 then
            removeMarker()
            setMarker(user)
        end
        if tmLib.getDist(table.unpack(marker_data.coordinates)) < 5 then
            removeMarker()
            return
        end
    end
end

imgui.OnFrame(
    function() return not isPauseMenuActive() and renderWindowMembers[0] end,
    function(self)
        self.HideCursor = true

        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.11, 0.15, 0.17, 0))
        imgui.SetNextWindowSize(imgui.ImVec2(800, 530), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        imgui.Begin(u8("FarmMembers"), renderWindowMembers,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.AlwaysAutoResize)


        for _, user in pairs(members) do
            if user.id then
                tmLib.TextColoredRGB(getItemUser(user))
            end
        end
        imgui.End()
        imgui.PopStyleColor()
    end
)

local function prepareSMS(id)
    sampSetChatInputText("/sms "..tostring(id)..' ')
    sampSetChatInputEnabled(true)
end

local function sendCoordinates(id)
    local pl_x, pl_y, pl_z = getCharCoordinates(PLAYER_PED)
    sampSendChat(b('/sms ', id, ' @GPSX=',pl_x, 'Y=',pl_y,'Z=',pl_z))
end

local is_open_popup = new.bool()

local function imguiListItem(data)
    imgui.Text(data.nickname)
    imgui.NextColumn()
    imgui.Text(data.id and tostring(data.id) or '')
    imgui.NextColumn()
    tmLib.TextColoredRGB(data.id and '{' .. data.color .. '}####' or '')
    imgui.NextColumn()
    if data.afk then
        imgui.Text(data.afk)
    end
    imgui.NextColumn()
    if data.sleep then
        imgui.Text(data.sleep)
    end
    imgui.NextColumn()
    if data.id then
        if imgui.Button('GPS##'..data.nickname, imgui.ImVec2(0, 0)) then
            imgui.OpenPopup(data.nickname)
            is_open_popup[0] = true
        end
    end

    if imgui.BeginPopupModal(data.nickname, is_open_popup, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove) then
        imgui.Text(u8 "Выберите действие");
        if imgui.Button(u8 "Показать") then
            if data.coordinates then
                setMarker(data)
                lua_thread.create(getMarker)
            else 
                sampSendChat(b('/sms ', data.id, ' @GPSGET'))
            end
            imgui.CloseCurrentPopup()
            is_open_popup[0] = false
            renderWindow[0] = false
        end
        imgui.SameLine()
        if imgui.Button(u8 "Отправить координаты") then
            sendCoordinates(data.id)
            imgui.CloseCurrentPopup()
            is_open_popup[0] = false
            renderWindow[0] = false
        end
        if imgui.Button(u8 "Закрыть") then
            imgui.CloseCurrentPopup()
            is_open_popup[0] = false
        end
        imgui.EndPopup()
    end

    imgui.NextColumn()
    if data.id then
        if imgui.Button('SMS##'..data.nickname, imgui.ImVec2(0, 0)) then
            prepareSMS(data.id)
            renderWindow[0] = false
        end
    end
    imgui.NextColumn()
    if imgui.Button('DEL##'..data.nickname, imgui.ImVec2(0, 0)) then
        list_friends[data.nickname] = nil
        saveList()
    end
    imgui.NextColumn()
    imgui.Separator()
end



imgui.OnFrame(function() return not isPauseMenuActive() and renderWindow[0] end,
    function(self)
        imgui.SetNextWindowSize(imgui.ImVec2(460, 500), imgui.Cond.Always)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        local title = b(u8'Где мои друзья? ', '[', script.this.version, ']')
        imgui.Begin(title, renderWindow,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoCollapse)

        imgui.Columns(3, 'search', false)
        imgui.SetColumnWidth(-1, 250)
        imgui.Text('Nick_Nmae')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 60)
        imgui.Text('id')
        imgui.NextColumn()
        imgui.NextColumn()


        imgui.PushItemWidth(250)
        imgui.InputText('##input_nickname', input_nickname, tmLib.sizeof(input_nickname))
        imgui.NextColumn()


        imgui.PushItemWidth(60)
        if imgui.InputText('##input_id', input_id, tmLib.sizeof(input_id)) then
            imgui.StrCopy(input_id, getValidId(ffi.string(input_id)))
        end

        imgui.NextColumn()

        if imgui.Button(u8 'Добавить') then
            addFreand()
        end
        imgui.NewLine()


        imgui.Columns(8, 'members', false)

        imgui.SetColumnWidth(-1, 150)
        imgui.Text('Nick_Nmae')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('id')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('Color')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('AFK')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('SLEEP')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('GPS')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('SMS')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 45)
        imgui.Text('DEL')
        imgui.NextColumn()
        imgui.Separator()
        for _, user in pairs(members) do
            imguiListItem(user)
        end

        if imgui.Button(u8'Удалить маркер') then
            removeMarker()
        end

        imgui.End()
        imgui.PopStyleColor()
    end
)

local function getOnlineMember(nickname)
    local id = tmLib.getIdByNick(nickname)
    local result = {
        id = id and id or nil,
        nickname = nickname,
        color = id and tmLib.getUserColor(tonumber(id)) or nil
    }
    if id then
        count_online = count_online + 1
        local isPed, ped = sampGetCharHandleBySampPlayerId(id)
        if isPed then
            local x, y, z = getCharCoordinates(ped)
            result.coordinates = {x=x, y=y, z=z}
        end
    end
    return result
end

local function checkOnlineFriends()
    count_online = 0
    for nickname in pairs(list_friends) do
        local oldMember = members[nickname] and table.copy(members[nickname]) or nil
        members[nickname] = getOnlineMember(nickname)
        if oldMember then
            if oldMember.afk then members[nickname].afk = oldMember.afk end
            if oldMember.sleep then members[nickname].sleep = oldMember.sleep end
        end
    end
end

local function checkingAFK()
    while renderWindow[0] do
        for _, data in pairs(members) do
            if data.id then
                sampSendChat('/id '.. data.id)
                wait(500)
            end
        end
       wait(3000)
    end
end



function main()
    EXPORTS.TAG_ADDONS = 'ToolsMate'
    EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
    EXPORTS.URL_GET_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BListFriends%5D.lua'
    EXPORTS.DEPENDENCIES = { tmLib.setting, ExpansionLua }

    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end

    addEventHandler("onWindowMessage", function(msg, wparam, lparam)
        if not sampIsCursorActive() then
            if (msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN) and wparam == vkeys.VK_O then
                renderWindow[0] = true
                lua_thread.create(checkingAFK)
            end
        end

        if wparam == vkeys.VK_ESCAPE and renderWindow[0] then
            consumeWindowMessage(true, true)
            renderWindow[0] = false
        end
    end)

    loadList()

    while true do
        wait(1000)
        checkOnlineFriends()
    end
end

function sampev.onServerMessage(_, text)
    if text:find('@GPSX=', 1, true) then
        local x,y,z,nickname = text:match('@GPSX=(.+)Y=(.+)Z=(.+). Отправитель: (%S+)%[')
        if nickname then
            setMarker({coordinates = {x=tonumber(x),y=tonumber(y),z=tonumber(z)}, nickname = nickname})
            lua_thread.create(getMarker)
        end
        return false
    elseif text:find('@GPSGET', 1, true) then
        sendCoordinates(text:match('Отправитель: %S+%[(%d+)'))
        return false
    end
    local nickname, id = text:match('^ (%S+)%s%[(%d+)%]')
    if nickname and id and list_friends[nickname] then
        if text:find('SLEEP|AFK', 1, true) then
            local sleep, afk = text:match('SLEEP|AFK: (%d+)|(%d+)')
            members[nickname].sleep = sleep
            members[nickname].afk = afk
        elseif text:find('SLEEP', 1, true) then
            members[nickname].sleep = text:match('SLEEP: (%d+)')
            members[nickname].afk = nil
        elseif text:find('AFK', 1, true) then
            members[nickname].afk = text:match('AFK: (%d+)')
            members[nickname].sleep = nil
        else
            members[nickname].sleep = nil
            members[nickname].afk = nil
        end
        return false
    end
end
