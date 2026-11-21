local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")

-- "Mute all sounds" at the top of Notifications greys out the three sound
-- toggles while it is on; the sound pickers stay usable and still preview.

local MUTE = "Mute all sounds"
local WHISPER_TOGGLE = "Play sound on new whisper"
local TOGGLES = { WHISPER_TOGGLE, "Play sound on message request", "Play sound when you send a whisper" }
local SELECTORS = { "Notification sound", "Request sound", "Mention sound", "Sent whisper sound" }
local REASON = "Turn off Mute all sounds to change this."

local function build(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = NotificationSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

local function assertAllCovered(frame, labels, covered, context)
  for _, label in ipairs(labels) do
    local cover = FindUI.disabledCover(FindUI.byLabel(frame, label))
    assert((cover ~= nil) == covered, context .. ": " .. label .. (covered and " should be greyed" or " should be usable"))
  end
end

local function optionByLabel(row, label)
  for _, button in ipairs(FindUI.dropdownOptions(row)) do
    if button.label.text == label then
      return button
    end
  end
  error("no sound option labelled " .. label)
end

local function whisperCover(result)
  return FindUI.disabledCover(FindUI.byLabel(result.frame, WHISPER_TOGGLE))
end

-- Hovers a grey cover and returns the tooltip text it shows.
local function hover(cover)
  local savedTooltip = rawget(_G, "GameTooltip")
  local tip = {}
  rawset(_G, "GameTooltip", {
    SetOwner = function() end,
    SetText = function(_, value)
      tip.text = value
    end,
    Show = function() end,
    Hide = function() end,
  })
  local ok, err = pcall(function()
    assert(cover, "muted, the whisper toggle has a cover")
    cover:GetScript("OnEnter")(cover)
  end)
  rawset(_G, "GameTooltip", savedTooltip)
  assert(ok, err)
  return tip.text
end

return function()
  -- test_mute_toggle_saves_key
  do
    local result, changes = build({})
    FindUI.click(FindUI.toggle(result.frame, MUTE))
    assert(changes.muteAllSounds == true, "turning mute on saves true, got " .. tostring(changes.muteAllSounds))
  end

  -- test_mute_toggle_defaults_off
  do
    local result = build({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, MUTE)) == false, "Mute all sounds defaults to off")
  end

  -- test_mute_toggle_sits_above_whisper_toggle
  do
    local result = build({})
    local whisperRow = FindUI.byLabel(result.frame, WHISPER_TOGGLE)
    assert(whisperRow.points[1][2] == FindUI.byLabel(result.frame, MUTE), "the whisper toggle hangs under the mute toggle")
  end

  -- test_sound_toggles_greyed_when_opened_muted
  do
    local result = build({ muteAllSounds = true })
    assertAllCovered(result.frame, TOGGLES, true, "opened muted")
    assert(FindUI.byLabel(result.frame, WHISPER_TOGGLE).alpha < 1, "greyed toggles are dimmed")
  end

  -- test_sound_toggles_grey_on_mute_click
  do
    local result = build({})
    FindUI.click(FindUI.toggle(result.frame, MUTE))
    assertAllCovered(result.frame, TOGGLES, true, "after muting")
  end

  -- test_sound_toggles_ungrey_on_unmute_click
  do
    local result = build({ muteAllSounds = true })
    FindUI.click(FindUI.toggle(result.frame, MUTE))
    assertAllCovered(result.frame, TOGGLES, false, "after unmuting")
  end

  -- test_reset_ungreys_sound_toggles
  do
    local result, changes = build({ muteAllSounds = true })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.muteAllSounds == false, "Reset turns mute off, got " .. tostring(changes.muteAllSounds))
    assertAllCovered(result.frame, TOGGLES, false, "after Reset")
  end

  -- test_greyed_toggles_keep_saved_values
  do
    local result = build({ muteAllSounds = true, playSoundOnWhisper = true })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, WHISPER_TOGGLE)) == true, "a greyed toggle keeps its saved value")
  end

  -- test_selectors_stay_enabled_while_muted
  do
    local result = build({ muteAllSounds = true })
    assertAllCovered(result.frame, SELECTORS, false, "selectors while muted")
  end

  -- test_preview_plays_while_muted
  do
    local result = build({ muteAllSounds = true })
    local plays = {}
    local saved = rawget(_G, "PlaySound")
    rawset(_G, "PlaySound", function(soundId)
      plays[#plays + 1] = soundId
    end)
    local ok, err = pcall(FindUI.click, optionByLabel(FindUI.byLabel(result.frame, "Notification sound"), "Ping"))
    rawset(_G, "PlaySound", saved)
    assert(ok, err)
    assert(#plays == 1 and plays[1] == 5274, "picking a sound previews it while muted, got " .. tostring(plays[1]))
  end

  -- test_greyed_toggle_hover_reason
  do
    local result = build({ muteAllSounds = true })
    local shown = hover(whisperCover(result))
    assert(shown == REASON, "hover explains why, got " .. tostring(shown))
  end

  -- test_hover_reason_follows_language_change
  do
    local result = build({ muteAllSounds = true })
    local cover = whisperCover(result)
    Localization.Configure({ language = "deDE" })
    local ok, shown = pcall(function()
      result.setLanguage()
      return hover(cover)
    end)
    Localization.Configure({ language = "enUS" })
    assert(ok, shown)
    local expected = Localization.Text(REASON, "deDE")
    assert(expected ~= REASON, "deDE has its own reason text")
    assert(shown == expected, "hover reason follows the new language, got " .. tostring(shown))
  end
end
