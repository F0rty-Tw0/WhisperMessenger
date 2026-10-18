local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

local LABEL = "Class-colored names"

local function create(factory, parent, config, changes)
  return AppearanceSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 500)

  -- test_class_colour_toggle_is_gone

  do
    local settings = create(factory, parent, {}, {})
    assert(FindUI.text(settings.frame, LABEL) == nil, "the class colour toggle is gone")
  end

  -- test_language_change_survives_without_the_toggle

  do
    local settings = create(factory, parent, {}, {})
    Localization.Configure({ language = "deDE" })
    local ok, err = pcall(settings.setLanguage)
    Localization.Configure({ language = "enUS" })
    assert(ok, "relabel survives without the toggle: " .. tostring(err))
  end
end
