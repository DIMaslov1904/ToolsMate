ExpansionLua = {
  name = 'tm-expansion',
  url_script = '',
  urp_version = '',
  version = "0.1.0",
  path_script = getWorkingDirectory() .. '\\ToolsMate\\expansion.lua'
}

-- Форматирование строк
f = string.format
-- Аналог join из питона
c = table.concat
-- Конкагинация строк
function b(...)
  local arg = { ... }
  local r = {}
  for _, v in pairs(arg) do r[#r + 1] = tostring(v) end
  return c(r, "")
end

-- Создание функции с опр. аргументами, без её вызова
function Def(fn, ...)
  local arg = { ... }
  return function(...)
    local new_arg = { ... }
    for _ in pairs(new_arg) do return fn(table.unpack(new_arg)) end
    return fn(table.unpack(arg))
  end
end

-- Создание асинхронную функции с опр. аргументами, без её вызова
function FlowDef(fn, ...)
  local arg = { ... }
  return function(...)
    local new_arg = { ... }
    for _ in pairs(new_arg) do return fn:run(table.unpack(new_arg)) end
    return fn:run(table.unpack(arg))
  end
end

-- Копирование таблицы
table.copy = function(obj)
  if type(obj) ~= 'table' then return obj end
  local res = {}
  for k, v in pairs(obj) do res[table.copy(k)] = table.copy(v) end
  return res
end

-- Количество элементов в таблице
table.len = function(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

-- Улучшенный print
local print_orig = print
function print(...)
  local args = { ... }
  function table.val_to_str(v)
    if "string" == type(v) then
      v = string.gsub(v, "\n", "\\n")
      if string.match(string.gsub(v, "[^'\"]", ""), '^"+$') then
        return "'" .. v .. "'"
      end
      return '"' .. string.gsub(v, '"', '\\"') .. '"'
    else
      return "table" == type(v) and table.tostring(v) or tostring(v)
    end
  end

  function table.key_to_str(k)
    if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
      return k
    else
      return "[" .. table.val_to_str(k) .. "]"
    end
  end

  function table.tostring(tbl)
    local result, done = {}, {}
    for k, v in ipairs(tbl) do
      table.insert(result, table.val_to_str(v))
      done[k] = true
    end
    for k, v in pairs(tbl) do
      if not done[k] then
        table.insert(result, table.key_to_str(k) .. "=" .. table.val_to_str(v))
      end
    end
    return "{" .. c(result, ",") .. "}"
  end

  for i, arg in ipairs(args) do
    if type(arg) == "table" then
      args[i] = table.tostring(arg)
    end
  end
  print_orig(table.unpack(args))
end
