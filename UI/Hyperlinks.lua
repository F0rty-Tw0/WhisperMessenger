local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")
local QuestLinkText = ns.QuestLinkText or require("WhisperMessenger.Model.QuestLinkText")
local LinkClicks = ns.UIHyperlinksLinkClicks or require("WhisperMessenger.UI.Hyperlinks.LinkClicks")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local PlayerLinkCodec = ns.UIHyperlinksPlayerLinkCodec or require("WhisperMessenger.UI.Hyperlinks.PlayerLinkCodec")

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

function Hyperlinks.FormatTextForDisplay(text)
  local value = QuestLinkText.Rewrite(tostring(text or ""))
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

    table.insert(output, PlayerLinkCodec.Encode(string.sub(value, hyperlinkStart, hyperlinkEnd)))
    cursor = hyperlinkEnd + 1
  end

  return table.concat(output)
end

-- Player links in text shown in our frames go through this, so the secure
-- link template's SetItemRef ignores them (no /who on a shift-click) and our
-- click hook routes them instead (LinkClicks.BindClick).
Hyperlinks.EncodePlayerLinks = PlayerLinkCodec.Encode

Hyperlinks.HandleClick = LinkClicks.HandleClick

function Hyperlinks.HandleEnter(owner, link)
  if type(link) == "string" then
    link = PlayerLinkCodec.DecodeLink(link)
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

-- Link click routing lives in Hyperlinks/LinkClicks.lua.
Hyperlinks.BindClick = LinkClicks.BindClick
Hyperlinks.LinkFrameTemplate = LinkClicks.LinkFrameTemplate
Hyperlinks.CreateLinkFrame = LinkClicks.CreateLinkFrame

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
  LinkClicks.BindClick(frame, onLinkClick)
end

ns.UIHyperlinks = Hyperlinks
return Hyperlinks
