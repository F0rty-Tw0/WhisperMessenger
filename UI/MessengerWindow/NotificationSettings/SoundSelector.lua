local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local SoundSelector = {}

SoundSelector.DEFAULT_SOUND = "whisper"

SoundSelector.OPTIONS = {
  { key = "whisper", label = "Whisper" },
  { key = "ping", label = "Ping" },
  { key = "chime", label = "Chime" },
  { key = "bell", label = "Bell" },
  { key = "raid_warning", label = "RW" },
  { key = "ready", label = "Ready" },
  { key = "queue", label = "Queue" },
  { key = "alert", label = "Alert" },
  { key = "sigil", label = "Sigil" },
  { key = "map", label = "Map" },
  { key = "ding", label = "Ding" },
  { key = "glyph", label = "Glyph" },
  { key = "orb", label = "Orb" },
  { key = "spark", label = "Spark" },
  { key = "echo", label = "Echo" },
  { key = "pulse", label = "Pulse" },
}

function SoundSelector.Create(factory, parent, opts)
  opts = opts or {}
  local onChange = opts.onChange
  return ButtonSelector.Create(factory, parent, {
    labelText = "Notification sound",
    optionsList = SoundSelector.OPTIONS,
    fallbackKey = SoundSelector.DEFAULT_SOUND,
    initial = opts.initial,
    colors = opts.colors,
    onChange = function(value)
      if onChange then
        onChange(value)
      end
      -- Preview the chosen sound on selection so the user can audition it
      -- without saving and reloading.
      local SoundPlayer = ns.SoundPlayer
      if SoundPlayer and SoundPlayer.Preview then
        SoundPlayer.Preview(value)
      end
    end,
    rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    buttonWidth = 50,
    buttonHeight = 26,
    buttonSpacing = 4,
    maxPerRow = 6,
  })
end

ns.NotificationSettingsSoundSelector = SoundSelector
return SoundSelector
