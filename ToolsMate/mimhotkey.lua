require('lib.moonloader')
local imgui = require('mimgui')
local vk = require 'vkeys'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

HOTKEY = {
    no_flood = true,
    lastkey = 9999,
    MODULEINFO = {
        version = 2,
        author = 'chapo'
    },
    Text = {
        wait_for_key = 'Ожидание соченатия...',
        no_key = 'None'
    },
    List = {},
    EditKey = nil,
    Edit = {
        backup = {},
        new = {}
    },
    Ret = {name = nil, data = {}},
    setting = {
        name = 'tm-mimhotkey',
        url_script = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/mimhotkey.lua',
        urp_version = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json',
        version = "1.0.0",
        path_script = getWorkingDirectory() .. '\\ToolsMate\\mimhotkey.lua',
        tag = 'ToolsMate'
    }
}

local LargeKeys = {
    VK_SHIFT,
    VK_SPACE,
    VK_CONTROL,
    VK_LMENU,
    VK_RETURN
}

addEventHandler('onWindowMessage', function(msg, key)
    if msg == 0x0100 --[[ WM_KEYDOWN ]] then
        if HOTKEY.EditKey == nil then
            if (HOTKEY.no_flood and key ~= HOTKEY.lastkey) or (not HOTKEY.no_flood) then
                HOTKEY.lastkey = key
                for name, data in pairs(HOTKEY.List) do
                    keys = data.keys
                    if (#keys == 1 and key == keys[1]) or (#keys == 2 and isKeyDown(keys[1]) and key == keys[2]) then
                        data.callback(name)
                    end
                end
            end
            if HOTKEY.EditKey ~= nil then
                if #HOTKEY.List[HOTKEY.EditKey] < 2 then
                    table.insert(HOTKEY.List[HOTKEY.EditKey], key)
                end
            end
        else
            if key == VK_ESCAPE then
                HOTKEY.List[HOTKEY.EditKey].keys = HOTKEY.Edit.backup
                HOTKEY.EditKey = nil
                consumeWindowMessage(true, true)
            elseif key == VK_BACK then
                HOTKEY.List[HOTKEY.EditKey].keys = {}
                HOTKEY.EditKey = nil
                consumeWindowMessage(true, true)
            end
        end        
    elseif msg == 0x0101 --[[ WM_KEYUP ]] then
        if HOTKEY.EditKey ~= nil and key ~= VK_LMENU then
            if key == VK_BACK then
                HOTKEY.List[HOTKEY.EditKey].keys = {}
                HOTKEY.EditKey = nil
            else
                local PressKey = getDownKeys()
                local LargeKey = PressKey[#PressKey]
                HOTKEY.List[HOTKEY.EditKey].keys = {#PressKey > 0 and PressKey[#PressKey] or key, #PressKey > 0 and key or nil}
                if HOTKEY.List[HOTKEY.EditKey].keys[1] == HOTKEY.List[HOTKEY.EditKey].keys[2] then
                    HOTKEY.List[HOTKEY.EditKey].keys[2] = nil
                end
                HOTKEY.Ret.name = HOTKEY.EditKey
                HOTKEY.Ret.data = HOTKEY.List[HOTKEY.EditKey].keys
                HOTKEY.EditKey = nil
            end
        end
    end
end)

getDownKeys = function()
    local t = {}
    for index, KEYID in ipairs(LargeKeys) do
        if isKeyDown(KEYID) then
            table.insert(t, KEYID)
        end
    end
    return t
end

HOTKEY.GetBindKeys = function(bind)
    local keys = {}
    local t = {}
    if type(bind) == 'string' then
        if HOTKEY.List[bind] then
            keys = HOTKEY.List[bind].keys
        else
            return 'BIND NOT FOUND'
        end
    elseif type(bind) == 'table' then
        keys = bind
    else
        return 'INCORRECT DATA TYPE'
    end

    for k, v in ipairs(keys) do
        table.insert(t, vk.id_to_name(v) or 'UNK')
    end
    return table.concat(t, ' + ')
end

HOTKEY.GetKeysText = function(bind)
    local t = {}
    if HOTKEY.List[bind] then
        for k, v in ipairs(HOTKEY.List[bind].keys) do
            table.insert(t, vk.id_to_name(v) or 'UNK')
        end
    end
    return table.concat(t, ' + ')
end

HOTKEY.GetHotkeyKeys = function(name)
    return {HOTKEY.List[name].keys == nil and 'bind not found' or HOTKEY.GetKeysText(name)}
end

HOTKEY.RegisterCallback = function(name, keys, callback)
    if HOTKEY.List[name] == nil then
        HOTKEY.List[name] = {
            keys = keys,
            callback = callback
        }
        return true, 'vse zaebis, mojno najimat knopo4ku!'
    else
        return false, 'error, hotkey '..name..' already registred'
    end
end

--HOTKEY.KeyEditCallback

HOTKEY.KeyEditor = function(bindname, text, size)
    if HOTKEY.List[bindname] then
        local keystext = #HOTKEY.List[bindname].keys == 0 and HOTKEY.Text.no_key or HOTKEY.GetKeysText(bindname)--table.concat(HOTKEY.List[bindname].keys, ' + ')--
        if HOTKEY.EditKey ~= nil then
            if HOTKEY.EditKey == bindname then
                keystext = u8(HOTKEY.Text.wait_for_key)
            end
        end 
        if imgui.Button((text ~= nil and text..': ' or '')..keystext..'##HOTKEY_EDITOR:'..bindname, size) then
            HOTKEY.Edit.backup = HOTKEY.List[bindname].keys
            HOTKEY.List[bindname].keys = {}
            HOTKEY.EditKey = bindname
        end
        if HOTKEY.Ret.name ~= nil then
            if HOTKEY.Ret.name == bindname then
                HOTKEY.Ret.name = nil
                return HOTKEY.Ret.data
            end
        end
    else
        imgui.Button('Bind "'..tostring(bindname)..'" not found##HOTKEY_EDITOR:BINDNAMENOTFOUND', size)
    end
end

return HOTKEY