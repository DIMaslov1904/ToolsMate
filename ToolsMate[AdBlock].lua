script_name('ToolsMate[AdBlock]')
script_author('DIMaslov1904')
script_version("1.1.0")
script_url("https://github.com/DIMaslov1904/ToolsMate")
script_description('Блокировка вывода в чат указанных сообщений.')


-- Переменные
local on = true     -- состояние по умолчанию
local messages = {  -- при наличии данных фраз - сообщение не выводится в чат
  'Объявление:',
  'Редакция News',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
  'Задайте ваш вопрос в поддержку сервера - /ask',
  'Всю интересующую вас информацию вы можете получить на сайте - samp-rp.ru',
  'Играйте вместе с музыкой от официального радио Samp RolePlay - /music',
}


function main()
  -- Зависимости
  if not isSampLoaded() or not isSampfuncsLoaded() then return end
  while not isSampAvailable() do wait(0) end

  local isSampev, sampev = xpcall(require, function ()
      sampAddChatMessage(script.this.name..' выгружен. Библиотеки [SAMP.Lua] не установлены!', 0xD87093)
      thisScript():unload()
    end, 'samp.events')
  if not isSampev then return end


  -- Интеграция с ToolsMate
  EXPORTS.TAG_ADDONS = 'ToolsMate'
  EXPORTS.NAME_ADDONS = 'AdBlock'
  EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
  EXPORTS.URL_GET_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BAdBlock%5D.lua'
  EXPORTS.run = ads


  local function ads()
    local isNotify, notify = pcall(import, ('ToolsMate'))
    on = not on
    local message = ('{%s}AdBlock. Блокировка %s!'):format(on and '00FF00' or 'FF0000', on and 'включёна' or 'выключена')
    if isNotify then notify.addNotify( message, 5)
    else sampAddChatMessage(message, 0xFF0000) end
  end

  function sampev.onServerMessage(_, text)
    if on==true then for _, mess in ipairs(messages) do
      if string.find (text,mess,1,true) then return false end
    end end
  end

  sampRegisterChatCommand("adb", ads)
end
