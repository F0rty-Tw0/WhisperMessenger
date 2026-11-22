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

-- Runs `fn` on the given flavor under the Native look, then switches the
-- look off even when `fn` throws.
local function withNativeLook(isForever, fn)
  Flavor.With(true, isForever, function()
    Hud.Configure("classic")
    local ok, err = pcall(fn)
    Hud.Configure("off")
    if not ok then
      error(err, 0)
    end
  end)
end

-- The Font Family dropdown, built under whatever look is on.
local function create()
  local factory = dropdownFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local dropdown = DropdownSelector.Create(factory, parent, {
    labelText = "Font Family",
    optionsList = OPTIONS,
    fallbackKey = "default",
    initial = "open_sans",
    onChange = function(key)
      changes[#changes + 1] = key
    end,
  })
  return dropdown, changes
end

-- Builds the Font Family dropdown under the Native look on the given flavor.
local function buildIn(isForever)
  local dropdown, changes
  withNativeLook(isForever, function()
    dropdown, changes = create()
  end)
  return dropdown, changes
end

-- Builds, opens and picks "Morpheus" on Forever under the Native look while
-- the banned Blizzard menu APIs are spied on.
local function pickUnderSpies()
  local dd, changes, touchedNames
  withBannedSpies(function(touched)
    touchedNames = touched
    withNativeLook(true, function()
      dd, changes = create()
      FindUI.click(dd.button)
      FindUI.click(FindUI.dropdownOptions(dd.row)[3])
    end)
  end)
  return dd, changes, touchedNames
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
    local _, _, touched = pickUnderSpies()
    assert(#touched == 0, "banned Blizzard menu API touched: " .. table.concat(touched, ","))
  end

  -- test_forever_dropdown_pick_fires_on_change
  do
    local _, changes = pickUnderSpies()
    assert(changes[1] == "morpheus", "pick fires onChange with the picked key")
  end

  -- test_forever_dropdown_pick_shows_the_picked_label
  do
    local dd = pickUnderSpies()
    assert(dd.button.label.text == "Morpheus", "closed button shows the picked label")
  end

  -- test_forever_native_dropdown_create_returns_nil
  do
    local factory = dropdownFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local handle
    withNativeLook(true, function()
      handle = NativeDropdown.Create(factory, parent, { optionsList = OPTIONS })
    end)
    assert(handle == nil, "Forever + Native look: NativeDropdown.Create is nil")
  end

  -- test_retail_native_look_keeps_the_blizzard_dropdown
  do
    assert(buildIn(false).button.template == DROPDOWN_TEMPLATE, "Retail + Native look keeps the Blizzard dropdown")
  end
end
