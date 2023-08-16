script_name('ToolsMate[AdBlock]')
script_author('DIMaslov1904')
script_version("1.1.1")
script_url("https://github.com/DIMaslov1904/ToolsMate")
script_description('���������� ������ � ��� ��������� ���������.')


-- ����������
local on = true     -- ��������� �� ���������
local messages = {  -- ��� ������� ������ ���� - ��������� �� ��������� � ���
  '����������:',
  '�������� News',
  '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',
  '������� ��� ������ � ��������� ������� - /ask',
  '��� ������������ ��� ���������� �� ������ �������� �� ����� - samp-rp.ru',
  '������� ������ � ������� �� ������������ ����� Samp RolePlay - /music',
}


function main()
  -- �����������
  if not isSampLoaded() or not isSampfuncsLoaded() then return end
  while not isSampAvailable() do wait(0) end

  local isSampev, sampev = xpcall(require, function ()
      sampAddChatMessage(script.this.name..' ��������. ���������� [SAMP.Lua] �� �����������!', 0xD87093)
      thisScript():unload()
    end, 'samp.events')
  if not isSampev then return end


  -- ���������� � ToolsMate
  EXPORTS.TAG_ADDONS = 'ToolsMate'
  EXPORTS.NAME_ADDONS = 'AdBlock'
  EXPORTS.URL_CHECK_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json'
  EXPORTS.URL_GET_UPDATE = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate%5BAdBlock%5D.lua'

  
  local function ads()
    local isNotify, notify = pcall(import, ('ToolsMate'))
    on = not on
    local message = ('{%s}AdBlock. ���������� %s!'):format(on and '00FF00' or 'FF0000', on and '��������' or '���������')
    if isNotify then notify.addNotify( message, 5)
    else sampAddChatMessage(message, 0xFF0000) end
  end

  EXPORTS.run = ads

  function sampev.onServerMessage(_, text)
    if on==true then for _, mess in ipairs(messages) do
      if string.find (text,mess,1,true) then return false end
    end end
  end

  sampRegisterChatCommand("adb", ads)
end
