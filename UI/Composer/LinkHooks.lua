local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatLinkSources = ns.ComposerChatLinkSources or require("WhisperMessenger.UI.Composer.ChatLinkSources")
local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")
local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")

local LinkHooks = {}
local registeredLinkHooks = false
local linkedInputs = {}
local lastInsertFrameTime = nil

local function isInputShown(input)
  if type(input.IsVisible) == "function" then
    return input:IsVisible() == true
  end
  if type(input.IsShown) ~= "function" then
    return true
  end
  return input:IsShown() == true
end

local function isInputFocused(input)
  if type(input.HasFocus) ~= "function" then
    return false
  end
  return input:HasFocus() == true
end

local function findInputForInsertion(allowVisibleWithoutFocus)
  local fallbackVisibleInput = nil

  for _, input in ipairs(linkedInputs) do
    if input ~= nil and type(input.Insert) == "function" and isInputShown(input) then
      if isInputFocused(input) then
        return input
      end
      if allowVisibleWithoutFocus and fallbackVisibleInput == nil then
        fallbackVisibleInput = input
      end
    end
  end

  return fallbackVisibleInput
end

local function tryInsertLink(link, options)
  if link == nil then
    return false
  end

  options = options or {}
  local input = findInputForInsertion(options.allowVisibleWithoutFocus == true)
  if input == nil then
    return false
  end

  -- Classic vanilla shift-click of a quest produces plain `[Name (id)]` text
  -- with no |H...|h envelope. Rewrite to a real hyperlink so the link is
  -- clickable in the composer and survives transmission to the recipient.
  local insertable = link
  if type(insertable) == "string" then
    insertable = QuestLinkClassic.Rewrite(insertable)
  end

  -- ponytail: one insert per frame. A single shift-click fans out into several
  -- Blizzard insert paths (player-link handler, SetItemRef modified-click
  -- fallback, our SetItemRef post-hook). Only the first — the plain
  -- whisperable name — should land. GetTime() is constant within a frame.
  local now = type(_G.GetTime) == "function" and _G.GetTime() or nil
  if now ~= nil and now == lastInsertFrameTime then
    return true -- already inserted this frame; report handled so callers don't fall back
  end
  lastInsertFrameTime = now

  input:Insert(insertable)
  return true
end

local function safeHookGlobal(functionName, handler)
  local ok = pcall(_G.hooksecurefunc, functionName, handler)
  return ok
end

local function safeHookMethod(target, methodName, handler)
  if type(target) ~= "table" then
    return false
  end
  local ok = pcall(_G.hooksecurefunc, target, methodName, handler)
  return ok
end

-- Never assign to a Blizzard global or a ChatFrameUtil field, not even to put
-- Blizzard's own function back: any write from addon code taints that slot for
-- the whole session. Blizzard's later reads of it (opening chat, inserting a
-- link, pressing Enter) then run tainted, and in an encounter the game blocks
-- the player's own chat message and blames this addon. Post-hooks through
-- hooksecurefunc keep Blizzard's function in place and its callers untainted.
--
-- Shift-click inserts end in InsertLink. The post-hook adds the link to our
-- composer only while it has focus and no Blizzard chat box is open (an open
-- one already got the link from Blizzard). A click can reach more than one
-- hook; the one-insert-per-frame dedupe in tryInsertLink keeps a single copy.
local function blizzardChatBoxActive()
  local util = _G.ChatFrameUtil
  local getActiveWindow = type(util) == "table" and util.GetActiveWindow or _G.ChatEdit_GetActiveWindow
  return type(getActiveWindow) == "function" and getActiveWindow() ~= nil
end

local function insertFromBlizzard(link)
  if _G._wmSuspended or type(link) ~= "string" or link == "" or blizzardChatBoxActive() then
    return
  end
  tryInsertLink(link, { allowVisibleWithoutFocus = false })
end

local function playerNameFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return string.match(link, "^player%a*:([^:]+)")
end

local function isBattleNetPlayerLink(link)
  return type(link) == "string" and string.find(link, "BNplayer", 1, true) == 1
end

local function isPlayerLink(link)
  return type(link) == "string" and string.find(link, "player", 1, true) == 1
end

-- A player name shift-clicked in our own window: inserts the plain name into
-- the focused composer and returns true, so the caller can keep the click
-- away from Blizzard's SetItemRef (with no Blizzard chat box open it sends a
-- /who for the name). Returns false when the composer did not take it.
function LinkHooks.InsertClickedPlayerName(link)
  local playerName = playerNameFromLink(link)
  if playerName == nil or _G._wmSuspended or not ChatLinkSources.IsChatLinkClick() then
    return false
  end
  return tryInsertLink(playerName, { allowVisibleWithoutFocus = false })
end

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  -- SetItemRef: handles clicking hyperlinks inside chat bubbles / transcript.
  safeHookGlobal("SetItemRef", function(link, text)
    if _G._wmSuspended then
      return
    end
    -- Our URL links only copy their address; they are never inserted.
    if link == nil or UrlFormatter.ExtractExternalUrlFromLink(link) ~= nil then
      return
    end
    -- A shift-clicked player name inserts the plain name, as Blizzard does
    -- for its own open chat box (Blizzard also sends a /who when none is
    -- open). This hook only sees clicks outside our window, or in it while
    -- the composer had no focus: with focus, our window's click script puts
    -- the name in through InsertClickedPlayerName and never calls SetItemRef.
    -- Blizzard ignores shift-clicked Battle.net names so the encoded account
    -- name never reaches chat; so do we. Any other click on a player name
    -- (right-click menu, plain click) inserts nothing: the server refuses a
    -- sent |Hplayer link ("Invalid escape code in chat message").
    local playerName = playerNameFromLink(link)
    if isBattleNetPlayerLink(link) or isPlayerLink(link) then
      if playerName ~= nil and ChatLinkSources.IsChatLinkClick() then
        insertFromBlizzard(playerName)
      end
      return
    end

    local linkToInsert = link
    if type(text) == "string" and text ~= "" and string.find(text, "|H", 1, true) then
      linkToInsert = text
    elseif type(link) == "string" and string.find(link, "quest:", 1, true) and type(text) == "string" and text ~= "" then
      linkToInsert = "|H" .. link .. "|h" .. text .. "|h"
    end

    -- Only insert into the messenger composer when it currently has focus.
    -- Otherwise clicking a chat-bubble link (or anything routed through
    -- SetItemRef) would silently dump the link into our editbox even when
    -- the user expected the default behavior (open quest log, show tooltip).
    tryInsertLink(linkToInsert, { allowVisibleWithoutFocus = false })
  end)

  safeHookMethod(_G.ChatFrameUtil, "InsertLink", insertFromBlizzard)
  safeHookGlobal("ChatEdit_InsertLink", insertFromBlizzard)
  ChatLinkSources.Register(insertFromBlizzard)

  registeredLinkHooks = true
end

function LinkHooks.RegisterInput(input)
  table.insert(linkedInputs, 1, input)
  registerLinkHooks()
end

ns.ComposerLinkHooks = LinkHooks
return LinkHooks
