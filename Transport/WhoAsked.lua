local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WhoFreshness = ns.WhoFreshness or require("WhisperMessenger.Transport.WhoFreshness")

-- When WhoLookup last sent a /who for each name, this session only. Names
-- with no conversation land here too, so the list is capped instead of
-- following conversation removals.
local WhoAsked = {}

WhoAsked.MAX_ENTRIES = 256

local askedAtByName = {}
local entryCount = 0

function WhoAsked.Get(nameKey)
  return askedAtByName[nameKey]
end

function WhoAsked.Count()
  return entryCount
end

function WhoAsked.Forget(nameKey)
  if nameKey ~= nil and askedAtByName[nameKey] ~= nil then
    askedAtByName[nameKey] = nil
    entryCount = entryCount - 1
  end
end

-- A name asked STALE_SECONDS ago reads the same as one never asked, so
-- dropping those changes no answer. WhoLookup spaces its asks, which leaves
-- far fewer fresh names than the cap.
local function makeRoom(now)
  for nameKey, askedAt in pairs(askedAtByName) do
    if now - askedAt >= WhoFreshness.STALE_SECONDS then
      askedAtByName[nameKey] = nil
      entryCount = entryCount - 1
    end
  end
  -- grug: wipe-all backstop, as in SeenLevel; LRU if it ever matters
  if entryCount >= WhoAsked.MAX_ENTRIES then
    askedAtByName = {}
    entryCount = 0
  end
end

function WhoAsked.Remember(nameKey, now)
  if askedAtByName[nameKey] == nil then
    if entryCount >= WhoAsked.MAX_ENTRIES then
      makeRoom(now)
    end
    entryCount = entryCount + 1
  end
  askedAtByName[nameKey] = now
end

function WhoAsked._reset()
  askedAtByName = {}
  entryCount = 0
end

ns.WhoAsked = WhoAsked

return WhoAsked
