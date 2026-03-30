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

  -- Force-enable audio when muted so notifications always play
  local savedEnableAll = nil
  local savedEnableSFX = nil
  local enableAll = _G.GetCVar("Sound_EnableAllSound")
  local enableSFX = _G.GetCVar("Sound_EnableSFX")
  if enableAll == "0" then
    savedEnableAll = enableAll
    _G.SetCVar("Sound_EnableAllSound", "1")
  end
  if enableSFX == "0" then
    savedEnableSFX = enableSFX
    _G.SetCVar("Sound_EnableSFX", "1")
  end

  -- Play on Master channel to bypass per-channel muting
  _G.PlaySound(soundId, "Master")

  -- Restore audio CVars after a short delay so the sound has time to start
  if savedEnableAll ~= nil or savedEnableSFX ~= nil then
    _G.C_Timer.After(0.5, function()
      if savedEnableAll ~= nil then
        _G.SetCVar("Sound_EnableAllSound", savedEnableAll)
      end
      if savedEnableSFX ~= nil then
        _G.SetCVar("Sound_EnableSFX", savedEnableSFX)
      end
    end)
  end
end

function SoundPlayer.Preview(soundKey)
  local soundId = SOUND_BY_KEY[soundKey] or SOUND_BY_KEY[DEFAULT_SOUND_KEY]
  _G.PlaySound(soundId, "Master")
end

ns.SoundPlayer = SoundPlayer

return SoundPlayer
