-- On WoW: Forever every Blizzard menu taints from addon code, so even under
-- the Native WoW HUD the settings dropdowns build WhisperMessenger's own
-- list. Other flavors keep the game's dropdown under the Native look.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Flavor = require("tests.helpers.flavor")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local NativeDropdown = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.NativeDropdown")

local DROPDOWN_TEMPLATE = "WowStyle1DropdownTemplate"

local OPTIONS = {
  { key = "default", label = "Default" },
  { key = "open_sans", label = "Open Sans" },
  { key = "morpheus", label = "Morpheus" },
}

-- Every Blizzard menu entry point WhisperMessenger must avoid on Forever.
-- Table globals record any field read.
local BANNED_TABLES = { "MenuUtil", "Menu" }
local BANNED_FUNCTIONS = {
  "UnitPopup_OpenMenu",
  "UIDropDownMenu_Initialize",
  "UIDropDownMenu_AddButton",
  "UIDropDownMenu_CreateInfo",
  "ToggleDropDownMenu",
  "FriendsFrame_ShowDropdown",
  "FriendsFrame_ShowBNDropdown",
  "SetItemRef",
}

local function withBannedSpies(fn)
  local touched = {}
  local saved = {}
  for _, name in ipairs(BANNED_TABLES) do
    saved[name] = rawget(_G, name)
    rawset(
      _G,
      name,
      setmetatable({}, {
        __index = function(_, key)
          touched[#touched + 1] = name .. "." .. tostring(key)
          return function() end
        end,
      })
    )
  end
  for _, name in ipairs(BANNED_FUNCTIONS) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, function()
      touched[#touched + 1] = name
    end)
  end
  local ok, err = pcall(fn, touched)
  for _, name in ipairs(BANNED_TABLES) do
    rawset(_G, name, saved[name])
  end
  for _, name in ipairs(BANNED_FUNCTIONS) do
    rawset(_G, name, saved[name])
  end
  if not ok then
    error(err, 0)
  end
end

-- Just the DropdownButton methods production calls, so a missing gate
-- visibly builds the Blizzard dropdown.
local function dropdownFactory()
  local base = FakeUI.NewFactory()
  return {
    CreateFrame = function(frameType, name, parent, template)
      local frame = base.CreateFrame(frameType, name, parent, template)
      if template == DROPDOWN_TEMPLATE then
        function frame:SetupMenu(generator)
          self.generator = generator
        end
        function frame:GenerateMenu() end
      end
      return frame
    end,
  }
end

-- Builds the Font Family dropdown under the Native look on the given flavor;
-- `keepHud` leaves the Native look on for the caller.
local function buildIn(isForever, keepHud)
  local factory = dropdownFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local dropdown
  Flavor.With(true, isForever, function()
    Hud.Configure("classic")
    dropdown = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      optionsList = OPTIONS,
      fallbackKey = "default",
      initial = "open_sans",
      onChange = function(key)
        changes[#changes + 1] = key
      end,
    })
    if not keepHud then
      Hud.Configure("off")
    end
  end)
  return dropdown, changes
end

return function()
  -- test_forever_native_look_builds_the_wm_dropdown
  do
    local dd = buildIn(true)
    assert(dd.button.template == nil, "Forever: WM dropdown, got " .. tostring(dd.button.template))
    assert(FindUI.dropdownMenu(dd.row) ~= nil, "Forever: WM's own menu list")
    assert(FindUI.find(dd.row, function(n)
      return n.template == DROPDOWN_TEMPLATE
    end) == nil, "no Blizzard dropdown frame built")
  end

  -- test_forever_dropdown_open_and_pick_touch_no_blizzard_menu
  do
    withBannedSpies(function(touched)
      Flavor.With(true, true, function()
        local dd, changes = buildIn(true, true)
        FindUI.click(dd.button)
        FindUI.click(FindUI.dropdownOptions(dd.row)[3])
        assert(changes[1] == "morpheus" and dd.button.label.text == "Morpheus", "pick works")
      end)
      Hud.Configure("off")
      assert(#touched == 0, "banned Blizzard menu API touched: " .. table.concat(touched, ","))
    end)
  end

  -- test_forever_native_dropdown_create_returns_nil
  do
    local factory = dropdownFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local handle
    Flavor.With(true, true, function()
      Hud.Configure("classic")
      handle = NativeDropdown.Create(factory, parent, { optionsList = OPTIONS })
      Hud.Configure("off")
    end)
    assert(handle == nil, "Forever + Native look: NativeDropdown.Create is nil")
  end

  -- test_retail_native_look_keeps_the_blizzard_dropdown
  do
    assert(buildIn(false).button.template == DROPDOWN_TEMPLATE, "Retail + Native look keeps the Blizzard dropdown")
  end
end
