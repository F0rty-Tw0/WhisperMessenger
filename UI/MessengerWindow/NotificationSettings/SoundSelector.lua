local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local DropdownSelector = ns.MessengerWindowDropdownSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local SoundPlayer = ns.SoundPlayer or require("WhisperMessenger.Core.SoundPlayer")

local SoundSelector = {}

SoundSelector.DEFAULT_SOUND = SoundPlayer.DEFAULT_SOUND_KEY

-- Group names are proper names (this addon, the SharedMedia library), so
-- they are not translated.
local OWN_GROUP = "Whisper Messenger"
local SHARED_GROUP = "SharedMedia"

-- Our sounds, then sounds other addons share through LibSharedMedia. Group
-- headers only appear when there are two groups to tell apart.
function SoundSelector.Options()
  local shared = SoundPlayer.ListSharedSounds()
  local options = {}
  if #shared > 0 then
    options[1] = { header = true, label = OWN_GROUP }
  end
  for _, sound in ipairs(SoundPlayer.BUILTIN_SOUNDS) do
    options[#options + 1] = { key = sound.key, label = Localization.Text(sound.label) }
  end
  if #shared > 0 then
    options[#options + 1] = { header = true, label = SHARED_GROUP }
  end
  for _, name in ipairs(shared) do
    options[#options + 1] = { key = SoundPlayer.SharedMediaKey(name), label = name }
  end
  return options
end

function SoundSelector.Create(factory, parent, opts)
  opts = opts or {}
  local onChange = opts.onChange
  return DropdownSelector.Create(factory, parent, {
    labelText = opts.labelText or Localization.Text("Notification sound"),
    optionsList = SoundSelector.Options(),
    getOptions = SoundSelector.Options,
    fallbackKey = SoundSelector.DEFAULT_SOUND,
    initial = opts.initial,
    colors = opts.colors,
    onChange = function(value)
      if onChange then
        onChange(value)
      end
      -- Preview the chosen sound on selection so the user can audition it
      -- without saving and reloading.
      SoundPlayer.PlayKey(value)
    end,
    rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    buttonHeight = 26,
  })
end

ns.NotificationSettingsSoundSelector = SoundSelector
return SoundSelector
