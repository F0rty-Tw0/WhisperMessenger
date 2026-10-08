local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

local LABEL = "Show player levels"
local TOOLTIP = "Shows a player's level, colored by how it compares to yours, in the chat header and before names in group and channel chats."

local function create(factory, parent, config, changes)
  return AppearanceSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
end

local function lastChange(changes, key)
  for index = #changes, 1, -1 do
    if changes[index].key == key then
      return changes[index]
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 500)

  -- test_toggle_is_off_by_default

  do
    local settings = create(factory, parent, {}, {})
    local toggle = FindUI.toggle(settings.frame, LABEL)
    assert(toggle ~= nil, "the Appearance page has a player levels toggle")
    assert(not FindUI.isToggleOn(toggle), "player levels are off by default")
  end

  -- test_toggle_reflects_saved_on_choice

  do
    local settings = create(factory, parent, { showPlayerLevels = true }, {})
    assert(FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "a saved on choice shows the toggle on")
  end

  -- test_click_reports_the_new_value

  do
    local changes = {}
    local settings = create(factory, parent, {}, changes)
    FindUI.click(FindUI.toggle(settings.frame, LABEL))
    local change = lastChange(changes, "showPlayerLevels")
    assert(change ~= nil and change.value == true, "turning the toggle on reports true")
  end

  -- test_reset_turns_the_toggle_back_off

  do
    local changes = {}
    local settings = create(factory, parent, { showPlayerLevels = true }, changes)
    FindUI.click(FindUI.byLabel(settings.frame, "Reset to Defaults"))
    local change = lastChange(changes, "showPlayerLevels")
    assert(change ~= nil and change.value == false, "reset restores the default (off)")
    assert(not FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "reset flips the toggle back off")
  end

  -- test_language_change_relabels_the_toggle

  do
    local settings = create(factory, parent, {}, {})
    Localization.Configure({ language = "deDE" })
    settings.setLanguage()
    local translated = Localization.Text(LABEL)
    Localization.Configure({ language = "enUS" })
    assert(translated ~= LABEL, "the German catalog translates the label")
    assert(FindUI.text(settings.frame, translated) ~= nil, "toggle label follows the interface language")
  end

  -- test_tooltip_is_translated

  do
    assert(Localization.Text(TOOLTIP, "deDE") ~= TOOLTIP, "the German catalog translates the tooltip")
  end
end
