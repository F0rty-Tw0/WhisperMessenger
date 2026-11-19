local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UrlFormatter = ns.UIHyperlinksUrlFormatter or require("WhisperMessenger.UI.Hyperlinks.UrlFormatter")
local CombatItemRef = ns.UIHyperlinksCombatItemRef or require("WhisperMessenger.UI.Hyperlinks.CombatItemRef")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local PlayerLinkCodec = ns.UIHyperlinksPlayerLinkCodec or require("WhisperMessenger.UI.Hyperlinks.PlayerLinkCodec")

local LinkClicks = {}

local INLINE_LINK_TEMPLATE = "InlineHyperlinkFrameTemplate"

-- Template for a frame that shows links. With InlineHyperlinkFrameTemplate
-- the game runs its own secure click handler; flavors without it get
-- extraTemplate alone (may be nil). The second value says which one it is.
function LinkClicks.LinkFrameTemplate(extraTemplate)
  if not FlavorCompat.HasTemplate(INLINE_LINK_TEMPLATE) then
    return extraTemplate, false
  end
  if extraTemplate == nil then
    return INLINE_LINK_TEMPLATE, true
  end
  return extraTemplate .. ", " .. INLINE_LINK_TEMPLATE, true
end

-- Builds a link frame with LinkFrameTemplate and marks it _wmSecureLinks
-- when it asked for the secure template and the frame has the template's
-- click script. A frame marked secure gets no click script of its own (see
-- BindClick), so one that lost the template would have dead links. The flag
-- is decided once per frame: a pooled frame handed out again may carry our
-- own click script from BindClick, which is not the template's.
function LinkClicks.CreateLinkFrame(factory, frameType, name, parent, extraTemplate)
  local template, usedSecure = LinkClicks.LinkFrameTemplate(extraTemplate)
  local frame = factory.CreateFrame(frameType, name, parent, template)
  if frame._wmSecureLinks == nil then
    frame._wmSecureLinks = usedSecure and frame.GetScript ~= nil and frame:GetScript("OnHyperlinkClick") ~= nil
  end
  return frame
end

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

function LinkClicks.HandleClick(link, text, button, sourceFrame)
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

local function blizzardChatClickHandler()
  local mixin = _G.ChatFrameMixin
  if type(mixin) ~= "table" or type(mixin.OnHyperlinkClick) ~= "function" then
    return nil
  end
  return mixin.OnHyperlinkClick
end

local function routeClick(frame, link, text, button)
  link = PlayerLinkCodec.DecodeLink(link)
  text = PlayerLinkCodec.DecodeText(text)

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
    LinkClicks.HandleClick(link, text, button, frame)
    return
  end

  chatClickHandler(frame, link, text, button)
  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    copyExternalUrl(externalUrl)
  end
end

-- After the template's own click (Blizzard code calling SetItemRef), handles
-- what SetItemRef skips: our encoded player links (it ignores addon links) and
-- URL links. Every other link was already handled by the template.
local function afterSecureClick(frame, link, text, button)
  if PlayerLinkCodec.IsEncoded(link) then
    routeClick(frame, link, text, button)
    return
  end

  local externalUrl = UrlFormatter.ExtractExternalUrlFromLink(link)
  if externalUrl ~= nil then
    copyExternalUrl(externalUrl)
  end
end

local function onSecureLinkClick(self, link, text, button)
  local routed, err = pcall(afterSecureClick, self, link, text, button)
  if self._wmOnLinkClick then
    self._wmOnLinkClick()
  end
  if not routed then
    error(err, 0)
  end
end

-- Link clicks on frame. onLinkClick runs once after every click, even when
-- our routing throws (the error is rethrown after it, so it still surfaces).
-- On a secure frame it runs from a post-hook, so it may not run at all when
-- the template's own handler (Blizzard's SetItemRef) throws first.
--
-- A frame with the secure template (_wmSecureLinks) keeps the template's own
-- click script, so a click opens Blizzard windows untainted. BindClick only
-- post-hooks it (once per frame; a rebind swaps the callback) for encoded
-- player links and URL links, see afterSecureClick.
--
-- Any other frame gets an addon click script, so the click runs tainted
-- whatever it calls, even Blizzard's own chat-frame click handler (a plain
-- item click in combat then made ShowUIPanel print "Interface action
-- failed"). Clicks go to that handler, except a shift-clicked player name for
-- the focused composer and a plain tooltip-link click in combat
-- (CombatItemRef). Without the handler, the click goes through HandleClick.
function LinkClicks.BindClick(frame, onLinkClick)
  if frame._wmSecureLinks then
    frame._wmOnLinkClick = onLinkClick
    if not frame._wmSecureClickHooked then
      frame:HookScript("OnHyperlinkClick", onSecureLinkClick)
      frame._wmSecureClickHooked = true
    end
    return
  end

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

ns.UIHyperlinksLinkClicks = LinkClicks
return LinkClicks
