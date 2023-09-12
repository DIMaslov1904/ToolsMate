script_name('ToolsMate[FarmersAssistant]')
script_author('DIMaslov1904')
script_version("0.3.6")
script_url("https://t.me/ToolsMate")
script_description [[
    В основном бухгалтерская функциональность.
    Позвлояет расчитывать премии, расходы, стоимость продажи фруктов.
]]



-------------------------
-- Текста уведомлений
-------------------------
local localization = {
    notifications = {
        speedBooster = {
            before = 'До окончания буста скорости',
            current = 'Буст скорости окончен'
        },
        quantityBooster = {
            before = 'До окончания буста количества',
            current = 'Буст количества окончен'
        },
        warehouse = 'На складе осталось',
        seed = 'На поле осталось',
        harvest = 'Готово продукции уже'
    }
}

-------------------------
-- Координаты мест
-------------------------
local zone = {
    priceFruit = { -- цены на фрукты
        x = 969.73431396484,
        y = 2160.6918945313,
        z = 10.820300102234
    },
    farms = {
        x =  -6.2522883415222,
        y =  62.375579833984
    }
}


-------------------------
-- Зависимости
-------------------------
local not_found = {}
require 'moonloader'
local wm = require 'windows.message'
local vkeys = require 'vkeys'
local isSampev, sampev = xpcall(require, function() table.insert(not_found, 'SAMP.Lua') end, 'samp.events')
local isImgui, imgui = xpcall(require, function() table.insert(not_found, 'MimGui') end, 'mimgui')
local isUpdater, updater = pcall(require, ('ToolsMate[Updater]'))
local isTMLib, tmLib = xpcall(require, function()
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
local getValueImgut = tmLib.getValueImgut
local getValueImgutNumber = tmLib.getValueImgutNumber
local separatorNumber = tmLib.separatorNumber


-- Переменные
local renderWindow = new.bool()
local renderWindowMembers = new.bool(true)
local renderWindowStatuses = new.bool(true)
local renderWindowOld = renderWindow[0]
local sizeX, sizeY = getScreenResolution()
local isAutoOpenFarmInfo = false


local isFarmer = false
local now_date = os.date('%m%d')
local config_file_name = table.concat({ getWorkingDirectory(), 'config', script.this.name .. '.json' }, '/')
local default_state = {
    owner = '',
    days = {},
    members = {
        owner = '',
        deputies = {},
        farmers = {},
    },
    hangar = {
        balance = 0,
        warehouse = 0,
        seed = 0,
        harvest = 0,
        quantityBooster = os.time(),
        speedBooster = os.time(),
        upd = os.time()
    },
    greenhouse = {
        trees = {}
    },
    settings = {
        timeQuantityBooster = 10,
        timeSpeedBooster = 10,
        countWarehouse = 5000,
        countSeed = 2500,
        countHarvest = 3500
    },
    fruits = {}
}

local state = table.copy(default_state)

local timeQuantityBooster
local timeSpeedBooster
local countWarehouse
local countSeed
local countHarvest


local tab = 1

local select_day
local select_date = now_date
local difference_days = 0
local owner, owner_id

local showAll = false

local members = {
    owner = '',
    deputies = {},
    farmers = {},
    workers = {}
}

local param_list = {
    { key = 'balance', title = 'Баланс фермы', reg = '{FBDD7E}Баланс фермы:{FFFFFF}%s+(%d+)' },
    { key = 'warehouse', title = 'Семена в амбаре', reg = '{FBDD7E}Семена в амбаре:{FFFFFF}%s+(%d+)' },
    { key = 'seed', title = 'Урожая на поле', reg = '{FBDD7E}Урожая на поле:{FFFFFF}%s+(%d+)' },
    { key = 'harvest', title = 'Продукции в амбаре', reg = '{FBDD7E}Продукции в амбаре:{FFFFFF}%s+(%d+)' },
}

local statuses = {}




local function reverDate(date)
    local month, day = date:match("(%d%d)(%d%d)")
    return table.concat({ day, month }, '.')
end

local function createNewDay()
    if not state.days[select_date] or not state.days[select_date].profit or not state.days[select_date].members then
        state.days[select_date] = { profit = "0", members = {} }
    end
    select_day = state.days[select_date]
end


local function isPayImgui(pay)
    if type(pay) == 'cdata' then return pay[0] == true end
    return pay == true
end

-- Сохранение конфигурации
local function saveState()
    if table.len(state.days) > 0 then
        state.days[select_date] = {
            profit = tmLib.imgToText(select_day.profit),
            members = {}
        }
        for nickname, data in pairs(select_day.members) do
            state.days[select_date].members[nickname] = {
                fixed = getValueImgut(data.fixed, '0'),
                part  = getValueImgut(data.part, '0'),
                total = data.total or 0,
                pay   = isPayImgui(data.pay)
            }
        end
    end
    state.owner = tmLib.getValueImgut(owner, '')
    tmLib.json(config_file_name):Save(state)
end


local bypassStructure
bypassStructure = function(instance, sample)
    local isChanges = false
    for key, val in pairs(sample) do
        if type(val) ~= type(instance[key]) then
            isChanges = true
            if type(val) == 'table' then
                _, instance[key] = bypassStructure({}, val)
            else
                instance[key] = val
            end
        end
    end
    return isChanges, instance
end


-- Загрузка конфигурации
local function loadState()
    local isChanges
    state = tmLib.json(config_file_name):Load(state) or state
    isChanges, state = bypassStructure(state, default_state)
    if (isChanges) then saveState() end
    createNewDay()

    owner = new.char[256](state.owner or '')
    owner_id = new.char[100]('')
    timeQuantityBooster = new.char[50](tostring(state.settings.timeQuantityBooster or '0'))
    timeSpeedBooster = new.char[50](tostring(state.settings.timeSpeedBooster or '0'))
    countWarehouse = new.char[50](tostring(state.settings.countWarehouse or '0'))
    countSeed = new.char[50](tostring(state.settings.countSeed or '0'))
    countHarvest = new.char[50](tostring(state.settings.countHarvest or '0'))
end


local function getDifferenceDay(difference)
    return os.date("%m%d", os.time() - 24 * 60 * 60 * difference)
end


local function createMembersAward()
    local d1, d2, d3 = now_date, getDifferenceDay(1), getDifferenceDay(2)

    for day, _ in pairs(state.days) do
        if day ~= d1 and day ~= d2 and day ~= d3 then
            state.days[day] = nil
        end
    end

    local old_members = table.copy(select_day.members)
    select_day = {
        profit = new.char[256](getValueImgut(select_day.profit, '0')),
        members = {}
    }

    local fillMembers = function(t)
        for i, nickname in pairs(t) do
            if nickname ~= '{FF0033}свободное место' then
                local old_state = old_members[nickname]
                if old_state then
                    select_day.members[nickname] = {
                        fixed = new.char[256](getValueImgut(old_state.fixed, '0')),
                        part  = new.char[256](getValueImgut(old_state.part, '0')),
                        total = old_state.total or '0',
                        pay   = new.bool(isPayImgui(old_state.pay))
                    }
                else
                    select_day.members[nickname] = {
                        fixed = new.char[256](0),
                        part  = new.char[256](0),
                        total = 0,
                        pay   = new.bool(false)
                    }
                end
            end
        end
    end

    local fillOldMembers = function()
        for nickname, old_state in pairs(old_members) do
            select_day.members[nickname] = {
                fixed = new.char[256](getValueImgut(old_state.fixed, '0')),
                part  = new.char[256](getValueImgut(old_state.part, '0')),
                total = old_state.total or '0',
                pay   = new.bool(isPayImgui(old_state.pay))
            }
        end
    end

    if difference_days > 0 and table.len(old_members) > 0 then
        fillOldMembers()
    else
        fillMembers(state.members.deputies)
        fillMembers(state.members.farmers)
    end
end

local function changeDay()
    saveState()
    select_date = getDifferenceDay(difference_days)
    createNewDay()
    createMembersAward()
end

local function selectPrevDay()
    if difference_days > 1 then return end
    difference_days = difference_days + 1
    changeDay()
end

local function selectNextDay()
    if difference_days <= 0 then return end
    difference_days = difference_days - 1
    changeDay()
end

local is_open_popup = new.bool(false)

local function tableRowAwards(nickname, data)
    local disabled = data.pay[0]
    imgui.Separator()
    imgui.NextColumn()
    imgui.Text(nickname)
    if imgui.IsItemClicked() and not disabled then
        imgui.OpenPopup(nickname)
        is_open_popup[0] = true
    end

    if imgui.BeginPopupModal(nickname, is_open_popup, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove) then
        imgui.Text(u8 "Выберите способ оплаты");
        if imgui.Button(u8 "Передать") then
            local successes, id_user = pcall(tostring, tmLib.getIdByNick(nickname))
            if successes then
                sampSendChat(("/pay %s %d"):format(id_user, data.total))
                function sampev.onServerMessage(_, text)
                    local mess = ('Вы передали %s'):format(nickname)
                    if string.find(text, mess, 1, true) then
                        data.pay[0] = true
                        function sampev.onServerMessage() end
                    end
                end
            end
            if not successes then sampAddChatMessage('Пользователь не онлай', -1) end
            imgui.CloseCurrentPopup()
            is_open_popup[0] = false
        end
        imgui.SameLine()
        if imgui.Button(u8 "На банковский счёт") then
            sampSendChat(("/transfer %s %d"):format(nickname, data.total))
            function sampev.onServerMessage(_, text)
                local mess = ('Вы передали %d вирт, на счет %s'):format(data.total, nickname)
                if string.find(text, mess, 1, true) then
                    data.pay[0] = true
                    function sampev.onServerMessage() end
                end
            end

            imgui.CloseCurrentPopup()
            is_open_popup[0] = false
        end
        if imgui.Button(u8 "Закрыть") then
            imgui.CloseCurrentPopup()
            is_open_popup[0] = false
        end
        imgui.EndPopup()
    end

    imgui.NextColumn()
    if disabled then
        imgui.Text(tmLib.getValueImgut(data.fixed, '0'))
        imgui.NextColumn()
        imgui.Text(tmLib.getValueImgut(data.part, '0'))
    else
        imgui.InputText('##fix_' .. nickname, data.fixed, 265)
        imgui.NextColumn()
        imgui.InputText('##path_' .. nickname, data.part, 265)
    end
    imgui.NextColumn()
    imgui.Text(separatorNumber(data.total))
    imgui.NextColumn()
    imgui.Checkbox('##pay_' .. nickname, data.pay)
end

-- Обновление состава
local function updateMembers(text)
    if text:match('Владелец%s+(%S+)%s+') ~= state.owner then
        return
    end
    state.members = table.copy(default_state.members)
    for value in string.gmatch(text, '[^\n]+') do
        if value:find('Владелец') then
            state.members.owner = value:match('^Владелец%s+(%S+)%s+')
        elseif value:find('Заместитель') then
            table.insert(state.members.deputies, value:match('Заместитель%s+(%S+)%s+'))
        elseif value:find('Фермер') then
            table.insert(state.members.farmers, value:match('Фермер%s+(%S+)%s+'))
        end
    end
    for i = 1, 5 - #state.members.deputies do
        table.insert(state.members.deputies, '{FF0033}свободное место')
    end

    for i = 1, 10 - #state.members.farmers do
        table.insert(state.members.farmers, '{FF0033}свободное место')
    end
    saveState()
end

-- Обновление информации о ферме
local function updateFinfo(text)
    state.hangar.upd = os.time()

    for value in string.gmatch(text, '[^\n]+') do
        if value:find('Владелец') then
            local l_owner = value:match('{FBDD7E}Владелец:{FFFFFF}%s+(%S+)')
            if l_owner and state.owner ~= l_owner then return end
        elseif value:find('скорости сбора урожая') then
            local remaineSpeedBooster = tmLib.remainedtime(state.hangar.speedBooster)
            local hour                = tonumber(value:match('— Множитель х2 к скорости сбора урожая:%s+(%d+) час') or
                0) * 60 * 60
            local min                 = tonumber(value:match('— Множитель х2 к скорости сбора урожая:%s+(%d+) мин') or
                0) * 60
            local sec                 = tonumber(value:match('— Множитель х2 к скорости сбора урожая:%s+(%d+) сек') or
                0)
            local result              = os.time() + (hour > 0 and hour + 60 or 0) + (min > 0 and min + 60 or 0) + sec
            if remaineSpeedBooster == '0' or os.difftime(result, state.hangar.speedBooster) < 0 or min > 0 then
                state.hangar.speedBooster = result
            end
        elseif value:find('количеству собираемого урожая') then
            local remaineQuantityBooster = tmLib.remainedtime(state.hangar.quantityBooster)
            local hour = tonumber(value:match('— Множитель х2 к количеству собираемого урожая:%s+(%d+) час') or
                0) * 60 * 60
            local min = tonumber(value:match('— Множитель х2 к количеству собираемого урожая:%s+(%d+) мин') or
                0) * 60
            local sec = tonumber(value:match('— Множитель х2 к количеству собираемого урожая:%s+(%d+) сек') or
                0)
            local result = os.time() + (hour > 0 and hour + 60 or 0) + (min > 0 and min + 60 or 0) + sec
            if remaineQuantityBooster == '0' or os.difftime(result, state.hangar.quantityBooster) < 0 or min > 0 then
                state.hangar.quantityBooster = result
            end
        else
            for _, item in pairs(param_list) do
                if value:find(item.title) then
                    state.hangar[item.key] = tonumber(value:match(item.reg))
                    break
                end
            end
        end
    end
    saveState()
end


local function updateTrees(arr)
    for _, item in pairs(arr) do
        local num = tonumber(item:match('%[Место №(%d+)%]')) or 0
        state.greenhouse.trees[num] = {
            name = item:match('<< (.+) >>'),
            health = tonumber(item:match('Здоровье:{FFFFFF} (%d+)')),
            nutrition = tonumber(item:match('Питание:{FFFFFF} (%d+)'))
        }

        for value in string.gmatch(item, '[^\n]+') do
            if string.find(value, 'Стадия') then
                state.greenhouse.trees[num].stage = value:match('Стадия:{FFFFFF} (%A+)')
            elseif string.find(value, 'До сл.стадии') then
                state.greenhouse.trees[num].traceStage = value:match('До сл.стадии (%d+)%s')
            end
        end
    end
    saveState()
end

function imgui.TextColoredRGB(text)
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
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else
                imgui.Text(u8(w))
            end
        end
    end
    render_text(text)
end

local imguiScreen = {}

------------------
-- Окно состава
------------------
function imguiScreen.members()
    local id_owner, color_owner = tmLib.getColorAndId(state.members.owner)
    imgui.Text(u8 'Владелец:')
    imgui.TextColoredRGB(('{%s}%s %s'):format(color_owner, state.members.owner, id_owner))
    imgui.Separator()

    imgui.Text(u8 'Заместители:')
    for _, nikname in pairs(state.members.deputies) do
        local id, color = tmLib.getColorAndId(nikname)
        imgui.TextColoredRGB(('{%s}%s %s'):format(color, nikname, id))
    end
    imgui.Separator()

    imgui.Text(u8 'Фермеры:')
    for _, nikname in pairs(state.members.farmers) do
        local id, color = tmLib.getColorAndId(nikname)
        imgui.TextColoredRGB(('{%s}%s %s'):format(color, nikname, id))
    end
end

------------------
-- Окно премий
------------------
function imguiScreen.awards()
    local sum_fized, sum_part = 0, 0

    for nickname, data in pairs(select_day.members) do
        sum_fized = sum_fized + getValueImgutNumber(data.fixed, 0)
        sum_part = sum_part + getValueImgutNumber(data.part, 0)
    end

    local one_part = 0

    if sum_part > 0 then one_part = (getValueImgutNumber(select_day.profit, 0) - sum_fized) / sum_part end

    for nickname, data in pairs(select_day.members) do
        if not data.pay[0] then
            data.total = tmLib.round(
                (getValueImgutNumber(data.fixed, 0) + getValueImgutNumber(data.part, 0) * one_part), 0)
        end
    end

    if difference_days > 1 then
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
    end
    if imgui.ArrowButton('Prevent day', 0) then
        selectPrevDay()
    end
    if difference_days > 1 then
        imgui.PopStyleColor()
    end
    imgui.SameLine()
    imgui.Text(reverDate(select_date))
    if difference_days == 0 then
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
    end
    imgui.SameLine()
    if imgui.ArrowButton('Next day', 1) then
        selectNextDay()
    end
    if difference_days == 0 then
        imgui.PopStyleColor()
        imgui.SameLine()
        imgui.Text(u8 'Сегодня')
    end

    imgui.PushItemWidth(100)
    imgui.InputText(u8 'Заработано фермой', select_day.profit, 256)
    imgui.SameLine()
    imgui.Text(u8(separatorNumber(tmLib.imgToNumber(select_day.profit))))

    imgui.Columns(5, 'awards', true)
    imgui.SetColumnWidth(-1, 200)
    imgui.Text(u8 'Ник')
    imgui.NextColumn()
    imgui.SetColumnWidth(-1, 120)
    imgui.Text(u8 'Фикс')
    imgui.NextColumn()
    imgui.SetColumnWidth(-1, 100)
    imgui.Text(u8 'Доля')
    imgui.NextColumn()
    imgui.SetColumnWidth(-1, 100)
    imgui.Text(u8 'Итого')
    imgui.NextColumn()
    imgui.SetColumnWidth(-1, 80)
    imgui.Text(u8 'Выплачено')

    for nickname, data in pairs(select_day.members) do
        tableRowAwards(nickname, data)
    end
end

------------------
-- Окно амбара
------------------
function imguiScreen.ambar()
    imgui.Columns(2, 'ambar', false)

    imgui.SetColumnWidth(-1, 160)
    imgui.Text(u8 'Баланс фермы')
    imgui.NextColumn()
    imgui.Text(separatorNumber(state.hangar.balance))
    imgui.NextColumn()

    imgui.Text(u8 'Семена в амбаре')
    imgui.NextColumn()
    imgui.ProgressBar(state.hangar.warehouse / 10000, imgui.ImVec2(100, 15),
        separatorNumber(state.hangar.warehouse))
    imgui.NextColumn()

    imgui.Text(u8 'Урожая на поле')
    imgui.NextColumn()
    imgui.ProgressBar(state.hangar.seed / 5000, imgui.ImVec2(100, 15), separatorNumber(state.hangar.seed))
    imgui.NextColumn()

    imgui.Text(u8 'Продукции в амбаре')
    imgui.NextColumn()
    imgui.ProgressBar(state.hangar.harvest / 10000, imgui.ImVec2(100, 15),
        separatorNumber(state.hangar.harvest))
    imgui.NextColumn()


    imgui.Text(u8('Буст скорости до'))
    imgui.NextColumn()

    imgui.TextColoredRGB('{AAAAAA}' ..
        os.date('%H:%M:%S', state.hangar.speedBooster) ..
        '{00FF00}' .. tmLib.remainsToFormLine(state.hangar.speedBooster))
    imgui.NextColumn()
    imgui.Text(u8('Буст количества до'))
    imgui.NextColumn()
    imgui.TextColoredRGB('{AAAAAA}' ..
        os.date('%H:%M:%S', state.hangar.quantityBooster) ..
        '{00FF00}' .. tmLib.remainsToFormLine(state.hangar.quantityBooster))
    imgui.NextColumn()

    imgui.Text(u8 'Синхроницазия')
    imgui.NextColumn()
    imgui.TextColoredRGB('{AAAAAA}' ..
        os.date('%H:%M:%S', state.hangar.upd) .. ' {00FF00}' .. tmLib.difftime(state.hangar.upd) .. ' назад')
    imgui.NextColumn()
end

------------------
-- Окно теплицы
------------------
function imguiScreen.greenhouses()
    imgui.Columns(2, 'trees', false)
    for i, item in pairs(state.greenhouse.trees) do
        imgui.SetColumnWidth(-1, 300)
        imgui.Text(u8('№' .. tostring(i) .. ' ' .. item.name))
        imgui.Text(u8(item.stage .. ' до след ' .. item.traceStage))
        imgui.Text(u8 'Здоровье')
        imgui.SameLine()
        imgui.ProgressBar(item.health / 100, imgui.ImVec2(80, 15))
        imgui.Text(u8 'Питание  ')
        imgui.SameLine()
        imgui.ProgressBar(item.nutrition / 100, imgui.ImVec2(80, 15))
        imgui.Text('==============')

        if i == 6 then
            imgui.NextColumn()
        end
    end
end

------------------
-- Окно хлева
------------------
function imguiScreen.barn()
end

------------------
-- Окно хлева
------------------
function imguiScreen.settings()
    imgui.Text(u8 'Владелец фермы')
    imgui.PushItemWidth(200)
    if imgui.InputText('##ownerFarm', owner, 256) then
        saveState()
    end
    imgui.SameLine()
    imgui.PushItemWidth(40)
    imgui.InputText('##newOwnerId', owner_id, 256)
    imgui.SameLine()
    if imgui.Button(u8 'Заполнить по id') then
        owner = new.char[256](sampGetPlayerNickname(tmLib.getValueImgutNumber(owner_id, -1)) or '')
        saveState()
    end
    imgui.Text(u8 'Если осталось меньше')
    imgui.SameLine()
    if imgui.InputText('##timeQuantityBooster', timeQuantityBooster, 50) then
        state.settings.timeQuantityBooster = tmLib.getValueImgutNumber(timeQuantityBooster, 0)
        saveState()
    end
    imgui.SameLine()
    imgui.Text(u8 'мин уведомлять о бусте количества')
    imgui.Text(u8 'Если осталось меньше')
    imgui.SameLine()
    if imgui.InputText('##timeSpeedBooster', timeSpeedBooster, 50) then
        state.settings.timeSpeedBooster = tmLib.getValueImgutNumber(timeSpeedBooster, 0)
        saveState()
    end
    imgui.SameLine()
    imgui.Text(u8 'мин уведомлять о бусте скорости')
    imgui.Text(u8 'Если меньше')
    imgui.SameLine()
    if imgui.InputText('##countWarehouse', countWarehouse, 50) then
        state.settings.countWarehouse = tmLib.getValueImgutNumber(countWarehouse, 0)
        saveState()
    end
    imgui.SameLine()
    imgui.Text(u8 ' состояние склада, то уведомить')
    imgui.Text(u8 'Если меньше')
    imgui.SameLine()
    if imgui.InputText('##countSeed', countSeed, 50) then
        state.settings.countSeed = tmLib.getValueImgutNumber(countSeed, 0)
        saveState()
    end
    imgui.SameLine()
    imgui.Text(u8 'засаженного на поле, то уведомить')
    imgui.Text(u8 'Если больше')
    imgui.SameLine()
    if imgui.InputText('##countHarvest', countHarvest, 50) then
        state.settings.countHarvest = tmLib.getValueImgutNumber(countHarvest, 0)
        saveState()
    end
    imgui.SameLine()
    imgui.Text(u8 'готовой продукции на складе, то уведомить')
end

imgui.OnFrame(function() return not isPauseMenuActive() and renderWindow[0] end,
    function(player)
        player.HideCursor = false
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.00, 0.47, 1.85, 1.00))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.25, 0.25, 0.26, 0.6))
        imgui.SetNextWindowSize(imgui.ImVec2(800, 530), imgui.Cond.Always)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        local title = b('Помошник по ферме',
            #state.owner < 1 and ' [Укажите владельца в настройках!]' or '', ' [ver ',
            script.this.version, ']')
        imgui.Begin(u8(title), renderWindow,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoCollapse)

        for numberTab, nameTab in pairs({'Главная', 'Состав', 'Премии', 'Теплица', 'Хлев',
            'Настройки' }) do
            if imgui.Button(u8(nameTab), imgui.ImVec2(140, 34)) then
                tab = numberTab
                if tab == 2 then createMembersAward() end
            end
        end

        imgui.SetCursorPos(imgui.ImVec2(155, 28))
        if imgui.BeginChild('Name##' .. tab, imgui.ImVec2(660, 490), false) then
            if tab == 1 then
                imguiScreen.ambar()
            elseif tab == 2 then
                imguiScreen.members()
            elseif tab == 3 then
                imguiScreen.awards()
            elseif tab == 4 then
                imguiScreen.greenhouses()
            elseif tab == 5 then
                imguiScreen.barn()
            elseif tab == 6 then
                imguiScreen.settings()
            end
            imgui.EndChild()
        end
        imgui.End()
        imgui.PopStyleColor()
    end
)

local function imguiUsers(users)
    for _, user in pairs(users) do
        if not user.id then return end
        local nearby = sampGetPlayerHealth(user.id) > 0
        if showAll or nearby then
            local text = ('{%s}%s {FFFFFF}[%s]'):format(user.color, user.nick, user.id)
            if not nearby then
                text = text .. ' {FF0000}не в зоне видимости'
            end
            imgui.TextColoredRGB(text)
        end
    end
end

imgui.OnFrame(
    function() return not isPauseMenuActive() and renderWindowMembers[0] end,
    function(squadImgui)
        squadImgui.HideCursor = not showAll

        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.11, 0.15, 0.17, 0))
        imgui.SetNextWindowSize(imgui.ImVec2(800, 530), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        imgui.Begin(u8("Squad"), renderWindowMembers,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.AlwaysAutoResize)

        imguiUsers({ members.owner })
        imguiUsers(members.deputies)
        imguiUsers(members.farmers)
        if #members.workers > 0 then
            imgui.TextColored(imgui.ImVec4(0, 1, 0, 1), u8 'Рабочие:')
            imguiUsers(members.workers)
        end
        imgui.End()
        imgui.PopStyleColor()
    end
)

imgui.OnFrame(
    function() return not isPauseMenuActive() and #statuses > 0 and renderWindowStatuses[0] end,
    function(squadImgui)
        squadImgui.HideCursor = not showAll
        imgui.SetNextWindowSize(imgui.ImVec2(800, 530), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        imgui.Begin(u8("renderWindowStatuses"), renderWindowStatuses,
            imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar +
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.AlwaysAutoResize)

        for _, val in pairs(statuses) do
            local text = localization.notifications[val.key]
            if type(localization.notifications[val.key]) == 'table' then
                if #val.data > 0 then
                    text = localization.notifications[val.key].before
                else
                    text = localization.notifications[val.key].current
                end
            end
            imgui.Text(u8(c({ text, val.data }, ' ')))
        end

        imgui.End()
        imgui.PopStyleColor()
    end
)


local function getPedBySkin(id)
    local result, ped = sampGetCharHandleBySampPlayerId(id)


    if result and tmLib.iin({ 157, 132 }, getCharModel(ped)) then
        local x = getCharCoordinates(ped)
        if x > -30 then
            return {
                id = id,
                nick = sampGetPlayerNickname(id),
                color = tmLib.getUserColor(id)
            }
        end
    end
end

local function getOnlineMember(nickname)
    local id = tmLib.getIdByNick(nickname)
    if id then
        return {
            id = id,
            nick = nickname,
            color = tmLib.getUserColor(tonumber(id))
        }
    end
    return false
end

local function getIdsSkins()
    while true do
        members = {
            owner = {},
            deputies = {},
            farmers = {},
            workers = {}
        }

        local l_owner = getOnlineMember(state.members.owner)
        if l_owner then
            members.owner = l_owner
        end

        for _, nickname in pairs(state.members.deputies) do
            local user = getOnlineMember(nickname)
            if user then table.insert(members.deputies, user) end
        end

        for _, nickname in pairs(state.members.farmers) do
            local user = getOnlineMember(nickname)
            if user then table.insert(members.farmers, user) end
        end

        for _, id in pairs(tmLib.sampGetCharsInStream()) do
            local user = getPedBySkin(id)
            if user then table.insert(members.workers, user) end
        end
        wait(6000)
    end
end

local function checkingStatus()
    while true do
        statuses = {}
        if isFarmer then
            ------------------
            -- проверка бустов
            ------------------
            if tmLib.soontime(state.hangar.speedBooster, (state.settings.timeSpeedBooster or 0) * 60) then
                table.insert(statuses,
                    { key = 'speedBooster', data = tmLib.remainsToFormLine(state.hangar.speedBooster) })
            end

            if tmLib.soontime(state.hangar.quantityBooster, (state.settings.timeQuantityBooster or 0) * 60) then
                table.insert(statuses,
                    { key = 'quantityBooster', data = tmLib.remainsToFormLine(state.hangar.quantityBooster) })
            end

            ------------------
            -- проверка склада
            ------------------
            if state.hangar.warehouse < state.settings.countWarehouse then
                table.insert(statuses, { key = 'warehouse', data = state.hangar.warehouse })
            end

            if state.hangar.seed < state.settings.countSeed then
                table.insert(statuses, { key = 'seed', data = state.hangar.seed })
            end

            if state.hangar.harvest > state.settings.countHarvest then
                table.insert(statuses, { key = 'harvest', data = state.hangar.harvest })
            end
        end
        wait(6000)
    end
end

local farm_skin_ids = {
    '34',
    '131',
    '132',
    '157',
    '158',
    '161',
    '198',
    '201'
}


-- Получаем цену фруктов
local function getPriceFruit()
    -- local text = tmLib.search3Dtext('Разгрузка фруктов')[1]
    -- if text then
    --     state.fruits = {}
    --     for value in string.gmatch(text, '[^\n]+') do
    --         if value:find('слив') then
    --             state.fruits.plums = value:match('Стоимость слив:%s+(.+)%s+')
    --         elseif value:find('яблок') then
    --             state.fruits.apples= value:match('Стоимость яблок:%s+(.+)%s+')
    --         elseif value:find('апельсинов') then
    --             state.fruits.oranges= value:match('Стоимость апельсинов:%s+(.+)%s+')
    --         elseif value:find('бананов') then
    --             state.fruits.bananas= value:match('Стоимость бананов:%s+(.+)%s+')
    --         end
    --     end
    --     state.fruits.update_at = tmLib.datetime()
    --     local full_car = state.fruits.plums * 250 + state.fruits.apples * 250 + state.fruits.oranges * 250 + state.fruits.bananas * 250
    --     sampSendChat(f('/f Сегодня за полную машину фруктов: %s вирт', tmLib.separatorNumber(full_car)))
    --     saveState()
    --     return true
    -- end
    -- return false
end
local updateFarmInfo
updateFarmInfo = lua_thread.create_suspended(function ()
    while true do
        isAutoOpenFarmInfo = true
        sampSendChat('/finfo')
        wait(60000)
        if tmLib.getDist(zone.farms.x, zone.farms.y, zone.farms.z) > 50 then return end
    end
end)

local updateTreesInfo
updateTreesInfo = lua_thread.create_suspended(function ()
    while true do
        local messages = tmLib.search3Dtext('[Место')
        updateTrees(messages)
        wait(11000)
        if table.len(messages) < 1 then return end
    end
end)

local function init()
    loadState()
    isFarmer =  tmLib.iin(farm_skin_ids, tostring(getCharModel(PLAYER_PED)))
end


function main()
    EXPORTS.TAG_ADDONS = 'ToolsMate'
    EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
    EXPORTS.URL_GET_UPDATE =
    'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BFarmersAssistant%5D.lua'
    EXPORTS.DEPENDENCIES = {
        tmLib.setting,
        ExpansionLua
    }

    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end

    init()

    lua_thread.create(getIdsSkins)
    lua_thread.create(checkingStatus)


    addEventHandler("onWindowMessage", function(msg, wparam, lparam)
        if not sampIsCursorActive() then
            if (msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN) and wparam == vkeys.VK_P then
                renderWindow[0] = not renderWindow[0]
                if not renderWindow[0] then saveState() end
            elseif wparam == vkeys.VK_X then
                if msg == wm.WM_KEYDOWN then
                    showAll = true
                elseif msg == wm.WM_KEYUP then
                    showAll = false
                end
            end
        end

        if wparam == vkeys.VK_ESCAPE and renderWindow[0] then
            consumeWindowMessage(true, true)
            renderWindow[0] = false
        end
    end)

    

    while true do
        if tmLib.getDist(zone.priceFruit.x, zone.priceFruit.y, zone.priceFruit.z) < 100 and tmLib.checkingWithPayday(state.fruits.update_at)  then
            getPriceFruit()
        end

        if tmLib.getDist(zone.farms.x, zone.farms.y, zone.farms.z) < 50 and updateFarmInfo:status() ~= 'yielded' then
            updateFarmInfo:run()
        end

        if renderWindow[0] ~= renderWindowOld then
            if not renderWindow[0] then
                tab = 1
                saveState()
            end
            renderWindowOld = renderWindow[0]
        end
        wait(0)
    end
end

function sampev.onShowDialog(id, style, title, btn1, btn2, text)
    if string.find(title, 'Состав фермы', 1, true) then
        updateMembers(text)
    elseif string.find(title, 'Информация о ферме', 1, true) then
        updateFinfo(text)
        if isAutoOpenFarmInfo then
            isAutoOpenFarmInfo = false
            return false
        end
    elseif string.find(title, 'Работа на ферме', 1, true) then
        if (btn1 == 'Начать') then
            sampSendDialogResponse(id, 1, 0)
            sampCloseCurrentDialogWithButton(0)
            return false
        end
    end
end

function sampev.onSetInterior(interior)
    if interior > 0 then
        lua_thread.create(function()
            wait(5000)
            local messages = tmLib.search3Dtext('[Место')
            if table.len(messages) > 0 and updateTreesInfo:status() ~= 'yielded' then
                updateTreesInfo:run()
           end
        end)
    end
end

function sampev.onServerMessage(_, text)
    -- [18:51:10]  [Ферма]{FFFFFF} Зерновоз Irene_Nishimiya купила у фермы 1000 продукции за 55000 вирт
    -- [18:51:11]  [Ферма]{FFFFFF} Зерновоз Irene_Nishimiya продала ферме 250 семян за 2500 вирт
    -- [Ферма]{FFFFFF} Pater_Neofit разгрузил в амбар фермы 1000 единиц урожая из машины №2
    -- [19:00:06]  [Ферма]{FFFFFF} El_Carton засеял на поле 2000 семян
    -- [Ферма]{FFFFFF} Stephen_Thompson выполнил скашивание комбайном {FFFFFF}(( x2.0 множитель к времени сбора урожая на 2 часа ))


--     [13:12:02]  [Подсказка]{FFFFFF} Используйте отображенную кнопку, находясь на поле, чтобы начать скашивание урожая
-- [13:12:28]  Вы начали скашивание комбайном {FFFFFF}(( Двигайтесь по красным меткам ))
-- [13:13:53]  [Ферма]{FFFFFF} Dima_Maslow выполнил скашивание комбайном {FFFFFF}(( x2.0 множитель к времени сбора 


    -- [Ферма]{FFFFFF} Irene_Nishimiya завершила скашивание травы для хлева
    -- один стог это - 400


    if string.find(text, 'Работа на ферме начата', 1, true) then
        isFarmer = true
    elseif string.find(text, 'Рабочий день на ферме закончен', 1, true) then
        isFarmer = false
    elseif string.find(text, '[Ферма]{FFFFFF} Зерновоз', 1, true) then
        local count, price = text:match('%s(%d+)%s.+%sза (%d+) вирт')
        if not count then return end
        if string.find(text, 'продукции за', 1, true) then
            state.hangar.harvest = state.hangar.harvest - count
            state.hangar.balance = state.hangar.balance + price
        else
            state.hangar.warehouse = state.hangar.warehouse + count
            state.hangar.balance = state.hangar.balance - price
        end
        saveState()
    elseif string.find(text, 'в амбар фермы', 1, true) then
        local count = text:match('в амбар фермы (%d+) единиц урожая из машины')
        if not count then return end
        state.hangar.harvest = state.hangar.harvest + count
        state.hangar.seed = state.hangar.seed - count
        saveState()
    elseif string.find(text, 'на поле', 1, true) then
        local count = text:match('на поле (%d+) семян')
        if not count then return end
        state.hangar.warehouse = state.hangar.warehouse - count
        state.hangar.seed = state.hangar.seed + count
        saveState()
    elseif string.find(text, 'скашивание комбайном', 1, true) then
        state.hangar.speedBooster = os.time() + 2 * 3600
    elseif string.find(text, 'удобрение кукурузником', 1, true) then
        state.hangar.quantityBooster = os.time() + 2 * 3600

    elseif string.find(text, 'котик?', 1, true) then -- TODO: УДалить после
        local my_id = text:match('- Dima_Maslow%[(%d+)%]:')
    if my_id then
        local sms = f('/sms %d мур-мур', my_id)
            lua_thread.create(function ()
                sampSendChat(sms)
                wait(1500)
                sampSendChat('/me мурлычет')
                sampAddChatMessage('Я уберу это со следующим обновлением. Обезаю :D Мило же))', -1)
            end)
    end
  
    end
end
