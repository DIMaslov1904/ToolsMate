-- �����������
require 'ToolsMate.expansion'
local ffi      = require 'ffi'
local encoding = require 'encoding'
local imgui    = require 'mimgui'
local dlstatus = require('moonloader').download_status


encoding.default = 'CP1251'


local lib = {
    u8 = encoding.UTF8,
    setting = {
        name = 'tm-lib',
        url_script = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/lib.lua',
        urp_version = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json',
        version = "0.1.0",
        path_script = getWorkingDirectory() .. '\\ToolsMate\\lib.lua'
    }
}


------
-- ������ � �������
------
function lib.round(num, idp)
    local mult = 10 ^ (idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

------
-- ������ � ������
------
function lib.difftime(reference)
    local days = math.floor(os.difftime(os.time(), reference) / (24 * 60 * 60))
    local hour = math.floor(os.difftime(os.time(), reference) / (60 * 60)) % 60
    local min = math.floor(os.difftime(os.time(), reference) / (60)) % (60 * 60)
    local result = min .. ' ���'
    if hour > 0 then result = hour .. ' ����� ' .. result end
    if days > 0 then result = days .. ' ���� ' .. result end
    return result
end

function lib.remainedtime(reference)
    if os.difftime(reference, os.time()) < 1 then return '0' end
    local hour = math.floor(os.difftime(reference, os.time()) / (60 * 60))
    local min = math.floor(os.difftime(reference, os.time()) / 60) % 60
    local result = min .. ' ���'
    if hour > 0 then result = hour .. ' ����� ' .. result end
    return result
end

function lib.soontime(reference, range)
    return os.difftime(reference, os.time()) < range
end

function lib.remainsToFormLine(time)
    local remaine = lib.remainedtime(time)
    return remaine == '0' and '' or ' �������� ' .. remaine
end

------
-- ������ � ��������
------
function lib.sampGetCharsInStream() -- �������� id ������� � ���� ������
    local inStream = {}
    for _, v in pairs(getAllChars()) do
        local result, id = sampGetPlayerIdByCharHandle(v)
        if result then table.insert(inStream, id) end
    end
    return inStream
end

function lib.getIdByNick(nick)
    local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if nick == sampGetPlayerNickname(myid) then return myid end
    for i = 0, 1003 do
        if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == nick then return i end
    end
end

-- �������� ���� �� id ������
function lib.getUserColor(id)
    return id and ("%06X"):format(bit.band(sampGetPlayerColor(id), 0xFFFFFF)) or 'FFFFFF'
end

function lib.getColorAndId(nickname)
    local id = lib.getIdByNick(nickname)
    local str_id = id and ('[%d]'):format(id) or ''
    return str_id, lib.getUserColor(id)
end

------
-- ������ � json
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
-- list         ������ � ������� ����� ������������ ��������	                                                    ������������	table
-- what_find	������� ������� ����� ��������. � ������ ���� ����� ������� ������ - ����� ��������� ��� ��������.	������������	string/number/table
-- mode	        ����� ������ �������� ������������������. ������������ ���� �� ������ �������� ������� ������.      ��������������  bool
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

------
-- ������ �����
------
function lib.search3Dtext(patern)
    local messages = {}
    for id = 0, 2048 do
        if sampIs3dTextDefined(id) then
            local text = sampGet3dTextInfoById(id)
            if string.find(text, patern, 1, true) then table.insert(messages, text) end
        end
    end
    return messages
end

------
-- ������ � imgui
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

------
-- ������ � ������
------
function lib.isBackgroundDark(color)
    if not color or #color < 1 then return false end
    local r, g, b = color:match('(%x%x)(%x%x)(%x%x)')
    return tonumber(r, 16) * 0.299 + tonumber(g, 16) * 0.587 + tonumber(b, 16) * 0.114 < 180
end

------
-- ������ � �������� ��������
------
function lib.checkingPath(path)
    local fullPath = getWorkingDirectory() .. '\\'
    for part in string.gmatch(path:sub(path:find("moonloader") + 10, #path), "([^\\]+)\\") do
        fullPath = fullPath .. part .. '\\'
        local ok, err, code = os.rename(fullPath, fullPath)
        if code == 2 then
            createDirectory(fullPath)
        elseif not ok then
            print('{77DDE7}' .. path .. '{FFCC00} �� ����������!\n {FFCC00}������ �������� ��������: ' ..
                err)
            return false
        end
    end
    return true
end

------
-- ������ � ������������
------
local state = {
    update_path = b(getWorkingDirectory(), '\\ToolsMate\\Update\\'),
    libs = {}
}

-- ��������� ��������� ������
local function compareVersion(current, new)
    local function parser(ver)
        local numbers = {}
        local count = 0
        local result = 0
        for num in string.gmatch(ver, "([^.]+)") do
            count = count + 1
            numbers[count] = tonumber(num)
        end
        for i = count, 1, -1 do result = result + (numbers[i] * 1000 ^ (count - i)) end
        return result
    end

    return parser(new) > parser(current)
end

-- ���������� ��������
local flowGet = lua_thread.create_suspended(function(name)
    if not name then return end
    local directory, url, reload, found, noAutoUpdate

    for _, l_lib in pairs(state.libs) do
        if l_lib.name == name then
            found = true
            if l_lib.urlGetUpdate then
                directory = l_lib.path
                url = l_lib.urlGetUpdate
                reload = l_lib.reload
            end
            break
        end
    end

    if not found then return end
    if not url then return end


    local loading = true

    downloadUrlToFile(url, directory, function(id, status)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            if reload then reload() end
            loading = false
        end
    end)
    while loading do wait(500) end
end)



-- �������� ������
local compareVersions  = lua_thread.create_suspended(function(directory)
    local versions_json = lib.json(directory):Load({})

    for lib_name, val in pairs(versions_json) do
        for _, l_lib in pairs(state.libs) do
            if l_lib.name == lib_name and compareVersion(l_lib.version, val.version) then
                flowGet:run(lib_name)
                while flowGet:status() ~= 'dead' do wait(1000) end
            end
        end
    end
end)

-- �������� ��������� ������
local flowRequestCheck = lua_thread.create_suspended(function(name, url)
    local directory = b(state.update_path, name, '.json')
    local loading = true

    downloadUrlToFile(url, directory, function(id, status)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            compareVersions:run(directory)
            while compareVersions:status() ~= 'dead' do wait(1000) end
            loading = false
        end
    end)
    while loading do wait(500) end
end)

lib.checkUpdateList    = lua_thread.create_suspended(function(list)
    lib.checkingPath(state.update_path)

    for _, item in pairs(list) do
        table.insert(state.libs, {
            name = list.name,
            version = list.version,
            path = list.path_script,
            urlGetUpdate = item.url_script,
            urlCheckUpdate = item.urp_version,
            reload = item.reload
        })

        flowRequestCheck:run(item.name, item.urp_version)
        while flowRequestCheck:status() ~= 'dead' do wait(1000) end
    end
end)


return lib