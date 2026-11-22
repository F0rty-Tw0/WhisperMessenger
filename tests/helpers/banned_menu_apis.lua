-- Spies on every Blizzard menu entry point that taints when addon code
-- calls it. With(fn) runs fn(calls); calls lists "<Global>" or
-- "<Table>.<field>" per call. Every global is restored afterwards.
local BannedMenuApis = {}

local BANNED_FUNCTIONS = {
  "UnitPopup_OpenMenu",
  "EasyMenu",
  "ToggleDropDownMenu",
  "UIDropDownMenu_Initialize",
  "UIDropDownMenu_CreateInfo",
  "UIDropDownMenu_AddButton",
  "FriendsFrame_ShowDropdown",
  "FriendsFrame_ShowBNDropdown",
  "SetItemRef",
}
local BANNED_TABLES = { "MenuUtil", "ChatFrameMixin", "Menu" }

-- Reading the open menu is allowed (PopupEscape.ReportMenuShown).
local QUIET_MANAGER = {
  GetOpenMenu = function()
    return nil
  end,
}

local function recorder(calls, name)
  return function()
    table.insert(calls, name)
  end
end

-- Every field is a recording function, so type(x.Field) == "function" guards pass.
local function spyTable(calls, tableName)
  return setmetatable({}, {
    __index = function(_spy, field)
      if tableName == "Menu" and field == "GetManager" then
        return function()
          return QUIET_MANAGER
        end
      end
      return recorder(calls, tableName .. "." .. tostring(field))
    end,
  })
end

function BannedMenuApis.With(fn)
  local saved = {}
  local calls = {}
  for _, name in ipairs(BANNED_FUNCTIONS) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, recorder(calls, name))
  end
  for _, name in ipairs(BANNED_TABLES) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, spyTable(calls, name))
  end
  local ok, err = pcall(fn, calls)
  for _, name in ipairs(BANNED_FUNCTIONS) do
    rawset(_G, name, saved[name])
  end
  for _, name in ipairs(BANNED_TABLES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return BannedMenuApis
