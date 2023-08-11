--[[
    Библиотеки от которых зависит ваш скрипт, пакеты скрипта и т.д. в порядке зависимости
    От более глобавльных до вашего скрипта
--]]

local packages = {
    {
        name = 'ToolsMate[Updater].lua',
        url = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BUpdater%5D.lua'
    }
}

local script_name = 'ToolsMate[Updater]'

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    local succsess = true
    local function checkingPath(path)
        local fullPath = 'moonloader/'
        for part in string.gmatch(path, "([^/]+)/") do
            fullPath = fullPath..part..'/'
            local ok, err, code = os.rename(fullPath, fullPath)
            if code == 2 then createDirectory(fullPath)
            elseif not ok then print('{77DDE7}'..path..'{FFCC00} не установлен!\n {FFCC00}Ошибка создание каталога: '..err) return false end
        end return true
    end
    local function downloadPackage(lib_url, lib_name)
        if not checkingPath(lib_name) then return false end
        local loading, end_download, path = true, false, getWorkingDirectory().. '/'..lib_name
        downloadUrlToFile(lib_url, path, function(id, status, p1, p2)
            if  status == 6 then end_download = true end
            if  status == 58 then loading = false end
        end)
        while loading do wait(1000) end return end_download
    end
    for _, lib in pairs(packages) do if not pcall(import, lib.name) and not downloadPackage(lib.url, lib.name) then
        print('{77DDE7}'..lib.name..'{FFCC00} не установлен!\n {FFCC00}Ошибка загрузки файла')
        succsess = false
    end end
    if succsess then
        os.remove(script.this.path)
        sampAddChatMessage(script_name..'{FFB841} установлен!', 0x77DDE7)
        if not pcall(import, script_name) then reloadScripts() end
    end
    script.this:unload()
end
