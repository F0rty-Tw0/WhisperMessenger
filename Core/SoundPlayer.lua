local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SOUND_OPTIONS = {
  { key = "whisper", label = "Whisper", soundId = 3081 },
  { key = "ping", label = "Ping", soundId = 5274 },
  { key = "chime", label = "Chime", soundId = 6674 },
  { key = "bell", label = "Bell", soundId = 5275 },
  { key = "raid_warning", label = "Raid Warning", soundId = 8959 },
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
-- Saved keys for SharedMedia sounds; built-in keys never contain ":".
local SHARED_MEDIA_PREFIX = "lsm:"
-- LibSharedMedia's own silent entry; the toggle already turns sound off.
local SHARED_MEDIA_SILENT = "None"
local CHANNEL = "Master"

local SoundPlayer = {}

SoundPlayer.DEFAULT_SOUND_KEY = DEFAULT_SOUND_KEY
SoundPlayer.BUILTIN_SOUNDS = SOUND_OPTIONS

local function sharedMedia()
  local libStub = _G.LibStub
  if type(libStub) ~= "table" then
    return nil
  end
  local ok, lsm = pcall(libStub, "LibSharedMedia-3.0", true)
  if ok and type(lsm) == "table" then
    return lsm
  end
  return nil
end

local function fetchSharedSound(name)
  local lsm = sharedMedia()
  if not lsm or type(lsm.Fetch) ~= "function" then
    return nil
  end
  local ok, path = pcall(lsm.Fetch, lsm, "sound", name, true)
  if ok and (type(path) == "string" or type(path) == "number") then
    return path
  end
  return nil
end

function SoundPlayer.SharedMediaKey(name)
  return SHARED_MEDIA_PREFIX .. name
end

-- Names of the sounds other addons registered with LibSharedMedia.
function SoundPlayer.ListSharedSounds()
  local names = {}
  local lsm = sharedMedia()
  if not lsm or type(lsm.List) ~= "function" then
    return names
  end
  local ok, listed = pcall(lsm.List, lsm, "sound")
  if not ok or type(listed) ~= "table" then
    return names
  end
  for _, name in ipairs(listed) do
    if type(name) == "string" and name ~= "" and name ~= SHARED_MEDIA_SILENT then
      names[#names + 1] = name
    end
  end
  return names
end

-- Play on Master channel so notification uses dedicated channel settings.
-- Do not toggle global sound CVars; changing them can leak unrelated game audio.
-- A SharedMedia sound whose addon is gone plays the default instead.
local function playKey(soundKey)
  if type(soundKey) == "string" and string.sub(soundKey, 1, #SHARED_MEDIA_PREFIX) == SHARED_MEDIA_PREFIX then
    local path = fetchSharedSound(string.sub(soundKey, #SHARED_MEDIA_PREFIX + 1))
    if path then
      _G.PlaySoundFile(path, CHANNEL)
      return
    end
  end
  _G.PlaySound(SOUND_BY_KEY[soundKey] or SOUND_BY_KEY[DEFAULT_SOUND_KEY], CHANNEL)
end

function SoundPlayer.Play(settings)
  playKey(settings.notificationSound or DEFAULT_SOUND_KEY)
end

function SoundPlayer.PlayKey(soundKey)
  playKey(soundKey)
end

ns.SoundPlayer = SoundPlayer

return SoundPlayer
