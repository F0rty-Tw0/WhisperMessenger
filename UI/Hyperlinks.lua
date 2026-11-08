local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")
local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")
local CombatItemRef = ns.UIHyperlinksCombatItemRef or require("WhisperMessenger.UI.Hyperlinks.CombatItemRef")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

local function restoreTrailingEmojiToken(hyperlink)
  local link, display = string.match(hyperlink, "^|H(.-)|h(.-)|h$")
  if UrlFormatter.ExtractExternalUrlFromLink(link) == nil then
    return nil
  end

  local key = string.match(link, ":([%a%d_]+)$")
  if key == nil or not string.match(display, ":" .. key .. "$") or ReactionAssets.GetInlineTextureMarkup(key) == nil then
    return nil
  end

  return "|H" .. link .. ":|h" .. display .. ":|h"
end

local function formatEmojiInPlainSegments(value)
  local output = {}
  local cursor = 1

  while cursor <= #value do
    local hyperlinkStart, hyperlinkEnd = string.find(value, "|H.-|h.-|h", cursor)
    if hyperlinkStart == nil then
      table.insert(output, ReactionAssets.FormatTextForDisplay(string.sub(value, cursor)))
      break
    end

    if hyperlinkStart > cursor then
      table.insert(output, ReactionAssets.FormatTextForDisplay(string.sub(value, cursor, hyperlinkStart - 1)))
    end

    local hyperlink = string.sub(value, hyperlinkStart, hyperlinkEnd)
    local restored = restoreTrailingEmojiToken(hyperlink)
    if restored ~= nil and string.sub(value, hyperlinkEnd + 1, hyperlinkEnd + 3) == "|r:" then
      table.insert(output, restored .. "|r")
      cursor = hyperlinkEnd + 4
    else
      table.insert(output, hyperlink)
      cursor = hyperlinkEnd + 1
    end
  end

  return table.concat(output)
end

local function formatPlainSegment(segment)
  return formatEmojiInPlainSegments(UrlFormatter.FormatPlainSegment(segment))
end

-- Link types whose GameTooltip:SetHyperlink has a side effect instead of a
-- tooltip: `trade` opens the profession window. Hovering shows nothing for
-- these (same as Blizzard chat); clicking still routes through SetItemRef.
local NO_HOVER_TOOLTIP_TYPES = { trade = true }

local Hyperlinks = {}

local function resolveManualCopy()
  if type(ns.ChatBubbleContextMenuManualCopy) == "table" then
    return ns.ChatBubbleContextMenuManualCopy
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, "WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy")
    if ok and type(loaded) == "table" then
      return loaded
    end
  end

  return nil
end

local function resolveLinkHooks()
  if type(ns.ComposerLinkHooks) == "table" then
    return ns.ComposerLinkHooks
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, "WhisperMessenger.UI.Composer.LinkHooks")
    if ok and type(loaded) == "table" then
      return loaded
    end
  end

  return nil
end

local function copyExternalUrl(url)
  -- LaunchURL APIs are protected in addon context and trigger
  -- ADDON_ACTION_FORBIDDEN. Safe fallback is copy-to-clipboard.
  local manualCopy = resolveManualCopy()
  if type(manualCopy) == "table" and type(manualCopy.CopyText) == "function" then
    return manualCopy.CopyText(url) == true
  end

  return false
end

function Hyperlinks.FormatTextForDisplay(text)
  local value = QuestLinkClassic.Rewrite(tostring(text or ""))
  if value == "" then
    return ""
  end

  local output = {}
  local cursor = 1

  while cursor <= #value do
    local hyperlinkStart, hyperlinkEnd = string.find(value, "|H.-|h.-|h", cursor)
    if hyperlinkStart == nil then
      table.insert(output, formatPlainSegment(string.sub(value, cursor)))
      break
    end

    if hyperlinkStart > cursor then
      table.insert(output, formatPlainSegment(string.sub(value, cursor, hyperlinkStart - 1)))
    end

    table.insert(output, string.sub(value, hyperlinkStart, hyperlinkEnd))
    cursor = hyperlinkEnd + 1
  end

  return table.concat(output)
end

function Hyperlinks.HandleClick(link, text, button, sourceFrame)
  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    if copyExternalUrl(externalUrl) then
      return true
    end

    return false
  end

  -- A shift-clicked player name goes straight into the focused composer.
  -- Blizzard's SetItemRef would also send a /who for it, because none of
  -- Blizzard's chat boxes is open while our composer has focus.
  local linkHooks = resolveLinkHooks()
  if linkHooks ~= nil and linkHooks.InsertClickedPlayerName(link) then
    return true
  end

  if type(_G.SetItemRef) == "function" then
    _G.SetItemRef(link, text, button, sourceFrame)
    return true
  end

  return false
end

function Hyperlinks.HandleEnter(owner, link)
  if type(link) == "string" then
    local linkType = string.match(link, "^|H([^:|]+):") or string.match(link, "^([^:|]+):")
    if linkType and NO_HOVER_TOOLTIP_TYPES[string.lower(linkType)] then
      return
    end
  end

  local tooltip = _G.GameTooltip
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
    return
  end

  tooltip:SetOwner(owner, "ANCHOR_CURSOR")

  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(externalUrl)
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
    return
  end

  if type(tooltip.SetHyperlink) == "function" then
    local ok = pcall(tooltip.SetHyperlink, tooltip, link)
    if ok then
      if type(tooltip.Show) == "function" then
        tooltip:Show()
      end
      return
    end
  end

  if type(tooltip.SetText) == "function" then
    tooltip:SetText(tostring(link or ""))
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

function Hyperlinks.HandleLeave()
  if type(_G.GameTooltip) == "table" and type(_G.GameTooltip.Hide) == "function" then
    _G.GameTooltip:Hide()
  end
end

local function blizzardChatClickHandler()
  local mixin = _G.ChatFrameMixin
  if type(mixin) ~= "table" or type(mixin.OnHyperlinkClick) ~= "function" then
    return nil
  end
  return mixin.OnHyperlinkClick
end

local function routeClick(frame, link, text, button)
  -- Our composer has focus: a shift-clicked player name only goes into it.
  -- Blizzard's handler would also send a /who (none of its chat boxes is open).
  local linkHooks = resolveLinkHooks()
  if linkHooks ~= nil and linkHooks.InsertClickedPlayerName(link) then
    return
  end

  if CombatItemRef.TryPin(link) then
    return
  end

  local chatClickHandler = blizzardChatClickHandler()
  if chatClickHandler == nil then
    Hyperlinks.HandleClick(link, text, button, frame)
    return
  end

  chatClickHandler(frame, link, text, button)
  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    copyExternalUrl(externalUrl)
  end
end

-- Link clicks on frame. The script is addon code, so the click runs tainted
-- whatever it calls, even Blizzard's own chat-frame click handler (a plain
-- item click in combat then made ShowUIPanel print "Interface action
-- failed"). Clicks go to that handler, except a shift-clicked player name for
-- the focused composer and a plain tooltip-link click in combat
-- (CombatItemRef). Without the handler, the click goes through HandleClick.
-- onLinkClick runs once after every click, even when a handler throws (the
-- error is rethrown after it, so it still surfaces).
function Hyperlinks.BindClick(frame, onLinkClick)
  frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
    local routed, err = pcall(routeClick, self, link, text, button)
    if onLinkClick then
      onLinkClick()
    end
    if not routed then
      error(err, 0)
    end
  end)
end

-- Links in a frame's text: hover shows the tooltip, click (and shift-click
-- into chat) works as in the transcript. onLinkClick, when given, runs after
-- each link click.
function Hyperlinks.EnableOn(frame, onLinkClick)
  frame:EnableMouse(true)
  if frame.SetHyperlinksEnabled then
    frame:SetHyperlinksEnabled(true)
  end
  frame:SetScript("OnHyperlinkEnter", function(self, link)
    Hyperlinks.HandleEnter(self, link)
  end)
  frame:SetScript("OnHyperlinkLeave", function()
    Hyperlinks.HandleLeave()
  end)
  Hyperlinks.BindClick(frame, onLinkClick)
end

ns.UIHyperlinks = Hyperlinks
return Hyperlinks
