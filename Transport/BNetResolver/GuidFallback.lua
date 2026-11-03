local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Stage 5 of BNetResolver.ResolveAccountInfo: the GetAccountInfoByGUID
-- fallback used when the account ID lookups left presence unknown.
local GuidFallback = {}

-- Handles these cases:
--   a) Different person (shifted ID): return ByGUID result if online.
--   b) Same person (matching or missing battleTag): merge useful fields into accountInfo.
--   c) Stale ID with no accountInfo: return ByGUID result unconditionally.
-- Returns resolved accountInfo or nil.
function GuidFallback.Resolve(bnetApi, guid, accountInfo, isStaleId)
  if not guid or type(bnetApi.GetAccountInfoByGUID) ~= "function" then
    return nil
  end

  -- Stale ID with no prior accountInfo: direct GUID lookup, return unconditionally
  if isStaleId and accountInfo == nil then
    local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
    if ok and info then
      return info
    end
    return nil
  end

  -- Normal GUID fallback: only when accountInfo exists and isOnline is still nil
  if not accountInfo or accountInfo.isOnline ~= nil then
    return nil
  end

  local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
  if not ok or not info then
    return nil
  end

  local isDifferentPerson = info.battleTag and accountInfo.battleTag and info.battleTag ~= accountInfo.battleTag

  if isDifferentPerson then
    -- bnetAccountID has shifted to a different person between sessions;
    -- the GUID-based lookup is authoritative for the stored contact.
    -- isAFK/isDND are STICKY and persist after offline — do not use them as proof of presence.
    local gameInfo = info.gameAccountInfo
    if info.isOnline == true or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
      return info
    end
    return nil
  else
    -- Same person: merge useful fields from ByGUID result into accountInfo
    local gameInfo = info.gameAccountInfo
    if info.isOnline or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
      if gameInfo then
        accountInfo.gameAccountInfo = gameInfo
      end
      accountInfo.isOnline = info.isOnline
      -- If isOnline is still nil but game data proves online, set it
      if accountInfo.isOnline == nil and gameInfo and (gameInfo.isOnline or gameInfo.characterName) then
        accountInfo.isOnline = true
      end
      -- Preserve AFK/DND flags from whichever source has them
      if info.isAFK then
        accountInfo.isAFK = true
      end
      if info.isDND then
        accountInfo.isDND = true
      end
      return accountInfo
    end
    return nil
  end
end

ns.BNetResolverGuidFallback = GuidFallback
return GuidFallback
