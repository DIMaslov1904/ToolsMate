script_name('ToolsMate[AdBlock]')
script_author('DIMaslov1904')
script_version("1.0.0")
script_url("https://t.me/ToolsMate")
script_description('Блокировка вывода в чат указанных сообщений.')


-- Зависимости
local isSampev, sampev = pcall(require, 'samp.events')

if not isSampev then
  sampAddChatMessage(script.this.name..' выгружен. Библиотеки [SAMP.Lua] не установлены!', 0xD87093)
  thisScript():unload()
  return
end


-- Переменные
local toggle = true
local messages = {
  'Объявление:',
  'Редакция News',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
  'Задайте ваш вопрос в поддержку сервера - /ask',
  'Всю интересующую вас информацию вы можете получить на сайте - samp-rp.ru',
  'Играйте вместе с музыкой от официального радио Samp RolePlay - /music',
}


-- Функции
local function ads()
  local isNotify, notify = pcall(import, ('ToolsMate'))
  if toggle==true then
    toggle=false
    if isNotify then notify.addNotify( "{FF0000}AdBlock. Блокировка выключена!", 5)
    else sampAddChatMessage('AdBlock. Блокировка выключена!', 0xFF0000) end
  else
    toggle=true
    if isNotify then notify.addNotify("{00FF00}AdBlock. Блокировка включёна!", 5)
    else sampAddChatMessage('AdBlock. Блокировка включёна!', 0x00FF00) end
  end
end


-- База
function main()
  EXPORTS.TAG_ADDONS = 'ToolsMate'
  EXPORTS.NAME_ADDONS = 'AdBlock'
  EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
  EXPORTS.URL_GET_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BAdBlock%5D.lua'
  EXPORTS.run = ads

  if not isSampLoaded() or not isSampfuncsLoaded() then return end
  while not isSampAvailable() do wait(0) end
  function sampev.onServerMessage(_, text)
    if toggle==true then
      for _, mess in ipairs(messages) do
        if  string.find (text,mess,1,true) then
          return false
        end
      end
    end
  end
  sampRegisterChatCommand("adb", ads)
end
