script_name('ToolsMate[Updater]')
script_author('DIMaslov1904')
script_version("0.9.6")
script_url("https://t.me/ToolsMate")
script_description('Автообновление скриптов.')


-- Зависимости
local dlstatus = require('moonloader').download_status


-- Сокращения
local f = string.format
local c = table.concat
local b = function(...) -- Конкагинация строк
    local arg = { ... }
    local r = {}
    for _, v in pairs(arg) do r[#r + 1] = tostring(v) end
    return c(r, "")
end
local def = function(fn, ...) -- Создание функции с опр. аргументами, без её вызова
    local arg = { ... }
    return function(...)
        local new_arg = { ... }
        for _ in pairs(new_arg) do return fn(table.unpack(new_arg)) end
        return fn(table.unpack(arg))
    end
end

local flowDef = function(fn, ...)
    local arg = { ... }
    return function(...)
        local new_arg = { ... }
        for _ in pairs(new_arg) do return fn:run(table.unpack(new_arg)) end
        return fn:run(table.unpack(arg))
    end
end

local function newSampAddChatMessage(...)
    local arg = { ... }
    if not isSampLoaded() or not isSampfuncsLoaded() or not isSampAvailable() then return end
    sampAddChatMessage(table.unpack(arg))
end


-- Переменные
local comamnd = 'updater'
local config_file_name = c({ getWorkingDirectory(), b('ToolsMate\\Updater\\', script.this.name, '.json') }, '\\')
local update_path = getWorkingDirectory() .. '\\ToolsMate\\Updater\\'
local is_updates = false -- есть есть обновления
local state = {
    autoCheck = true,    -- Авто проверка
    autoDownload = true, -- Авто обновление
    unload = false,      -- Выгружаться после проверки
    libs = {},           -- Список всех скриптов
    urlsCheck = {}       -- Ссылки на проверку обновлений
}
local color = {
    successes = 0xCED23A,
    warning   = 0xFFB841,
    errors    = 0xD87093,
}
local MESSAGES = {
    on                     = f('{%06X}включено', color.successes),
    off                    = f('{%06X}выключено', color.errors),
    analysis               = 'Анализ установленных скриптов...',
    checking_updates       = 'Идёт прововерка обновлений...',
    no_update_url          = 'не удалось обновить. Разработчик не добавил ссылку для обновления',
    downloading_updates    = 'Идёт скачивание обновлений...',
    download_completed     = '- Загрузка завершена',
    download_error         = 'ошибка загрузки',
    new_version            = '- вышла новая версия:',
    current_version        = '| Текущая:',
    verification_completed = 'Проверка завершена!',
    no_updates             = 'Все доступные скрипты обновлены!',
    unload                 = 'выгрузка',
    handler_check          = 'проверить обновления (опц. имя скрипта)',
    handler_get            = 'обновить скрипт (название можно писать через пробел)',
    handler_autoCheck      = 'переключить автопроверку обновлений (вкл/выкл)',
    handler_autoDownload   = 'переключить автозагрузку обновлений (вкл/выкл)',
    handler_unload         = 'переключить выгрузку скрипта, после обновления (вкл/выкл)',
    no_script_name         = 'не передано название скрипта',
    no_search              = '- не найден',
    no_auto_update         = '- данный скрипт требует отдельного обновления вручуню',
    for_update             = f('Для обдновления введите /%s get ', comamnd),
    update_instructions    = {
        'Автообновление скриптов отключено',
        'Для обновления используйте команду:',
        f('/%s get script_name', comamnd)
    }
}


-- Функции
local function onoff(v)
    return v and MESSAGES.on or MESSAGES.off
end

local function checkingPath(path)
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

-- Работа с json
local function json(directory)
    checkingPath(directory)
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

-- Сохранение конфигурации
local function save_state()
    local save_state = {
        autoCheck = state.autoCheck,
        autoDownload = state.autoDownload,
        unload = state.unload
    }
    json(config_file_name):Save(save_state)
end

-- Загрузка конфигурации
local function load_state()
    local save_state = {
        autoCheck = state.autoCheck,
        autoDownload = state.autoDownload,
        unload = state.unload
    }
    state = json(config_file_name):Load(save_state)
end

-- Добавление установленных скриптов
local function browseScripts()
    state.libs = {}
    state.urlsCheck = {}

    for _, s in pairs(script.list()) do
        table.insert(state.libs, {
            name = s.name,
            version = s.version,
            path = s.path,
            noAutoUpdate = s.exports and s.exports.NO_AUTO_UPDATE or nil,
            urlCheckUpdate = s.exports and s.exports.URL_CHECK_UPDATE or nil,
            urlGetUpdate = s.exports and s.exports.URL_GET_UPDATE or nil,
            tag = s.exports and s.exports.TAG_ADDONS or nil,
            script = s
        })
        if s.exports then
            if s.exports.URL_CHECK_UPDATE then
                if (s.exports.TAG_ADDONS and not state.urlsCheck[s.exports.TAG_ADDONS]) then
                    state.urlsCheck[s.exports.TAG_ADDONS] = s.exports.URL_CHECK_UPDATE
                elseif not s.exports.TAG_ADDONS then
                    state.urlsCheck[s.name] = s.exports.URL_CHECK_UPDATE
                end
            end

            if s.exports.DEPENDENCIES then
                for _, item in pairs(s.exports.DEPENDENCIES) do
                    table.insert(state.libs, {
                        name = item.name,
                        version = item.version,
                        path = item.path_script,
                        urlCheckUpdate = item.urp_version or nil,
                        urlGetUpdate = item.url_script or nil,
                        noAutoUpdate = nil,
                        tag = item.tag or nil,
                        script = nil
                    })
                    state.urlsCheck[item.name] = item.urp_version
                end
            end
        end
    end
end

-- Обновление скриптов
local flowGet = lua_thread.create_suspended(function(name)
    if not name then
        newSampAddChatMessage(c({ script.this.name, MESSAGES.no_script_name }, ' '), color.errors)
        return
    end
    local directory, url, select_script, found, noAutoUpdate

    for _, lib in pairs(state.libs) do
        if lib.name == name then
            found = true
            if lib.urlGetUpdate then
                directory = lib.path
                url = lib.urlGetUpdate
                noAutoUpdate = lib.noAutoUpdate
                select_script = lib.script
            else
                newSampAddChatMessage(c({ name, MESSAGES.no_update_url }, ' '), color.errors)
            end
            break
        end
    end
    if noAutoUpdate then
        if script.this.name == name then
            lua_thread.create(function()
                wait(10000)
            end)
        else
            newSampAddChatMessage(c({ script.this.name, name, MESSAGES.no_auto_update }, ' '), color.warning)
            newSampAddChatMessage(c({ script.this.name, MESSAGES.for_update, name }, ' '), color.warning)
            return
        end
    end
    if not found then newSampAddChatMessage(c({ script.this.name, name, MESSAGES.no_search }, ' '), color.errors) end
    if not url then return end

    print(MESSAGES.downloading_updates)
    local loading, end_download = true, false

    if select_script then select_script:pause() end

    wait(1000)

    downloadUrlToFile(url, directory, function(id, status)
        if status == 6 then end_download = true end
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            print(c({ directory, MESSAGES.download_completed }, ' '))
            -- newSampAddChatMessage(c({ script.this.name, name, MESSAGES.download_completed }, ' '), color.warning)
            if select_script then select_script:reload() end
            loading = false
        end
    end)

    while loading do wait(500) end
    if not end_download then newSampAddChatMessage(c({ name, MESSAGES.download_error }, ' '), color.errors) end
end)

-- Сравнение текстовых версий
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

-- Проверка версий
local compareVersions = lua_thread.create_suspended(function(directory)
    local versions_json = json(directory):Load({})

    for lib_name, val in pairs(versions_json) do
        for _, lib in pairs(state.libs) do
            if lib.name == lib_name and compareVersion(lib.version, val.version) then
                local text_message = c(
                    { lib_name, MESSAGES.new_version, val.version, MESSAGES.current_version, lib.version }, ' ')
                print(text_message)
                is_updates = true
                flowGet:run(lib_name)
                while flowGet:status() ~= 'dead' do wait(1000) end
            end
        end
    end
end)

-- Загрузка сверщиков версий
local flowRequestCheck = lua_thread.create_suspended(function(name, url)
    local directory = b(update_path, name, '.json')
    local loading, end_download = true, false

    downloadUrlToFile(url, directory, function(id, status)
        if status == 6 then end_download = true end
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            print(c({ directory, MESSAGES.download_completed }, ' '))
            loading = false
        end
    end)
    while loading do wait(500) end

    compareVersions:run(directory)
    while compareVersions:status() ~= 'dead' do wait(1000) end


    if not end_download then
        newSampAddChatMessage(c({ name, MESSAGES.download_error }, ' '), color.errors)
    end
end)

-- Проверка обновлений
local function check(arg)
    local lib_name = type(arg) == "string" and arg or false
    local show_message = arg == 1
    local lib
    for _, v in pairs(state.libs) do if v.name == lib_name then lib = v end end
    lua_thread.create(function()
        print(MESSAGES.checking_updates)
        if show_message then newSampAddChatMessage(c({ script.this.name, MESSAGES.checking_updates }, ' '), color
            .warning) end

        if lib then
            flowRequestCheck:run(lib.name, lib.urlCheckUpdate)
            while flowRequestCheck:status() ~= 'dead' do wait(1000) end
        else
            for name, url in pairs(state.urlsCheck) do
                if not lib_name or name == lib_name then
                    flowRequestCheck:run(name, url)
                    while flowRequestCheck:status() ~= 'dead' do wait(1000) end
                end
            end
        end

        if not lib and lib_name then
            newSampAddChatMessage(c({ script.this.name, lib_name, MESSAGES.no_search }, ' '),
                color.errors)
        end

        print(MESSAGES.verification_completed)
        if show_message then
            newSampAddChatMessage(c({ script.this.name, MESSAGES.verification_completed }, ' '),
                color.warning)
        end

        if is_updates then
            if state.autoDownload then
                print(MESSAGES.no_updates)
            elseif not lib_name then
                for _, mess in ipairs(MESSAGES.update_instructions) do newSampAddChatMessage(mess, color.warning) end
            else
                newSampAddChatMessage(b(MESSAGES.for_update, lib_name), color.warning)
            end
        end
        is_updates = false
    end)
end

-- Изменение конфигурации
local function changeState(parameter)
    state[parameter] = not state[parameter]
    save_state()
    newSampAddChatMessage(c({ script.this.name, MESSAGES[parameter], onoff(state[parameter]) }, ' '), color.warning)
end

-- Обработчик команд
local function handler(arg)
    local fn, lib
    for str in arg:gmatch("([^%s]+)") do
        if not fn then
            fn = str
        elseif not lib then
            lib = str
        else
            lib = b(lib, ' ', str)
        end
    end

    local handlers = {
        {
            arg = 'check',
            name = MESSAGES.handler_check,
            collback = def(check, 1)
        },
        {
            arg = 'get',
            help = 'script_name',
            name = MESSAGES.handler_get,
            collback = flowDef(flowGet)
        },
        {
            arg = 'autoCheck',
            name = MESSAGES.handler_autoCheck,
            collback = def(changeState, 'autoCheck')
        },
        {
            arg = 'autoDownload',
            name = MESSAGES.handler_autoDownload,
            collback = def(changeState, 'autoDownload')
        },
        {
            arg = 'unload',
            name = MESSAGES.handler_unload,
            collback = def(changeState, 'unload')
        },
    }

    for _, hand in pairs(handlers) do if hand.arg == fn then return hand.collback(lib) end end
    for _, hand in pairs(handlers) do
        newSampAddChatMessage(
            f('%s -> {FFCF40}/%s %s %s{FFFFFF} - %s', script.this.name, comamnd, hand.arg, hand.help or '', hand.name),
            -1)
    end
end

-- Первые задачки
local function run()
    load_state()
    browseScripts()
    checkingPath(update_path)
end


--Ручное скачивание файла
local download = lua_thread.create_suspended(function(item)
    checkingPath(update_path)
    checkingPath(item.path_script)

    table.insert(state.libs, {
        name = item.name,
        path = item.path_script,
        urlGetUpdate = item.url_script or nil,
        noAutoUpdate = nil,
        tag = item.tag or nil,
        script = nil
    })

    flowGet:run(item.name)
    while flowGet:status() ~= 'dead' do wait(1000) end
end)


-- База
function main()
    EXPORTS.TAG_ADDONS = 'ToolsMate'
    EXPORTS.NAME_ADDONS = 'Обновление'
    EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
    EXPORTS.URL_GET_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BUpdater%5D.lua'

    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    run()

    sampRegisterChatCommand(comamnd, handler)

    wait(2000)
    check()
end

return {
    download = download,
}
