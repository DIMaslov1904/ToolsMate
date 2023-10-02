script_name('ToolsMate[ListFriends]')
script_author('DIMaslov1904')
script_version('2.1.0')
script_url('https://t.me/ToolsMate')
script_description('Список друзей. Отоброжает онлайн и друзей рядом')


-------------------------
-- Зависимости
-------------------------
require 'moonloader'
local ffi = require 'ffi'
local vkeys = require 'vkeys'
local inicfg = require 'inicfg'
local sampev = require 'samp.events'
local imgui = require 'mimgui'
local isUpdater, updater = pcall(require, ('ToolsMate[Updater]'))

local libs = {
    ['ToolsMate.expansion'] = {
        'tm-expansion',
        '\\ToolsMate\\expansion.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/expansion.lua'
    },
    ['ToolsMate.lib'] = {
        'tm-lib',
        '\\ToolsMate\\lib.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/lib.lua'
    },
    ['ToolsMate.mimhotkey'] = {
        'tm-mimhotkey',
        '\\ToolsMate\\mimhotkey.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/mimhotkey.lua'
    },
    ['ToolsMate.ADDONS'] = {
        'tm-ADDONS',
        '\\ToolsMate\\ADDONS.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/ADDONS.lua'
    },
    ['ToolsMate.Classes.Person'] = {
        'tm-classe-Person',
        '\\ToolsMate\\Classes\\Person.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/Classes/Person.lua'
    },
    ['fAwesome6'] = {
        'fAwesome6',
        '\\lib\\fAwesome6.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/foreign/fAwesome6.lua'
    },
    ['mimgui_blur1'] = {
        'mimgui_blur_lib.dll',
        '\\lib\\mimgui_blur\\mimgui_blur_lib.dll',
        'https://github.com/DIMaslov1904/ToolsMate/raw/main/foreign/mimgui_blur/mimgui_blur_lib.dll'
    },
    ['mimgui_blur2'] = {
        'mimgui_blur\\init.lua',
        '\\lib\\mimgui_blur\\init.lua',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/foreign/mimgui_blur/init.lua'
    },
    ['no_photo_user.png'] = {
        'no_photo_user.png',
        '\\ToolsMate\\img\\no_photo_user.png',
        'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/img/no_photo_user.png'
    }
}


local not_found = false

local function downloadLibForUpdater(name)
    not_found = true
    lua_thread.create(function()
        if isUpdater then
            while updater.download:status() == 'running' do wait(1000) end
            updater.download:run({
                name = libs[name][1],
                path_script = getWorkingDirectory() .. libs[name][2],
                url_script = libs[name][3],
            })
            while updater.download:status() ~= 'dead' do wait(1000) end
            thisScript():reload()
        end
    end)
end

local isExpansion = xpcall(require, function() downloadLibForUpdater('ToolsMate.expansion') end, 'ToolsMate.expansion')

local isTmLib, tmLib = xpcall(require, function()
    not_found = true
    if isExpansion then downloadLibForUpdater('ToolsMate.lib') end
end, 'ToolsMate.lib')

local isHotkey, hotkey = xpcall(require, function()
    not_found = true
    if isExpansion then downloadLibForUpdater('ToolsMate.mimhotkey') end
end, 'ToolsMate.mimhotkey')

local isAddons, addons = xpcall(require, function()
    not_found = true
    if isExpansion then downloadLibForUpdater('ToolsMate.ADDONS') end
end, 'ToolsMate.ADDONS')

xpcall(require, function()
    not_found = true
    if isExpansion and isTmLib then downloadLibForUpdater('ToolsMate.Classes.Person') end
end, 'ToolsMate.Classes.Person')

local isFaicons, faicons = xpcall(require, function() downloadLibForUpdater('fAwesome6') end, 'fAwesome6')

local isMimgui_blur, mimgui_blur = xpcall(require, function()
    if isTmLib then
        if not tmLib.file_exists(libs['mimgui_blur1'][2]) then downloadLibForUpdater('mimgui_blur1') end
        if not tmLib.file_exists(libs['mimgui_blur2'][2]) then downloadLibForUpdater('mimgui_blur2') end
    end
end, 'mimgui_blur')

if isTmLib then
    if not tmLib.file_exists(libs['no_photo_user.png'][2]) then
        downloadLibForUpdater('no_photo_user.png')
    end
end

if not_found then
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
local renderWindowMembers = new.bool()
local renderPopupSearch = new.bool()
local input_nickname = new.char[256]()
local input_id = new.char[10]()
local updateFrequency = new.char[10]()
local sizeX, sizeY = getScreenResolution()
local SF = sizeX / 1920
local blurRadius = new.float(4.0)
local showSettings = false
local imhandle
local data_file_name = getWorkingDirectory() .. '\\ToolsMate\\data\\ToolsMate[ListFriends].json'
local ini_name = '../ToolsMate/config/' .. script.this.name .. '.ini'

tmLib.checkingPath(getWorkingDirectory()..  '\\ToolsMate\\config\\' .. script.this.name .. '.ini')

local ini = inicfg.load({
    main = {
        marker = nil,
        checkpoint = nil,
        position = '[]',
        person = nil,
        actionLifeSMS = false,
        openMenuBindKeys = '[79]',
        updateFrequency = 10
    },
}, ini_name)

local openMenuBindKeys = decodeJson(ini.main.openMenuBindKeys)


local function saveIni()
    inicfg.save(ini, ini_name)
end

-------------------------
-- Классы
-------------------------
local PersonFriend = Extended(Person)
PersonFriend.is_script = new.bool()
PersonFriend.position = {}


-- Отправка смс игроку. (автооправка, текст)
function PersonFriend:sendSMS(arg_auto_send, art_text)
    local auto_send = arg_auto_send or false
    local text = art_text or ' '
    local message = b('/sms ', self.id, text)
    if auto_send then return sampSendChat(message) end
    sampSetChatInputText(message)
    sampSetChatInputEnabled(true)
end

function PersonFriend:Update() --> nil
    Person:Update(self)
    if self.id then
        local isPed, ped = sampGetCharHandleBySampPlayerId(self.id)
        if isPed then
            local x, y, z = getCharCoordinates(ped)
            self.position = { x = x, y = y, z = z }
        else
            self.position = {}
        end
    end
end

local PersonFriendList = Extended(PersonList)
PersonFriendList.child = PersonFriend

local personFriendList = PersonFriendList:new() -- Основное хранилище друзей


function PersonFriendList:AddPerson(arg)
    if not arg then return { status = 'error', message = 'Не передано имя/id!' } end
    local name = arg
    if type(arg) == 'number' then
        if not sampIsPlayerConnected(arg) then return { status = 'error', message = 'По данному id игрок не найден!' } end
        name = sampGetPlayerNickname(arg)
    end
    self.count = self.count + 1
    local person = self.child:new(name)
    person.is_script = new.bool()
    person.sorting = self.count
    table.insert(self.list, person)
    return { status = 'ok' }
end

-- Инициализация списка друзей
function PersonFriendList:Initial(members)
    self.count = 0
    for nickname, data in pairs(members) do
        local person = self.child:new(nickname)
        person.is_script = new.bool(data.is_script or false)
        person.sorting = data.sorting
        table.insert(personFriendList.list, person)
        self.count = self.count + 1
    end
    return { status = 'ok' }
end

function PersonFriendList:GetSaveList()
    local memebers = {}
    for _, data in pairs(self.list) do
        memebers[data.name] = {
            sorting = data.sorting or 0,
            is_script = data.is_script[0] or false
        }
    end
    return memebers
end

local Navigation = {}
function Navigation:new()
    local obj = {
        marker = ini.main.marker,
        checkpoint = ini.main.checkpoint,
        position = decodeJson(ini.main.position),
        person = nil,
        actionLifeSMS = ini.main.actionLifeSMS
    }

    function obj:Ini()
        if ini.main.person then
            self.person = personFriendList:GetPerson(ini.main.person)
        end
        if self.marker then
            self:LifeMarker()
        end
        if self.actionLifeSMS then
            self:LifeSMS()
        end
    end

    setmetatable(obj, self)
    self.__index = self; return obj
end

function Navigation:Access(person)
    if not person.isOnline then return false end
    if not person.is_script[0] and (not person.position or not person.position.x) then return false end
    return true
end

function Navigation:UpdateIni()
    ini.main.marker = self.marker
    ini.main.checkpoint = self.checkpoint
    ini.main.position = encodeJson(self.position)
    ini.main.person = self.person and self.person.name or nil
    ini.main.actionLifeSMS = self.actionLifeSMS or false
    saveIni()
end

function Navigation:RemoveMarker(isSMS)
    if self.marker then deleteCheckpoint(self.marker) end
    if self.checkpoint then removeBlip(self.checkpoint) end
    self.marker = nil
    self.checkpoint = nil
    self.person = nil
    self.position = {}
    if not isSMS then
        self.actionLifeSMS = false
    end
    self:UpdateIni()
end

function Navigation:CheckMarker()
    if self.person and not self.person.isOnline then return true end -- если офф - вырубаем
    local x1, y1, z1 = getCharCoordinates(PLAYER_PED)
    if self.person and self.person.position and self.person.position.x then
        local dist = getDistanceBetweenCoords3d(self.position.x, self.position.y, self.position.z, self.person.position
            .x, self.person.position.y, self.person.position.z)
        if dist > 3 then
            self:SetMarker(self.person.position.x, self.person.position.y, self.person.position.z, self.person)
        end
    elseif not self.person or not self.person.is_script[0] then --Удалаяем маркер
        self:RemoveMarker()
    elseif not self.actionLifeSMS then                          -- пеерекдючаемся на проверку по смс
        local l_perosn = self.person
        lua_thread.create(function()
            wait(2000)
            self.person = l_perosn
            self:LifeSMS()
        end)
        return true
    end
    return getDistanceBetweenCoords3d(self.position.x, self.position.y, self.position.z, x1, y1, z1) < 3 or
        not doesBlipExist(self.checkpoint)
end

function Navigation:LifeMarker()
    lua_thread.create(function()
        repeat wait(0) until self:CheckMarker()
        self:RemoveMarker()
        addOneOffSound(0, 0, 0, 1149)
    end)
end

function Navigation:SetMarker(x, y, z, person, isSMS)
    self:RemoveMarker(isSMS)
    self.person = person
    self.position = { x = x, y = y, z = z }
    self.checkpoint = addBlipForCoord(x, y, z)
    self.marker = createCheckpoint(2, x, y, z, 1, 1, 1, 3)
    changeBlipColour(self.checkpoint, 0xFFFFFFFF)
    self:UpdateIni()
    self:LifeMarker()
end

function Navigation:GetGPS(person)
    person:Update()
    if person.position and person.position.x then
        self:SetMarker(person.position.x, person.position.y, person.position.z, person)
    elseif person.is_script[0] then
        self.person = person
        self:LifeSMS()
    end
end

function Navigation:GetPositionSMS()
    if self.person then
        self.person:sendSMS(true, ' @GPSGET')
    end
end

function Navigation:SendPositionSMS(name, id)
    local pl_x, pl_y, pl_z = getCharCoordinates(PLAYER_PED)
    sampSendChat(b('/sms ', id, ' @GPSX=', pl_x, 'Y=', pl_y, 'Z=', pl_z))
    sampAddChatMessage('Данные о местоположении отправлены: {0ABAB5}' .. name, -1)
end

function Navigation:CheckSMS(message)
    if message:find('@GPSGET', 1, true) and message:find('Отправитель', 1, true) then
        local name, id = message:match('Отправитель: (%S+)%[(%d+)')
        self:SendPositionSMS(name, id)
    end
    if message:find('@GPSX=', 1, true) and message:find('Отправитель', 1, true) then
        local x, y, z = message:match('@GPSX=(.+)Y=(.+)Z=(.+)')
        self:SetMarker(x, y, z, self.person, true)
    end
    return false
end

function Navigation:LifeSMS()
    self.actionLifeSMS = true
    lua_thread.create(function()
        repeat
            self:GetPositionSMS()
            wait(ini.main.updateFrequency * 1000)
        until self.person and self.person.position and self.person.position.x
        self.actionLifeSMS = false
        self:GetGPS(self.person)
    end)
end

local navigation = Navigation:new()

local function saveList()
    tmLib.json(data_file_name):Save(personFriendList:GetSaveList())
end

local function loadList()
    local members = tmLib.json(data_file_name):Load({})
    PersonFriendList:Initial(members)
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

    imgui.StrCopy(input_nickname, '')
    imgui.StrCopy(input_id, '')

    if #nickname > 0 or id then
        personFriendList:AddPerson(id and id or nickname)
        renderPopupSearch[0] = false
        saveList()
    end
end


local fontSize
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    fontSize = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 14.0 * SF, _, glyph_ranges)

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14 * SF, config,
        iconRanges)


    if doesFileExist(getWorkingDirectory() .. '\\ToolsMate\\img\\no_photo_user.png') then
        imhandle = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\ToolsMate\\img\\no_photo_user.png')
    end


    local mc = imgui.ColorConvertU32ToFloat4(0x0ABAB500)
    imgui.SwitchContext()
    local style                      = imgui.GetStyle()
    local colors                     = style.Colors
    local clr                        = imgui.Col
    local ImVec4                     = imgui.ImVec4
    local ImVec2                     = imgui.ImVec2

    style.WindowPadding              = ImVec2(15 * SF, 15 * SF)
    style.WindowRounding             = 15 * SF
    style.ChildRounding              = 15 * SF
    style.FramePadding               = ImVec2(10 * SF, 10 * SF)
    style.FrameRounding              = 6 * SF
    style.ItemSpacing                = ImVec2(10 * SF, 5 * SF)
    style.ItemInnerSpacing           = ImVec2(10 * SF, 3 * SF)
    style.IndentSpacing              = 18 * SF
    style.ScrollbarSize              = 11 * SF
    style.ScrollbarRounding          = 11 * SF
    style.GrabMinSize                = 13 * SF
    style.GrabRounding               = 7 * SF
    style.TabRounding                = 6 * SF
    style.WindowTitleAlign           = ImVec2(0.5, 0.5)
    style.ButtonTextAlign            = ImVec2(0.5, 0.5)

    colors[clr.Text]                 = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]         = ImVec4(0.80, 0.80, 0.80, 0.50)
    colors[clr.WindowBg]             = ImVec4(0.09, 0.09, 0.09, 0.90)
    colors[clr.ChildBg]              = ImVec4(0.09, 0.09, 0.09, 0.70)
    colors[clr.PopupBg]              = ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[clr.Border]               = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.BorderShadow]         = ImVec4(0.00, 0.60, 0.00, 0.00)
    colors[clr.FrameBg]              = ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[clr.FrameBgHovered]       = ImVec4(mc.x, mc.y, mc.z, 0.50)
    colors[clr.FrameBgActive]        = ImVec4(mc.x, mc.y, mc.z, 0.80)
    colors[clr.TitleBg]              = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.TitleBgActive]        = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.TitleBgCollapsed]     = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.MenuBarBg]            = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ScrollbarBg]          = ImVec4(mc.x, mc.y, mc.z, 0.50)
    colors[clr.ScrollbarGrab]        = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.ScrollbarGrabHovered] = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.ScrollbarGrabActive]  = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.CheckMark]            = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.SliderGrab]           = ImVec4(mc.x, mc.y, mc.z, 0.70)
    colors[clr.SliderGrabActive]     = ImVec4(mc.x, mc.y, mc.z, 1.00)
    colors[clr.Button]               = ImVec4(mc.x, mc.y, mc.z, 0.50)
    colors[clr.ButtonHovered]        = ImVec4(mc.x, mc.y, mc.z, 0.80)
    colors[clr.ButtonActive]         = ImVec4(mc.x, mc.y, mc.z, 0.90)
    colors[clr.Header]               = ImVec4(1.00, 1.00, 1.00, 0.20)
    colors[clr.HeaderHovered]        = ImVec4(1.00, 1.00, 1.00, 0.20)
    colors[clr.HeaderActive]         = ImVec4(1.00, 1.00, 1.00, 0.30)
    colors[clr.TextSelectedBg]       = ImVec4(mc.x, mc.y, mc.z, 0.90)
end)



local function imguiPersonItem(person)
    imgui.BeginChild('Person_' .. person.name, imgui.ImVec2(400 * SF - 30 * SF, 75 * SF), true,
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
    local hovered = imgui.IsWindowHovered()
    local dl = imgui.GetWindowDrawList()
    imgui.SetCursorPos(imgui.ImVec2(40 * SF, 37 * SF))
    local p = imgui.GetCursorScreenPos()

    dl:AddCircleFilled(p, 30 * SF, tmLib.parseHexColorToU32(person.clist), 23)

    imgui.SetCursorPos(imgui.ImVec2(13 * SF, 10 * SF))
    imgui.Image(imhandle, imgui.ImVec2(54 * SF, 54 * SF))

    imgui.SetCursorPos(imgui.ImVec2(80 * SF, 15 * SF))
    imgui.Text(person.name)


    if person.isOnline then
        imgui.SetCursorPos(imgui.ImVec2(80 * SF, 45 * SF))
        tmLib.TextColoredRGB('{888888}ID')
        imgui.SameLine()
        imgui.Text(tostring(person.id))
    end

    imgui.SetCursorPos(imgui.ImVec2(150 * SF, 45 * SF))
    imgui.Text(faicons('USER_GROUP'))
    addons.Hint('##hint_is_script1'..person.name, u8'Наличие у игрока данного скрипта.\nНеобходимо для правильной работы маркера')
    imgui.SameLine()
    imgui.SetCursorPosY(40 * SF)
    if addons.ToggleButton('##Person_isScript_' .. person.name, person.is_script) then
        saveList()
    end
    addons.Hint('##hint_is_script'..person.name, u8'Наличие у игрока данного скрипта.\nНеобходимо для правильной работы маркера')


    imgui.SetCursorPos(imgui.ImVec2(230 * SF, 30 * SF))

    if addons.StateButton(navigation:Access(person), faicons('LOCATION_DOT'), imgui.ImVec2(35 * SF, 35 * SF)) then
        navigation:GetGPS(person)
    end
    addons.Hint('##hint_gps'..person.name, u8'Показать положение друга'..(not person.isOnline and u8'\n(Оффлай)' or not navigation:Access(person) and u8'\n(Далеко)' or ''))

    imgui.SameLine()

    if addons.StateButton(person.isOnline, faicons('COMMENT'), imgui.ImVec2(35 * SF, 35 * SF)) then
        person:sendSMS()
    end
    addons.Hint('##hint_sms'..person.name, u8'Заготовка для отправки смс'..(not person.isOnline and u8'\n(Оффлай)' or ''))
    imgui.SameLine()
    if imgui.Button(faicons('TRASH'), imgui.ImVec2(35 * SF, 35 * SF)) then
        personFriendList:removePerson(person.name)
        saveList()
    end

    if hovered then
        imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(0, 0))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
        imgui.SetCursorPos(imgui.ImVec2(305 * SF, 5 * SF))
        addons.StateButton(person.sorting ~= 1, faicons('UP'), imgui.ImVec2(20 * SF, 20 * SF))
        if imgui.IsItemClicked() then
            person.sorting, personFriendList.list[person.sorting - 1].sorting = person.sorting - 1, person.sorting
            personFriendList:SortingList()
            saveList()
        end
        addons.Hint('##hint_up'..person.name, u8'Поднять друга в списке')

        imgui.SameLine()
        addons.StateButton(person.sorting ~= personFriendList.count, faicons('DOWN'), imgui.ImVec2(20 * SF, 20 * SF))
        if imgui.IsItemClicked() then
            person.sorting, personFriendList.list[person.sorting + 1].sorting = person.sorting + 1, person.sorting
            personFriendList:SortingList()
            saveList()
        end
        addons.Hint('##hint_down'..person.name, u8'Отпустить друга в списке')
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)
    end
    imgui.EndChild()
end

-- Окно добавления друга
local function screenAddFriends()
    imgui.SetNextWindowSize(imgui.ImVec2(412 * SF, 95 * SF), imgui.Cond.FirstUseEver)
    if imgui.BeginPopupModal('seach_popup', renderPopupSearch, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove) then
        imgui.Columns(4, 'search', false)
        imgui.SetColumnWidth(-1, 200 * SF)
        imgui.Text('Nick_Nmae')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 60 * SF)
        imgui.Text('id')
        imgui.NextColumn()
        imgui.SetColumnWidth(-1, 87 * SF)
        imgui.NextColumn()
        imgui.NextColumn()
        imgui.PushItemWidth(190 * SF)
        imgui.InputText('##input_nickname', input_nickname, tmLib.sizeof(input_nickname))
        imgui.NextColumn()


        imgui.PushItemWidth(50 * SF)
        if imgui.InputText('##input_id', input_id, tmLib.sizeof(input_id)) then
            imgui.StrCopy(input_id, getValidId(ffi.string(input_id)))
        end

        imgui.NextColumn()

        if imgui.Button(u8 'Добавить') then
            addFreand()
        end
        imgui.NextColumn()

        if imgui.Button(faicons('XMARK'), imgui.ImVec2(35 * SF, 35 * SF)) then
            renderPopupSearch[0] = false
        end
    end
end


-- Основное окно
local function screenMain()
    if imgui.Button(faicons('USER_PLUS') .. u8 ' Добавить друга') then
        renderPopupSearch[0] = true
        imgui.OpenPopup('seach_popup')
    end
    imgui.SameLine()
    if navigation.marker or navigation.actionLifeSMS then
        imgui.SetCursorPosX(500 * SF - 250 * SF)
        if imgui.Button(faicons('LOCATION_DOT_SLASH')) then
            navigation:RemoveMarker()
        end
        imgui.SameLine()
    end
    addons.Hint('##LOCATION_DOT_SLASH', u8'Убрать маркер друга')
    imgui.SetCursorPosX(500 * SF - 200 * SF)
    if imgui.Button(faicons('GEAR')) then
        showSettings = true
    end
    imgui.SameLine()
    imgui.SetCursorPosX(500 * SF - 150 * SF)
    if imgui.Button(faicons('XMARK'), imgui.ImVec2(35 * SF, 35 * SF)) then
        renderWindow[0] = false
    end

    imgui.SetCursorPosX(320 * SF)
    tmLib.TextColoredRGB(b('{888888}online ', personFriendList.onlineCount, '/', personFriendList.count))

    for _, person in pairs(personFriendList.list) do
        imguiPersonItem(person)
    end

    screenAddFriends()
end

-- Окно настроек
local function screenSettings()
    imgui.SetCursorPosX(500 * SF - 200 * SF)
    if imgui.Button(faicons('LEFT_LONG')) then
        showSettings = false
    end
    imgui.SameLine()
    imgui.SetCursorPosX(500 * SF - 150 * SF)
    if imgui.Button(faicons('XMARK'), imgui.ImVec2(35 * SF, 35 * SF)) then
        renderWindow[0] = false
    end

    imgui.SetCursorPosY(65 * SF)
    imgui.Text(u8 'Сочетание для открытия меню')
    imgui.SameLine()
    imgui.SetCursorPos(imgui.ImVec2(230 * SF, 55 * SF))
    local newOpenMenuBindKeys = hotkey.KeyEditor('openMenuBind')
    if newOpenMenuBindKeys then
        ini.main.openMenuBindKeys = encodeJson(newOpenMenuBindKeys)
        saveIni()
    end

    imgui.SetCursorPosY(105 * SF)
    imgui.Text(u8 'Частота обновления по смс (сек)')
    imgui.SameLine()


    imgui.SetCursorPos(imgui.ImVec2(230 * SF, 95 * SF))
    imgui.PushItemWidth(50 * SF)
    if imgui.InputText("##updateFrequency", updateFrequency, tmLib.sizeof(updateFrequency)) then
        local updateFrequency_str = string.match(ffi.string(updateFrequency), '[%d]*')
        imgui.StrCopy(updateFrequency, updateFrequency_str)
        if #updateFrequency_str < 1 then
            ini.main.updateFrequency = 10
        else
            ini.main.updateFrequency = tonumber(updateFrequency_str)
        end
        saveIni()
    end
end




local imgui_menu = imgui.OnFrame(
    function() return not isPauseMenuActive() and renderWindow[0] end,
    function(self)
        imgui.PushFont(fontSize)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(400 * SF, 500 * SF), imgui.Cond.Always)
        imgui.Begin('Okno', renderWindow,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar)
        mimgui_blur.apply(imgui.GetWindowDrawList(), blurRadius[0])
        if showSettings then
            screenSettings()
        else
            screenMain()
        end
        imgui.End()
        imgui.PopFont()
    end
)

local imgui_online_members = imgui.OnFrame(
    function() return not isPauseMenuActive() and renderWindowMembers[0] end,
    function(self)
        self.HideCursor = true
        imgui.PushFont(fontSize)
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
        imgui.SetNextWindowPos(imgui.ImVec2(100, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        imgui.Begin("FriedsMembers", renderWindowMembers,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.AlwaysAutoResize)

        for _, person in pairs(personFriendList.listOnline) do
            local isNearby = person.position and person.position.x
            tmLib.TextColoredRGB(b(person.name, ' [', person.id, ']'))
            if isNearby then
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.10, 0.73, 0.71, 1.0), faicons('LOCATION_CROSSHAIRS'))
            end
        end
        imgui.End()
        imgui.PopStyleColor(2)
        imgui.PopFont()
    end
)



local toggleMenu = function()
    if not sampIsCursorActive() or renderWindow[0] then
        renderWindow[0] = not renderWindow[0]
    end
end


local function run()
    loadList()
    renderWindowMembers[0] = true

    addEventHandler("onWindowMessage", function(msg, wparam, lparam)
        if wparam == vkeys.VK_ESCAPE and renderWindow[0] then
            consumeWindowMessage(true, true)
            renderWindow[0] = false
        end
    end)

    hotkey.RegisterCallback('openMenuBind', openMenuBindKeys, toggleMenu)
    navigation:Ini()
    personFriendList:SortingList()
    imgui.StrCopy(updateFrequency, tostring(ini.main.updateFrequency))
end

function main()
    EXPORTS.TAG_ADDONS = 'ToolsMate'
    EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
    EXPORTS.URL_GET_UPDATE =
    'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BListFriends%5D.lua'
    EXPORTS.DEPENDENCIES = { tmLib.setting, ExpansionLua, hotkey.setting, addons.setting }

    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    repeat wait(0) until sampIsLocalPlayerSpawned()

    run()

    while true do
        wait(1000)
        personFriendList:Update()
    end
end

function sampev.onServerMessage(_, text)
    if text:find('@GPS', 1, true) then
        return navigation:CheckSMS(text)
    end
end
