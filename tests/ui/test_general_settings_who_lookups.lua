local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

local LABEL = "Look up players with /who"
local TOOLTIP = "Fills in a player's zone, guild, class and online status with a quiet /who when you open a chat."

local function create(factory, parent, config, changes)
  return GeneralSettings.Create(factory, parent, config, {
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

  -- test_toggle_is_on_for_a_missing_key

  do
    local settings = create(factory, parent, {}, {})
    local toggle = FindUI.toggle(settings.frame, LABEL)
    assert(toggle ~= nil, "the General page has a /who lookups toggle")
    assert(FindUI.isToggleOn(toggle), "lookups are on when nothing is saved")
  end

  -- test_toggle_reflects_saved_off_choice

  do
    local settings = create(factory, parent, { whoLookups = false }, {})
    assert(not FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "a saved off choice shows the toggle off")
  end

  -- test_click_reports_the_new_value

  do
    local changes = {}
    local settings = create(factory, parent, {}, changes)
    FindUI.click(FindUI.toggle(settings.frame, LABEL))
    local change = lastChange(changes, "whoLookups")
    assert(change ~= nil and change.value == false, "turning the toggle off reports false")
  end

  -- test_reset_turns_the_toggle_back_on

  do
    local changes = {}
    local settings = create(factory, parent, { whoLookups = false }, changes)
    FindUI.click(FindUI.byLabel(settings.frame, "Reset to Defaults"))
    local change = lastChange(changes, "whoLookups")
    assert(change ~= nil and change.value == true, "reset restores the default (on)")
    assert(FindUI.isToggleOn(FindUI.toggle(settings.frame, LABEL)), "reset flips the toggle back on")
  end

  -- test_language_change_relabels_the_toggle

  do
    local settings = create(factory, parent, {}, {})
    settings.setLanguage("deDE")
    local translated = Localization.Text(LABEL, "deDE")
    assert(translated ~= LABEL, "the German catalog translates the label")
    assert(FindUI.text(settings.frame, translated) ~= nil, "toggle label follows the interface language")
  end

  -- test_tooltip_is_translated

  do
    assert(Localization.Text(TOOLTIP, "deDE") ~= TOOLTIP, "the German catalog translates the tooltip")
  end
end
