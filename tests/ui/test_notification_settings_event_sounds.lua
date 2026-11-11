local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The event-sound rows on the Notifications panel: a mention picker, a sent
-- whisper toggle and its picker, saved as mentionSound, playSoundOnSend and
-- sentSound.

local MENTION_LABEL = "Mention sound"
local SENT_TOGGLE_LABEL = "Play sound when you send a whisper"
local SENT_LABEL = "Sent whisper sound"

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

local function shownSound(result, selectorLabel)
  return FindUI.ofType(FindUI.byLabel(result.frame, selectorLabel), "Button")[1].label.text
end

return function()
  local savedPlaySound = rawget(_G, "PlaySound")
  rawset(_G, "PlaySound", function() end)

  -- test_new_rows_save_their_keys
  do
    local result, changes = build()
    FindUI.click(FindUI.dropdownOptions(FindUI.byLabel(result.frame, MENTION_LABEL))[3])
    assert(changes.mentionSound == "chime", "picking the 3rd mention option saves its key, got " .. tostring(changes.mentionSound))
    FindUI.click(FindUI.toggle(result.frame, SENT_TOGGLE_LABEL))
    assert(changes.playSoundOnSend == true, "clicking the sent toggle saves playSoundOnSend=true")
    FindUI.click(FindUI.dropdownOptions(FindUI.byLabel(result.frame, SENT_LABEL))[4])
    assert(changes.sentSound == "bell", "picking the 4th sent option saves its key, got " .. tostring(changes.sentSound))
  end

  -- test_sent_toggle_is_off_by_default
  do
    local result = build()
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, SENT_TOGGLE_LABEL)) == false, "the sent sound starts off")
    assert(shownSound(result, SENT_LABEL) == "Chime", "the sent picker starts on Chime, got " .. tostring(shownSound(result, SENT_LABEL)))
  end

  -- test_mention_picker_shows_whisper_pick_when_unset
  do
    local result = build({ notificationSound = "bell" })
    assert(
      shownSound(result, MENTION_LABEL) == "Bell",
      "unset mention pick shows the whisper pick, got " .. tostring(shownSound(result, MENTION_LABEL))
    )
  end

  -- test_saved_event_sounds_load
  do
    local result = build({ notificationSound = "bell", mentionSound = "orb", playSoundOnSend = true, sentSound = "ding" })
    assert(shownSound(result, MENTION_LABEL) == "Orb", "a saved mention pick loads")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, SENT_TOGGLE_LABEL)) == true, "a saved sent toggle loads on")
    assert(shownSound(result, SENT_LABEL) == "Ding", "a saved sent pick loads")
  end

  -- test_reset_restores_event_sound_defaults
  do
    local result, changes = build({ notificationSound = "bell", mentionSound = "orb", playSoundOnSend = true, sentSound = "ding" })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.mentionSound == "whisper", "reset restores the mention pick, got " .. tostring(changes.mentionSound))
    assert(changes.notificationSound == "whisper", "reset restores the whisper pick, got " .. tostring(changes.notificationSound))
    assert(changes.playSoundOnSend == false, "reset turns the sent sound off")
    assert(changes.sentSound == "chime", "reset restores the sent pick, got " .. tostring(changes.sentSound))
  end

  -- test_set_language_relabels_event_rows
  do
    Localization.Configure({ language = "enUS" })
    local result = build()
    Localization.Configure({ language = "ruRU" })
    result.setLanguage()
    local catalog = require("WhisperMessenger.Locale.ruRU")
    for _, key in ipairs({ MENTION_LABEL, SENT_TOGGLE_LABEL, SENT_LABEL }) do
      assert(FindUI.text(result.frame, catalog[key]) ~= nil, "'" .. key .. "' takes the new language")
    end
    Localization.Configure({ language = "enUS" })
  end

  rawset(_G, "PlaySound", savedPlaySound)
end
