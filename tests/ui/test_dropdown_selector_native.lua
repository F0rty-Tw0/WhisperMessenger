-- Under the Native WoW HUD the Font Family control is a Blizzard dropdown
-- (WowStyle1DropdownTemplate + SetupMenu) with one radio per font. Clients
-- without that API get a panel button opening the game's context menu, and
-- clients without either keep the modern dropdown.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

local DROPDOWN_TEMPLATE = "WowStyle1DropdownTemplate"

local OPTIONS = {
  { key = "default", label = "Default" },
  { key = "open_sans", label = "Open Sans" },
  { key = "morpheus", label = "Morpheus" },
}

-- Just the DropdownButton methods production calls: SetupMenu, GenerateMenu.
local function dropdownFactory(withText)
  local base = FakeUI.NewFactory()
  return {
    CreateFrame = function(frameType, name, parent, template)
      local frame = base.CreateFrame(frameType, name, parent, template)
      if template == DROPDOWN_TEMPLATE then
        frame.generateCount = 0
        function frame:SetupMenu(generator)
          self.generator = generator
          self.generateCount = self.generateCount + 1
        end
        function frame:GenerateMenu()
          self.generateCount = self.generateCount + 1
        end
        if withText then
          frame.Text = frame:CreateFontString(nil, "OVERLAY")
        end
      end
      return frame
    end,
  }
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

local function selectedRadio(radios)
  for _, radio in ipairs(radios) do
    if radio.isSelected(radio.data) then
      return radio.data
    end
  end
  return nil
end

local function build(factory, extra)
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local spec = {
    labelText = "Font Family",
    optionsList = OPTIONS,
    fallbackKey = "default",
    initial = "open_sans",
    onChange = function(key)
      changes[#changes + 1] = key
    end,
  }
  for k, v in pairs(extra or {}) do
    spec[k] = v
  end
  Hud.Configure("classic")
  local dropdown = DropdownSelector.Create(factory, parent, spec)
  Hud.Configure("off")
  return dropdown, changes
end

local function withMenuUtil(fn)
  local saved = rawget(_G, "MenuUtil")
  local calls = {}
  rawset(_G, "MenuUtil", {
    CreateContextMenu = function(owner, generator)
      calls[#calls + 1] = { owner = owner, generator = generator }
    end,
  })
  local ok, err = pcall(fn, calls)
  rawset(_G, "MenuUtil", saved)
  if not ok then
    error(err, 0)
  end
end

local function colorsMatch(a, b)
  return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

return function()
  -- test_hud_uses_the_blizzard_dropdown_when_setup_menu_exists
  do
    local dropdown = build(dropdownFactory())
    assert(dropdown.button.template == DROPDOWN_TEMPLATE, "HUD: dropdown template, got " .. tostring(dropdown.button.template))
    assert(dropdown.label.text == "Font Family", "row label kept")
    assert(FindUI.dropdownMenu(dropdown.row) == nil, "no custom menu under the Blizzard dropdown")
  end

  -- test_hud_dropdown_lists_each_font_as_a_radio
  do
    local dropdown = build(dropdownFactory())
    local radios = openMenu(dropdown.button.generator, dropdown.button)
    assert(#radios == 3 and radios[2].text == "Open Sans", "one radio per font")
    assert(selectedRadio(radios) == "open_sans", "initial font is the checked radio")
  end

  -- test_hud_dropdown_pick_fires_on_change_and_moves_the_check
  do
    local dropdown, changes = build(dropdownFactory())
    local radios = openMenu(dropdown.button.generator, dropdown.button)
    radios[3].setSelected(radios[3].data)
    assert(changes[1] == "morpheus", "onChange fires with the picked font")
    assert(selectedRadio(radios) == "morpheus", "check moves to the picked font")
  end

  -- test_hud_dropdown_set_selected_refreshes_the_shown_value
  do
    local dropdown = build(dropdownFactory())
    local before = dropdown.button.generateCount
    dropdown.setSelected("morpheus")
    assert(dropdown.button.generateCount > before, "setSelected regenerates the menu so the shown value updates")
    assert(selectedRadio(openMenu(dropdown.button.generator, dropdown.button)) == "morpheus", "setSelected checks the font")
    dropdown.setSelected("missing")
    assert(selectedRadio(openMenu(dropdown.button.generator, dropdown.button)) == "default", "unknown key falls back")
  end

  -- test_hud_dropdown_refreshes_options_on_open
  do
    local source = { { key = "default", label = "Default" } }
    local dropdown = build(dropdownFactory(), {
      getOptions = function()
        return source
      end,
    })
    source = { { key = "default", label = "Default" }, { key = "new_font", label = "New Font" } }
    local radios = openMenu(dropdown.button.generator, dropdown.button)
    assert(#radios == 2 and radios[2].text == "New Font", "menu lists the fonts available when opened")
    dropdown.setOptionsList({ { key = "default", label = "Standard" } })
    source = nil
    radios = openMenu(dropdown.button.generator, dropdown.button)
    assert(#radios == 1 and radios[1].text == "Standard", "getOptions returning nil keeps the last list")
  end

  -- test_hud_dropdown_width_and_text_colour
  do
    local dropdown = build(dropdownFactory(true))
    dropdown.setWidth(240)
    assert(dropdown.button.width == 240, "setWidth sizes the dropdown")
    assert(colorsMatch(dropdown.button.Text.textColor, Theme.COLORS.text_primary), "value text uses the preset colour")
    dropdown.applyTheme(Theme)
    assert(colorsMatch(dropdown.label.textColor, Theme.COLORS.text_primary), "theme refresh recolours the row label")
  end

  -- test_hud_without_setup_menu_uses_a_panel_button_and_context_menu
  withMenuUtil(function(calls)
    local dropdown, changes = build(FakeUI.NewFactory())
    assert(dropdown.button.template == "UIPanelButtonTemplate", "fallback: panel button, got " .. tostring(dropdown.button.template))
    assert(dropdown.button.label.text == "Open Sans", "fallback shows the current font")
    local orphan = FindUI.find(dropdown.row, function(node)
      return node.template == DROPDOWN_TEMPLATE and node:IsShown()
    end)
    assert(orphan == nil, "the unusable dropdown frame is hidden")
    FindUI.click(dropdown.button)
    assert(calls[1] and calls[1].owner == dropdown.button, "click opens the game's context menu")
    local radios = openMenu(calls[1].generator, dropdown.button)
    radios[1].setSelected(radios[1].data)
    assert(changes[1] == "default", "picking fires onChange")
    assert(dropdown.button.label.text == "Default", "button shows the picked font")
    dropdown.setSelected("morpheus")
    assert(dropdown.button.label.text == "Morpheus", "setSelected updates the button")
  end)

  -- test_hud_without_dropdown_template_uses_the_context_menu_button
  withMenuUtil(function()
    local dropdown = build(TemplateFactory.missing(FakeUI.NewFactory(), DROPDOWN_TEMPLATE))
    assert(dropdown.button.template == "UIPanelButtonTemplate", "missing template: panel button")
  end)

  -- test_hud_without_any_menu_api_keeps_the_modern_dropdown
  do
    local saved = rawget(_G, "MenuUtil")
    rawset(_G, "MenuUtil", nil)
    local dropdown = build(FakeUI.NewFactory())
    rawset(_G, "MenuUtil", saved)
    assert(dropdown.button.template == nil, "no menu API: modern closed button")
    assert(FindUI.dropdownMenu(dropdown.row) ~= nil, "no menu API: custom menu")
  end

  -- test_modern_dropdown_ignores_the_blizzard_api
  do
    local factory = dropdownFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local dropdown = DropdownSelector.Create(factory, parent, { labelText = "Font Family", optionsList = OPTIONS, fallbackKey = "default" })
    assert(dropdown.button.template == nil, "modern: custom dropdown")
  end
end
