local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

local LABEL = "Class-colored names"
local TOOLTIP = "Shows player names above messages in their class color."

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

  -- test_toggle_is_on_by_default

  do
    local settings = create(factory, parent, {}, {})
    assert(FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "class colours are on by default")
  end

  -- test_toggle_reflects_saved_off_choice

  do
    local settings = create(factory, parent, { classColorSenderNames = false }, {})
    assert(not FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "a saved off choice shows the toggle off")
  end

  -- test_click_reports_the_new_value

  do
    local changes = {}
    local settings = create(factory, parent, {}, changes)
    FindUI.click(FindUI.toggle(settings.frame, LABEL))
    local change = lastChange(changes, "classColorSenderNames")
    assert(change ~= nil and change.value == false, "turning the toggle off reports false")
  end

  -- test_reset_turns_the_toggle_back_on

  do
    local changes = {}
    local settings = create(factory, parent, { classColorSenderNames = false }, changes)
    FindUI.click(FindUI.byLabel(settings.frame, "Reset to Defaults"))
    local change = lastChange(changes, "classColorSenderNames")
    assert(change ~= nil and change.value == true, "reset restores the default (on)")
    assert(FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "reset flips the toggle back on")
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
