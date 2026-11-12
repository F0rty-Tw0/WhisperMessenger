-- The notification sound is one dropdown: our built-in sounds first, then
-- any sounds other addons share through LibSharedMedia, each group under a
-- header. Picking a sound saves it and plays it once as a preview.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local FakeSharedSounds = require("tests.helpers.fake_shared_sounds")
local SoundSelector = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings.SoundSelector")

local SHARED = {
  { "Boom", "Interface\\AddOns\\Media\\boom.ogg" },
  { "Zap", "Interface\\AddOns\\Media\\zap.ogg" },
}

-- Builds the selector; returns its handle and the saved values.
local function build(initial)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local saved = {}
  local selector = SoundSelector.Create(factory, parent, {
    initial = initial,
    onChange = function(value)
      saved[#saved + 1] = value
    end,
  })
  return selector, saved
end

local function optionByLabel(selector, label)
  for _, button in ipairs(FindUI.dropdownOptions(selector.row)) do
    if button.label.text == label then
      return button
    end
  end
  error("no sound option labelled " .. label)
end

-- Records PlaySound / PlaySoundFile calls made by fn().
local function recordPlays(fn)
  local plays = {}
  local savedPlaySound, savedPlaySoundFile = rawget(_G, "PlaySound"), rawget(_G, "PlaySoundFile")
  rawset(_G, "PlaySound", function(soundId, channel)
    plays[#plays + 1] = { api = "PlaySound", sound = soundId, channel = channel }
  end)
  rawset(_G, "PlaySoundFile", function(path, channel)
    plays[#plays + 1] = { api = "PlaySoundFile", sound = path, channel = channel }
  end)
  local ok, err = pcall(fn)
  rawset(_G, "PlaySound", savedPlaySound)
  rawset(_G, "PlaySoundFile", savedPlaySoundFile)
  assert(ok, err)
  return plays
end

return function()
  -- test_options_list_our_sounds_first_then_shared_media
  do
    local options
    FakeSharedSounds.with(SHARED, function()
      options = SoundSelector.Options()
    end)
    assert(#options == 20, "2 headers + 16 built-in + 2 shared sounds, got " .. #options)
    assert(options[1].header and options[1].label == "Whisper Messenger", "our group comes first")
    assert(options[2].key == "whisper" and options[17].key == "pulse", "all 16 built-in sounds follow in order")
    assert(options[18].header and options[18].label == "SharedMedia", "SharedMedia group comes second")
    assert(options[19].key == "lsm:Boom" and options[19].label == "Boom", "shared sounds keep their SharedMedia name")
    assert(options[20].key == "lsm:Zap", "every shared sound is listed")
  end

  -- test_options_without_shared_media_list_only_ours
  do
    local options
    FakeSharedSounds.with(nil, function()
      options = SoundSelector.Options()
    end)
    assert(#options == 16 and options[1].key == "whisper", "only the 16 built-in sounds, got " .. #options)
    for _, option in ipairs(options) do
      assert(not option.header, "a single group needs no header")
    end
  end

  -- test_pick_our_sound_saves_its_key_and_previews_it
  do
    local selector, saved = build("whisper")
    local plays = recordPlays(function()
      FindUI.click(optionByLabel(selector, "Ping"))
    end)
    assert(saved[1] == "ping", "built-in pick saves its key, got " .. tostring(saved[1]))
    assert(#plays == 1 and plays[1].api == "PlaySound" and plays[1].sound == 5274, "built-in pick previews through PlaySound")
  end

  -- test_pick_shared_media_sound_saves_its_name_and_previews_it
  do
    local saved, plays
    FakeSharedSounds.with(SHARED, function()
      local selector
      selector, saved = build("whisper")
      plays = recordPlays(function()
        FindUI.click(optionByLabel(selector, "Zap"))
      end)
    end)
    assert(saved[1] == "lsm:Zap", "shared pick saves its SharedMedia name, got " .. tostring(saved[1]))
    assert(#plays == 1 and plays[1].api == "PlaySoundFile", "shared pick previews through PlaySoundFile")
    assert(plays[1].sound == "Interface\\AddOns\\Media\\zap.ogg" and plays[1].channel == "Master", "plays the shared file on Master")
  end

  -- test_saved_builtin_key_still_shows_its_sound
  do
    local selector = build("bell")
    assert(selector.button.label.text == "Bell", "an existing saved key loads, got " .. tostring(selector.button.label.text))
  end

  -- test_saved_shared_media_name_shows_its_sound
  do
    local selector
    FakeSharedSounds.with(SHARED, function()
      selector = build("lsm:Boom")
    end)
    assert(selector.button.label.text == "Boom", "a saved shared sound loads, got " .. tostring(selector.button.label.text))
  end

  -- test_menu_lists_shared_sounds_registered_after_creation
  do
    local selector = build("whisper")
    FakeSharedSounds.with(SHARED, function()
      FindUI.click(selector.button)
    end)
    assert(#FindUI.dropdownOptions(selector.row) == 20, "opening the menu picks up sounds shared since the panel was built")
  end

  -- test_label_text_option_overrides_label
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    SoundSelector.Create(factory, parent, { labelText = "Request sound" })
    assert(FindUI.byLabel(parent, "Request sound") ~= nil, "labelText replaces the default label")
    assert(FindUI.text(parent, "Notification sound") == nil, "the default label is not drawn as well")
  end

  print("  All notification sound selector tests passed")
end
