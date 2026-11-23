-- On WoW: Forever under the Native WoW HUD a settings dropdown shows
-- WhisperMessenger's own list while the game's gamepad UI is on (the game's
-- menus taint from addon code there) and the game's dropdown while it is
-- off. Other flavors keep the game's dropdown under the Native look.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Flavor = require("tests.helpers.flavor")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local NativeDropdown = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.NativeDropdown")
local DropdownSwap = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSwap")

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

-- Builds, opens and picks "Morpheus" on Forever under the Native look with
-- the gamepad UI on while the banned Blizzard menu APIs are spied on.
local function pickUnderSpies()
  local dd, changes, touchedNames
  withBannedSpies(function(touched)
    touchedNames = touched
    Flavor.WithPadUI(true, function()
      withNativeLook(true, function()
        dd, changes = create()
        FindUI.click(dd.button)
        FindUI.click(FindUI.dropdownOptions(dd.row)[3])
      end)
    end)
  end)
  return dd, changes, touchedNames
end

-- Runs a menu generator against a fake root description; returns the radios.
local function openMenu(generator, owner)
  local radios = {}
  local root = {
    CreateRadio = function(_self, text, isSelected, setSelected, data)
      radios[#radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
    end,
  }
  generator(owner, root)
  return radios
end

local function isDropdownTemplate(node)
  return node.template == DROPDOWN_TEMPLATE
end

-- Every node below `root` matching `predicate`.
local function countBelow(root, predicate)
  local count = 0
  for _, child in ipairs(root.children or {}) do
    if predicate(child) then
      count = count + 1
    end
    count = count + countBelow(child, predicate)
  end
  return count
end

return function()
  -- test_forever_native_look_builds_the_wm_dropdown
  do
    local dd
    Flavor.WithPadUI(true, function()
      dd = buildIn(true)
    end)
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

  -- test_forever_native_dropdown_create_builds_the_game_dropdown
  do
    local factory = dropdownFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local handle
    withNativeLook(true, function()
      handle = NativeDropdown.Create(factory, parent, { optionsList = OPTIONS })
    end)
    assert(handle ~= nil, "Forever + Native look: NativeDropdown.Create returns a handle")
    assert(handle.button.template == DROPDOWN_TEMPLATE, "the handle drives the game's dropdown")
  end

  -- test_retail_native_look_keeps_the_blizzard_dropdown
  do
    assert(buildIn(false).button.template == DROPDOWN_TEMPLATE, "Retail + Native look keeps the Blizzard dropdown")
  end

  -- test_forever_pad_off_native_look_shows_game_dropdown
  do
    local dd
    Flavor.WithPadUI(false, function()
      dd = buildIn(true)
    end)
    local nd = FindUI.find(dd.row, isDropdownTemplate)
    assert(nd ~= nil, "pad UI off: the game's dropdown is built")
    assert(nd.parent:IsShown(), "pad UI off: the game's dropdown row shows")
    assert(not dd.button:IsShown(), "pad UI off: WM's own button hides")
  end

  -- test_forever_pick_in_game_dropdown_calls_on_change_once
  do
    local dd, changes
    Flavor.WithPadUI(false, function()
      dd, changes = buildIn(true)
    end)
    local nd = FindUI.find(dd.row, isDropdownTemplate)
    assert(nd, "pad UI off: the game's dropdown is built")
    for _, radio in ipairs(openMenu(nd.generator, nd)) do
      if radio.data == "morpheus" then
        radio.setSelected(radio.data)
      end
    end
    assert(#changes == 1, "one pick reports once, got " .. #changes)
    assert(changes[1] == "morpheus", "the pick reports the picked key")
    assert(dd.button.label.text == "Morpheus", "WM's own button mirrors the pick")
  end

  -- test_forever_flip_off_closes_open_wm_list
  do
    withNativeLook(true, function()
      local dd
      Flavor.WithPadUI(true, function()
        dd = create()
        FindUI.click(dd.button)
        assert(FindUI.dropdownMenu(dd.row):IsShown(), "pad UI on: WM's own list opens")
      end)
      Flavor.WithPadUI(false, function()
        DropdownSwap.Refresh()
        assert(not FindUI.dropdownMenu(dd.row):IsShown(), "flip off closes WM's open list")
        assert(not dd.button:IsShown(), "flip off hides WM's own button")
      end)
    end)
  end

  -- test_retail_native_look_builds_no_swap
  do
    local dd = buildIn(false)
    assert(dd.button.template == DROPDOWN_TEMPLATE, "Retail: the game's dropdown")
    assert(countBelow(dd.row, isDropdownTemplate) == 1, "Retail: one game dropdown, got " .. countBelow(dd.row, isDropdownTemplate))
    assert(FindUI.dropdownMenu(dd.row) == nil, "Retail: no WM list")
    assert(dd.picked == nil, "Retail: a plain handle, not a swap pair")
  end
end
