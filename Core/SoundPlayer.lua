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
  { key = "ready", label = "Ready", soundId = 23404 },
  { key = "queue", label = "Queue", soundId = 31578 },
  { key = "alert", label = "Alert", soundId = 54129 },
  { key = "sigil", label = "Sigil", soundId = 111370 },
  { key = "map", label = "Map", soundId = 1210 },
  { key = "ding", label = "Ding", soundId = 12889 },
  { key = "glyph", label = "Glyph", soundId = 18019 },
  { key = "orb", label = "Orb", soundId = 32585 },
  { key = "spark", label = "Spark", soundId = 38326 },
  { key = "echo", label = "Echo", soundId = 39516 },
  { key = "pulse", label = "Pulse", soundId = 40033 },
}

local SOUND_BY_KEY = {}
for _, entry in ipairs(SOUND_OPTIONS) do
  SOUND_BY_KEY[entry.key] = entry.soundId
end

local DEFAULT_SOUND_KEY = "whisper"
local cvarLease

local SoundPlayer = {}

SoundPlayer.SOUND_OPTIONS = SOUND_OPTIONS

function SoundPlayer.SupportsVolume()
  local soundApi = _G.C_Sound
  return type(soundApi) == "table" and type(soundApi.PlaySoundWithOptions) == "function"
end

function SoundPlayer.NormalizeVolume(volume)
  if type(volume) ~= "number" or volume ~= volume or volume == math.huge or volume == -math.huge then
    return 1
  end

  if volume < 0 then
    return 0
  end
  if volume > 1 then
    return 1
  end
  return volume
end

local function getSoundId(soundKey)
  return SOUND_BY_KEY[soundKey] or SOUND_BY_KEY[DEFAULT_SOUND_KEY]
end

local function restoreCVarLease(lease)
  if cvarLease ~= lease then
    return
  end

  cvarLease = nil
  if lease.allSound then
    _G.SetCVar("Sound_EnableAllSound", lease.allSound)
  end
  if lease.sfx then
    _G.SetCVar("Sound_EnableSFX", lease.sfx)
  end
end

local function acquireCVarLease()
  if cvarLease then
    return cvarLease, false
  end

  local allSound = _G.GetCVar("Sound_EnableAllSound")
  local sfx = _G.GetCVar("Sound_EnableSFX")
  if allSound ~= "0" and sfx ~= "0" then
    return nil, false
  end

  local lease = {
    allSound = allSound == "0" and allSound or nil,
    sfx = sfx == "0" and sfx or nil,
    generation = 0,
  }
  cvarLease = lease

  if lease.allSound then
    _G.SetCVar("Sound_EnableAllSound", "1")
  end
  if lease.sfx then
    _G.SetCVar("Sound_EnableSFX", "1")
  end

  return lease, true
end

local function playWithSoundEnabled(play)
  local lease, acquired = acquireCVarLease()
  local played, playError = pcall(play)
  if not played then
    if acquired then
      restoreCVarLease(lease)
    end
    error(playError, 0)
  end

  if not lease then
    return
  end

  local previousGeneration = lease.generation
  local generation = previousGeneration + 1
  lease.generation = generation
  local scheduled, timerError = pcall(_G.C_Timer.After, 0.5, function()
    if cvarLease == lease and lease.generation == generation then
      restoreCVarLease(lease)
    end
  end)
  if not scheduled then
    lease.generation = previousGeneration
    if acquired then
      restoreCVarLease(lease)
    end
    error(timerError, 0)
  end
end

local function playSound(soundId, notificationVolume)
  if SoundPlayer.SupportsVolume() then
    local volume = SoundPlayer.NormalizeVolume(notificationVolume)
    if volume == 0 then
      return
    end

    playWithSoundEnabled(function()
      _G.C_Sound.PlaySoundWithOptions({
        soundKitID = soundId,
        volumeOverride = volume,
      })
    end)
    return
  end

  playWithSoundEnabled(function()
    _G.PlaySound(soundId, "Master")
  end)
end

function SoundPlayer.Play(settings)
  playSound(getSoundId(settings.notificationSound), settings.notificationVolume)
end

function SoundPlayer.Preview(soundKey, notificationVolume)
  playSound(getSoundId(soundKey), notificationVolume)
end

ns.SoundPlayer = SoundPlayer

return SoundPlayer
