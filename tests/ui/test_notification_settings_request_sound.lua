local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The two request-sound rows on the Notifications panel: a toggle and its own
-- sound picker, saved as playSoundOnRequest and requestSound.

local TOGGLE_LABEL = "Play sound on message request"
local SELECTOR_LABEL = "Request sound"

local function build(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = NotificationSettings.Create(factory, parent, config or {}, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

local function optionByLabel(result, selectorLabel, label)
  for _, button in ipairs(FindUI.dropdownOptions(FindUI.byLabel(result.frame, selectorLabel))) do
    if button.label.text == label then
      return button
    end
  end
  error("no sound option labelled " .. label)
end

return function()
  local savedPlaySound = rawget(_G, "PlaySound")
  rawset(_G, "PlaySound", function() end)

  -- test_request_rows_save_their_keys
  do
    local result, changes = build()
    FindUI.click(FindUI.toggle(result.frame, TOGGLE_LABEL))
    assert(changes.playSoundOnRequest == true, "clicking the toggle saves playSoundOnRequest=true")
    local options = FindUI.dropdownOptions(FindUI.byLabel(result.frame, SELECTOR_LABEL))
    FindUI.click(options[3])
    assert(changes.requestSound == "chime", "picking the 3rd option saves its key, got " .. tostring(changes.requestSound))
  end

  -- test_reset_restores_request_defaults
  do
    local result, changes = build({ playSoundOnRequest = true, requestSound = "bell" })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    FindUI.click(reset)
    assert(changes.playSoundOnRequest == false, "reset turns the request sound off")
    assert(changes.requestSound == "ping", "reset restores ping, got " .. tostring(changes.requestSound))
  end

  -- test_request_sound_pick_previews_it
  do
    local result = build()
    local previewed = {}
    local realPlayKey = SoundPlayer.PlayKey
    SoundPlayer.PlayKey = function(soundKey)
      previewed[#previewed + 1] = soundKey
    end
    local ok, err = pcall(function()
      FindUI.click(optionByLabel(result, SELECTOR_LABEL, "Bell"))
    end)
    SoundPlayer.PlayKey = realPlayKey
    assert(ok, err)
    assert(#previewed == 1 and previewed[1] == "bell", "picking Bell auditions it once through PlayKey")
  end

  -- test_set_language_relabels_request_rows
  do
    Localization.Configure({ language = "enUS" })
    local result = build()
    Localization.Configure({ language = "ruRU" })
    result.setLanguage()
    local catalog = require("WhisperMessenger.Locale.ruRU")
    local toggleLabel = catalog["Play sound on message request"]
    local selectorLabel = catalog["Request sound"]
    assert(FindUI.text(result.frame, toggleLabel) ~= nil, "the request toggle takes the new language")
    assert(FindUI.text(result.frame, selectorLabel) ~= nil, "the request selector takes the new language")
    Localization.Configure({ language = "enUS" })
  end

  rawset(_G, "PlaySound", savedPlaySound)
end
