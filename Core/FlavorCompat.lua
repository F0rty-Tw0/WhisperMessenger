local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = {}

local projectId = _G["WOW_PROJECT_ID"]
local MAINLINE = _G["WOW_PROJECT_MAINLINE"] or 1

FlavorCompat.projectId = projectId
FlavorCompat.isRetail = (projectId == MAINLINE)
FlavorCompat.isClassic = not FlavorCompat.isRetail

-- ponytail: no WOW_PROJECT_FOREVER exists; GetBuildInfo toc 16xxx is the only signal
local FOREVER_TOC_MIN = 16000
local FOREVER_TOC_MAX = 17000
local tocVersion = nil
if type(_G["GetBuildInfo"]) == "function" then
  tocVersion = select(4, _G["GetBuildInfo"]())
end
FlavorCompat.isForever = type(tocVersion) == "number" and tocVersion >= FOREVER_TOC_MIN and tocVersion < FOREVER_TOC_MAX

-- Region id of the current game client; nil without the API.
function FlavorCompat.CurrentRegion()
  local getCurrentRegion = _G["GetCurrentRegion"]
  if type(getCurrentRegion) ~= "function" then
    return nil
  end
  local ok, regionId = pcall(getCurrentRegion)
  return ok and regionId or nil
end

-- Enum.SeasonID of a Classic Era realm; nil without a season or the API.
function FlavorCompat.ActiveSeason()
  local seasons = _G["C_Seasons"]
  if type(seasons) ~= "table" or type(seasons.GetActiveSeason) ~= "function" then
    return nil
  end
  local ok, seasonId = pcall(seasons.GetActiveSeason)
  return ok and seasonId or nil
end

-- Feature flags — true only on flavors that support the feature
FlavorCompat.hasMythicPlus = FlavorCompat.isRetail and not FlavorCompat.isForever

-- Asks the server for fresh guild member data; GUILD_ROSTER_UPDATE answers.
-- Retail has C_GuildInfo.GuildRoster, the Classic flavors the global.
-- Returns true when a request went out.
function FlavorCompat.RequestGuildRoster()
  local isInGuild = _G["IsInGuild"]
  if type(isInGuild) ~= "function" or not isInGuild() then
    return false
  end
  local guildInfo = _G["C_GuildInfo"]
  local request = type(guildInfo) == "table" and guildInfo.GuildRoster or _G["GuildRoster"]
  if type(request) ~= "function" then
    return false
  end
  request()
  return true
end

-- Localized TOC title of an installed addon; nil when unknown, blank or the API is missing.
-- The old global echoes the name for unknown addons, so reason "MISSING" outranks the title.
function FlavorCompat.GetAddOnTitle(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local addOns = _G["C_AddOns"]
  local namespaced = type(addOns) == "table" and addOns.GetAddOnInfo or nil
  local getInfo = type(namespaced) == "function" and namespaced or _G["GetAddOnInfo"]
  if type(getInfo) ~= "function" then
    return nil
  end
  local ok, _, title, _, _, reason = pcall(getInfo, name)
  if not ok or reason == "MISSING" then
    return nil
  end
  if type(title) ~= "string" or not title:find("%S") then
    return nil
  end

  return title
end

-- True when the client knows the named XML template. A missing C_XMLUtil or a
-- lookup error counts as missing, so callers fall back on older flavors.
function FlavorCompat.HasTemplate(name)
  local xmlUtil = _G["C_XMLUtil"]
  if type(xmlUtil) ~= "table" or type(xmlUtil.GetTemplateInfo) ~= "function" then
    return false
  end
  local ok, info = pcall(xmlUtil.GetTemplateInfo, name)
  return ok and info ~= nil
end

-- Every Blizzard method the gamepad nav calls without a guard of its own.
-- A call added there without a guard needs its name here.
local GAMEPAD_FRAME_CONTROLS_METHODS = { "FrameShown", "FrameHidden" }
local GAMEPAD_SMART_NAVIGATION_METHODS = {
  "GetPanelInfo",
  "RefreshButtonGroups",
  "SetScrollFrameForFrame",
  "SetSmartNavPanelInfoAddedCallback",
  "RightClick",
}

local function hasMethods(object, names)
  if type(object) ~= "table" then
    return false
  end
  for _, name in ipairs(names) do
    if type(object[name]) ~= "function" then
      return false
    end
  end
  return true
end

-- True when the client has the whole gamepad UI API the addon talks to:
-- GamepadMode.FrameControlsManager and SmartNavigation, each with every
-- method listed above. Every gamepad piece turns on by this, never by
-- flavor: WoW: Forever has the API today, and the same code runs wherever
-- Blizzard ships it next. A client with only part of it counts as without.
-- gamepadMode, smartNavigation: the tables to check; nil = the game's
-- globals, false = absent.
function FlavorCompat.HasGamepadUI(gamepadMode, smartNavigation)
  if gamepadMode == nil then
    gamepadMode = _G["GamepadMode"]
  end
  if smartNavigation == nil then
    smartNavigation = _G["SmartNavigation"]
  end
  local fcm = type(gamepadMode) == "table" and gamepadMode.FrameControlsManager or nil
  return hasMethods(fcm, GAMEPAD_FRAME_CONTROLS_METHODS) and hasMethods(smartNavigation, GAMEPAD_SMART_NAVIGATION_METHODS)
end

-- True while the game's gamepad UI is on (the player is using the pad).
-- Blizzard's own check, read on every call; a missing API or an error is off.
function FlavorCompat.IsGamepadUIEnabled()
  local inputUtil = _G["InputUtil"]
  if type(inputUtil) ~= "table" or type(inputUtil.IsGamepadUIEnabled) ~= "function" then
    return false
  end
  local ok, enabled = pcall(inputUtil.IsGamepadUIEnabled)
  return ok and enabled == true
end

-- True when WM opens its own right-click menus and drop-down lists instead
-- of Blizzard's: on WoW: Forever, while the gamepad UI is on. Read on every
-- call, so picking up or putting down the pad switches at once.
function FlavorCompat.UsesOwnMenus()
  return FlavorCompat.isForever == true and FlavorCompat.IsGamepadUIEnabled()
end

-- The atlas name of the game's picture for pad button key ("PAD1", ...) on
-- the pad in use, or nil. Read on every call, so a pad swap shows at once.
-- Blizzard's lookup throws when the active icon set has no entry for the
-- key, so it runs in pcall; anything but a non-empty string is no picture.
function FlavorCompat.GamepadButtonAtlas(key)
  if type(key) ~= "string" then
    return nil
  end
  local iconUtil = _G["InputIconTextureSetUtility"]
  if type(iconUtil) ~= "table" or type(iconUtil.GetNormalActiveInputIconButtonTexture) ~= "function" then
    return nil
  end
  local ok, atlas = pcall(iconUtil.GetNormalActiveInputIconButtonTexture, key)
  if ok and type(atlas) == "string" and atlas ~= "" then
    return atlas
  end
  return nil
end

ns.FlavorCompat = FlavorCompat

return FlavorCompat
