require 'ToolsMate.expansion'
local tmLib = require 'ToolsMate.lib'

PersonVersion = {
    name = 'tm-classe-Person',
    url_script = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/ToolsMate/Classes/Person.lua',
    urp_version = 'https://raw.githubusercontent.com/DIMaslov1904/ToolsMate/main/version.json',
    version = "1.0.1",
    path_script = getWorkingDirectory() .. '\\ToolsMate\\Classes\\Person.lua',
    tag = 'ToolsMate'
}


Person = {}
function Person:new(name)
    local obj = {
        ---@type string
        name = name or "��� �� ������",
        ---@type integer | nil
        id = tmLib.getIdByNick(name),
        sorting = 100
    }

    ---@type boolean
    obj.isOnline = obj.id ~= nil

    ---@type string
    obj.clist = tmLib.getUserColor(obj.id)

    setmetatable(obj, self)
    self.__index = self; return obj
end

-- ���������� ����� ������
function Person:UpdateClist()
    if self.isOnline then
        self.clist = tmLib.getUserColor(self.id)
    elseif self.clist ~= 'FFFFFF' then
        self.clist = 'FFFFFF'
    end
end

-- ���������� ����������
function Person:Update() --> nil
    self.id = tmLib.getIdByNick(self.name)
    self.isOnline = self.id ~= nil
    self:UpdateClist()
end



PersonList = {}

function PersonList:new(persons)
    local obj = {
    ---@type table
    list = type(persons) == 'table' and persons or {},
    listOnline = {}
    }

    setmetatable(obj, self)
    self.__index = self; return obj
end

PersonList.child = Person
PersonList.onlineCount = 0
PersonList.count = 0

-- ���������� ��������� �������
function PersonList:Update()
    self.listOnline = {}
    self.onlineCount = 0
    for _, person in pairs(self.list) do
        person:Update()
        if person.isOnline then
            table.insert(self.listOnline, person)
        end
    end
    self.onlineCount = #self.listOnline
end

-- ������������� ������� �� ������ nickname
function PersonList:Initial(members)
    self.count = 0
    if not members then return {status='error', message='�� ������� ������ �������������!'} end
    for _, nickname in pairs(members) do
        self.count = self.count + 1
        table.insert(self.list, self.child:new(nickname))
    end
    return {status='ok'}
end

-- ��������� �������� �� nickname
function PersonList:GetPerson(name)
    for _, person in pairs(self.list) do
        if person.name == name then
            person:Update()
            return person
        end
    end
    return nil
end

-- ���������� ������ �������� �� nickname ��� id
function PersonList:AddPerson(arg)
    if not arg then return {status='error', message='�� �������� ���/id!'} end
    local name = arg
    if type(arg) == 'number' then
        if not sampIsPlayerConnected(arg) then return {status='error', message='�� ������� id ����� �� ������!'} end
        name = sampGetPlayerNickname(arg)
    end
    table.insert(self.list, self.child:new(name))
    self.count = self.count + 1
    return {status='ok'}
end

-- ������� �������� �� nickname
function PersonList:removePerson(name)
    for i, data in pairs(self.list) do
        if data.name == name then
            table.remove(self.list, i)
            self.count = self.count - 1
            return {status='ok'}
        end
    end
    return {status='error', message='�� ������� ����� �� ������ ����� � ������'}
end

function PersonList:SortingList()
    table.sort(self.list, function (a, b)
        return a.sorting < b.sorting
    end)
end
