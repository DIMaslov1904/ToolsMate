-- Зависимости
require 'ToolsMate.expansion'
local ffi        = require 'ffi'
local imgui      = require 'mimgui'
local encoding   = require 'encoding'
encoding.default = 'CP1251'


local lib = {
    u8 = encoding.UTF8,
    sizeof = ffi.sizeof,
    setting = {
        name = 'tm-lib',
        url_script = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/lib.lua',
        urp_version = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json',
        version = "0.2.1",
        path_script = getWorkingDirectory() .. '\\ToolsMate\\lib.lua',
        tag = 'ToolsMate'
    }
}


------
-- Работа с числами
------
function lib.round(num, idp)
    local mult = 10 ^ (idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

function lib.separatorNumber(number)
    local str = tostring(number)
    local result = ''

    for i = 1, #str, 1 do
        if (#str - i - 2) % 3 == 0 and #result > 0 then
            result = result .. '.'
        end
        result = result .. string.sub(str, i, i)
    end
    return result
end

------
-- Работа с датами
------
lib.datetime = Def(function () return os.time(utc) + 3 * 3600 end)
lib.datetime_str = tostring( os.date("!%H:%M:%S %d.%m.%Y", lib.datetime()))

lib.datetime_pd = string.gsub(lib.datetime_str, "%d+:%d+", "05:02")

function lib.difftime(reference)
    local days = math.floor(os.difftime(os.time(), reference) / (24 * 60 * 60))
    local hour = math.floor(os.difftime(os.time(), reference) / (60 * 60)) % 60
    local min = math.floor(os.difftime(os.time(), reference) / (60)) % 60
    local sec = os.difftime(os.time(), reference) % 60
    local result = min .. ' мин'
    if hour > 0 then result = hour .. ' часов ' .. result end
    if days > 0 then result = days .. ' дней ' .. result end
    if result == '0 мин' then result = sec..' сек' end

    if days > 3 then return 'давно' end
    return result
end

function lib.remainedtime(reference)
    if os.difftime(reference, os.time()) < 1 then return '0' end
    local days = math.floor(os.difftime(reference, os.time()) / (24 * 60 * 60))
    local hour = math.floor(os.difftime(reference, os.time()) / (60 * 60)) % 60
    local min = math.floor(os.difftime(reference, os.time()) / 60) % 60
    local sec = os.difftime(os.time(), reference) % 60
    local result = min .. ' мин'
    if hour > 0 then result = hour .. ' часов ' .. result end
    if days > 0 then result = days .. ' дней ' .. result end
    if result == '0 мин' then result = sec..' сек' end
    return result
end

function lib.soontime(reference, range)
    return os.difftime(reference, os.time()) < range
end

function lib.remainsToFormLine(time)
    local remaine = lib.remainedtime(time)
    return remaine == '0' and '' or ' осталось ' .. remaine
end

function lib.dateToString(str) -- Передаем 19.04.2000 23:30 получем переменные по порядку
    local dt = {};
    dt.hour, dt.min, dt.sec, dt.day, dt.month, dt.year = str:match("^(%d+):(%d+):(%d+)%s(%d+).(%d+).(%d+)")
    for key, value in pairs(dt) do dt[key] = tonumber(value) end
    dt.hour = dt.hour + 7
    dt.date = os.time { day = dt.day, year = dt.year, month = dt.month, hour = dt.hour, min = dt.min }
    return dt
end

function lib.checkingWithPayday(date) -- Проверка на обновление после PayDay
    if not date then
        return true
    end

    local now = os.time(utc) + 3 * 3600
    local pd = lib.dateToString(lib.datetime_pd).date
    local upd = type(date) == 'string' and lib.dateToString(date).date or date

    if math.floor(os.difftime(now - upd) / (12 * 60 * 60)) > 1 then
        return true
    elseif (now - upd > 1) and (pd - upd > 0) and (now - pd > 0) then
        return true
    end

    return false
end

-- Получить сегодняшнюю дату
function lib.getDate()
    return lib.datetime_str:sub(10, -1)
end


-- Получение времени в секундах из строки (мин/часы/сек)
-- пример: tmLib.getSecondForString(cow.text, 'До сл.стадии: (%d+) (ч*)')
function lib.getSecondForString(text, reg)
    local time_text, hour, sec = text:match(reg)
    if not time_text or #time_text < 1 then
        return 0
    end

    return tonumber(time_text) * ((sec and #sec >0) and 1 or 60) * ((hour and #hour > 0) and 60 or 1) + 30, ((hour and #hour > 0) and 'h' or (sec and #sec >0) and 's' or 'm')
end

-- Передаем 2 времени. Возращает минимальное. Если стоит toUpd то всегда возращаем time2
function lib.getMinTime(time1, time2, toUpd)
    local remaine = lib.remainedtime(time1)
    local diff_time = os.difftime(time2, time1)
    if remaine == '0' or diff_time < 0 or diff_time > 3599 or toUpd then
        return time2
    end
    return time1
end

------
-- Работа с игроками
------
function lib.sampGetCharsInStream() -- получить id игроков в зоне стрима
    local inStream = {}
    for _, v in pairs(getAllChars()) do
        local result, id = sampGetPlayerIdByCharHandle(v)
        if result then table.insert(inStream, id) end
    end
    return inStream
end

function lib.getIdByNick(nick) -- Получить id по нику игрока
    local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if nick == sampGetPlayerNickname(myid) then return myid end
    for i = 0, 1003 do
        if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == nick then return i end
    end
end

function lib.getUserColor(id) -- Получить цвет по id игрока
    return id and ("%06X"):format(bit.band(sampGetPlayerColor(id), 0xFFFFFF)) or 'FFFFFF'
end

function lib.getColorAndId(nickname) -- цвет и id в формета [id] или ''
    local id = lib.getIdByNick(nickname)
    local str_id = id and ('[%d]'):format(id) or ''
    return str_id, lib.getUserColor(id)
end

------
-- Работа с json
------
function lib.json(directory)
    local class = {}
    function class:Save(tbl)
        if tbl then
            local F = io.open(directory, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true
        end
        return false
    end

    function class:Load(default_table)
        local default_table = default_table or {}
        if not doesFileExist(directory) then class:Save(default_table or {}) end
        local F = io.open(directory, "r")
        local TABLE = decodeJson(F:read("*a") or {})
        F:close()
        return TABLE
    end

    return class
end

------
-- list         Массив в котором будет производится проверка	                                                    обязательный	table
-- what_find	Элемент который будет искаться. В случае если будет передан массив - будет проверять все элементы.	обязательный	string/number/table
-- mode	        Режим точной проверки последовательности. Используется если во второй параметр передан массив.      необязательный  bool
------
function lib.iin(list, what_find, mode)
    if what_find and type(what_find) ~= 'table' then
        local set = {}
        for _, l in ipairs(list) do set[l] = true end
        return set[what_find] and true or false
    elseif type(what_find) == 'table' then
        if not mode or mode == false then
            local set = {}
            for _, l in ipairs(list) do set[l] = true end
            for _, l in ipairs(what_find) do if set[l] then return true end end
        elseif mode == true then
            local set = {}
            local res = nil
            for _, l in ipairs(list) do set[l] = true end
            for k, v in pairs(what_find) do if set[v] then res = true else res = false end end
            return res
        end
    end
end


-------
-- instance наша таблица
-- образец
-- приводит нашу таблицу к виду образца
-----
function lib.bypassStructure(instance, sample)
    local isChanges = false
    for key, val in pairs(sample) do
        if type(val) ~= type(instance[key]) then
            isChanges = true
            if type(val) == 'table' then
                _, instance[key] = lib.bypassStructure({}, val)
            else
                instance[key] = val
            end
        end

        if type(val) == 'table' then
            _, instance[key] = lib.bypassStructure(instance[key], val)
        end

    end
    return isChanges, instance
end

------
-- Работа игрой
------
function lib.search3Dtext(patern, isCooridants) -- Поиск 3d текста
    local messages = {}
    for id = 0, 2048 do
        if sampIs3dTextDefined(id) then
            if isCooridants then
                local text, color, posX, posY, posZ = sampGet3dTextInfoById(id)
                if string.find(text, patern, 1, true) then table.insert(messages, {
                    text = text,
                    x = posX,
                    y = posY,
                    z = posZ,
                }) end
            else
                local text = sampGet3dTextInfoById(id)
                if string.find(text, patern, 1, true) then table.insert(messages, text) end
            end
            
        end
    end
    return messages
end

function lib.getDist(x, y, z) -- Получить дистанцию от игрока до координат get_dist(x,y,z)
    local pl_x, pl_y, pl_z = getCharCoordinates(PLAYER_PED)
    return lib.round(getDistanceBetweenCoords3d(pl_x, pl_y, pl_z, x, y, z), 2)
end

function lib.getDist2(x1,y1,z1,x2,y2,z2)-- Получить дистанцию между точками
    return lib.round(getDistanceBetweenCoords3d(x1,y1,z1,x2,y2,z2), 2)
end

------
-- Работа с imgui
------

function lib.imguiHint(str_id, hint_text, color, no_center)
    color = color or imgui.GetStyle().Colors[imgui.Col.PopupBg]
    local p_orig = imgui.GetCursorPos()
    local hovered = imgui.IsItemHovered()
    imgui.SameLine(nil, 0)

    local animTime = 0.2
    local show = true

    if not POOL_HINTS then POOL_HINTS = {} end
    if not POOL_HINTS[str_id] then
        POOL_HINTS[str_id] = {
            status = false,
            timer = 0
        }
    end

    if hovered then
        for k, v in pairs(POOL_HINTS) do
            if k ~= str_id and os.clock() - v.timer <= animTime then
                show = false
            end
        end
    end

    if show and POOL_HINTS[str_id].status ~= hovered then
        POOL_HINTS[str_id].status = hovered
        POOL_HINTS[str_id].timer = os.clock()
    end

    local getContrastColor = function(col)
        local luminance = 1 - (0.299 * col.x + 0.587 * col.y + 0.114 * col.z)
        return luminance < 0.5 and imgui.ImVec4(0, 0, 0, 1) or imgui.ImVec4(1, 1, 1, 1)
    end

    local rend_window = function(alpha)
        local size = imgui.GetItemRectSize()
        local scrPos = imgui.GetCursorScreenPos()
        local DL = imgui.GetWindowDrawList()
        local center = imgui.ImVec2(scrPos.x - (size.x / 2), scrPos.y + (size.y / 2) - (alpha * 4) + 10)
        local a = imgui.ImVec2(center.x - 7, center.y - size.y - 3)
        local b = imgui.ImVec2(center.x + 7, center.y - size.y - 3)
        local c = imgui.ImVec2(center.x, center.y - size.y + 3)
        local col = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color.x, color.y, color.z, alpha))

        DL:AddTriangleFilled(a, b, c, col)
        imgui.SetNextWindowPos(imgui.ImVec2(center.x, center.y - size.y - 3), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
        imgui.PushStyleColor(imgui.Col.PopupBg, color)
        imgui.PushStyleColor(imgui.Col.Border, color)
        imgui.PushStyleColor(imgui.Col.Text, getContrastColor(color))
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 8))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 6)
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)

        local max_width = function(text)
            local result = 0
            for line in text:gmatch('[^\n]+') do
                local len = imgui.CalcTextSize(line).x
                if len > result then
                    result = len
                end
            end
            return result
        end

        local hint_width = max_width(hint_text) + (imgui.GetStyle().WindowPadding.x * 2)
        imgui.SetNextWindowSize(imgui.ImVec2(hint_width, -1), imgui.Cond.Always)
        imgui.Begin('##' .. str_id, _,
            imgui.WindowFlags.Tooltip + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar +
            imgui.WindowFlags.NoTitleBar)
        for line in hint_text:gmatch('[^\n]+') do
            if no_center then
                imgui.Text(line)
            else
                imgui.SetCursorPosX((hint_width - imgui.CalcTextSize(line).x) / 2)
                imgui.Text(line)
            end
        end
        imgui.End()

        imgui.PopStyleVar(3)
        imgui.PopStyleColor(3)
    end

    if show then
        local between = os.clock() - POOL_HINTS[str_id].timer
        if between <= animTime then
            local s = function(f)
                return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
            end
            local alpha = hovered and s(between / animTime) or s(1.00 - between / animTime)
            rend_window(alpha)
        elseif hovered then
            rend_window(1.00)
        end
    end

    imgui.SetCursorPos(p_orig)
end

function lib.imgToNumber(var)
    return tonumber(lib.u8:decode(ffi.string(var))) or 0
end

function lib.imgToText(var)
    return lib.u8:decode(ffi.string(var))
end

function lib.getValueImgut(data, default)
    if not data then return default end
    if type(data) == 'cdata' then
        return lib.imgToText(data)
    elseif type(data) == 'string' then
        return data
    end
    return default
end

function lib.getValueImgutNumber(data, default)
    local result = lib.getValueImgut(data, default)
    return tonumber(#result > 0 and result or default)
end

function lib.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], lib.u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else
                imgui.Text(lib.u8(w))
            end
        end
    end
    render_text(text)
end

function lib.imguiTextWrapped(clr, text)
    if clr then imgui.PushStyleColor(ffi.C.ImGuiCol_Text, clr) end

    text = ffi.new('char[?]', #text + 1, text)
    local text_end = text + ffi.sizeof(text) - 1
    local pFont = imgui.GetFont()

    local scale = 1.0
    local endPrevLine = pFont:CalcWordWrapPositionA(scale, text, text_end, imgui.GetContentRegionAvail().x)
    imgui.TextUnformatted(text, endPrevLine)

    while endPrevLine < text_end do
        text = endPrevLine
        if text[0] == 32 then text = text + 1 end
        endPrevLine = pFont:CalcWordWrapPositionA(scale, text, text_end, imgui.GetContentRegionAvail().x)
        if text == endPrevLine then
            endPrevLine = endPrevLine + 1
        end
        imgui.TextUnformatted(text, endPrevLine)
    end

    if clr then imgui.PopStyleColor() end
end

------
-- Работа с цветом
------
function lib.isBackgroundDark(color)
    if not color or #color < 1 then return false end
    local r, g, b = color:match('(%x%x)(%x%x)(%x%x)')
    return tonumber(r, 16) * 0.299 + tonumber(g, 16) * 0.587 + tonumber(b, 16) * 0.114 < 180
end

------
-- Работа с файловой системой
------
function lib.checkingPath(path)
    local fullPath = getWorkingDirectory() .. '\\'
    for part in string.gmatch(path:sub(path:find("moonloader") + 10, #path), "([^\\]+)\\") do
        fullPath = fullPath .. part .. '\\'
        local ok, err, code = os.rename(fullPath, fullPath)
        if code == 2 then
            createDirectory(fullPath)
        elseif not ok then
            print('{77DDE7}' .. path .. '{FFCC00} не установлен!\n {FFCC00}Ошибка создание каталога: ' ..
                err)
            return false
        end
    end
    return true
end

return lib
