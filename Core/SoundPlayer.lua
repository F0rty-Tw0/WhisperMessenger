local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SOUND_OPTIONS = {
  { key = "whisper", label = "Whisper", soundId = 3081 },
  { key = "ping", label = "Ping", soundId = 5274 },
  { key = "chime", label = "Chime", soundId = 6674 },
  { key = "bell", label = "Bell", soundId = 5275 },
  { key = "raid_warning", label = "RW", soundId = 8959 },
}

local SOUND_BY_KEY = {}
for _, entry in ipairs(SOUND_OPTIONS) do
  SOUND_BY_KEY[entry.key] = entry.soundId
end

local DEFAULT_SOUND_KEY = "whisper"

local SoundPlayer = {}

SoundPlayer.SOUND_OPTIONS = SOUND_OPTIONS

function SoundPlayer.Play(settings)
  local soundKey = settings.notificationSound or DEFAULT_SOUND_KEY
  local soundId = SOUND_BY_KEY[soundKey] or SOUND_BY_KEY[DEFAULT_SOUND_KEY]

  -- Play on Master channel so notification uses dedicated channel settings.
  -- Do not toggle global sound CVars; changing them can leak unrelated game audio.
  _G.PlaySound(soundId, "Master")
end

function SoundPlayer.Preview(soundKey)
  local soundId = SOUND_BY_KEY[soundKey] or SOUND_BY_KEY[DEFAULT_SOUND_KEY]
  _G.PlaySound(soundId, "Master")
end

ns.SoundPlayer = SoundPlayer

return SoundPlayer
