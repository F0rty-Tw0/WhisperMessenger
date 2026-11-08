local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local DataBroker = ns.MinimapIconDataBroker or require("WhisperMessenger.UI.MinimapIcon.DataBroker")
local ChatCover = ns.BootstrapWindowCoordinatorChatCover or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.ChatCover")

-- One count (unread whispers plus the panels' badges) and one preview feed
-- every icon surface: the widget icon, the minimap icon, the
-- LibDataBroker text and the addon compartment entry.
local IconSurfaces = {}

--- The icon number (unread whispers plus the panels' badges) and the
-- whispers inside it: the glow and the tooltip split follow whispers only.
-- @param panelRegistry table|nil — nil before the runtime is bound
-- @return number total, number unread
function IconSurfaces.Counts(contacts, panelRegistry)
  local unread = BadgeFilter.SumWhisperUnread(contacts)

  return unread + (panelRegistry and panelRegistry.badgeSum() or 0), unread
end

local function setCount(surface, total, unread)
  if surface and surface.setUnreadCount then
    surface.setUnreadCount(total, unread)
  end
end

--- Puts the number on every surface given; a nil one is skipped.
function IconSurfaces.ShowCounts(total, unread, icon, minimap, ldb)
  setCount(icon, total, unread)
  setCount(minimap, total, unread)
  if ldb then
    ldb.unread = total
    ldb.whispers = unread
    ldb.text = DataBroker.FormatText(unread, total - unread)
  end
end

local function setExternalPulse(icon, on)
  if icon and icon.setExternalPulse then
    icon.setExternalPulse(on)
  end
end

-- An external preview (another addon's) holds the widget until an own
-- whisper newer than it arrives; that whisper drops it, and so does turning
-- the widget preview off. True when shown on target (the widget, or the
-- detached card). Its pulse flag goes to pulseIcon (the widget, may be nil)
-- and follows it; every other path switches the external pulse off.
local function showExternalPreview(target, pulseIcon, preview, surfaces)
  local external = surfaces.getExternalPreview and surfaces.getExternalPreview() or nil
  if external == nil then
    setExternalPulse(pulseIcon, false)
    return false
  end
  local previewsOff = surfaces.previewsOff and surfaces.previewsOff()
  if target.setExternalPreview and not previewsOff and not (preview and (tonumber(preview.sentAt) or 0) > external.stamp) then
    target.setExternalPreview(external)
    setExternalPulse(pulseIcon, external.pulse == true)
    return true
  end
  setExternalPulse(pulseIcon, false)
  if surfaces.dropExternalPreview then
    surfaces.dropExternalPreview()
  end
  return false
end

-- surfaces: { getWindow, isWindowVisible, buildMessagePreview, getIcon,
-- getMinimapIcon, getLdbObject, getCompartment?, getExternalPreview?,
-- dropExternalPreview?, previewsOff?, getPanelRegistry?, getDetachedPreview?,
-- previewDetached? }. While previewDetached() is true the detached card (not
-- the widget or minimap card) takes the preview.
function IconSurfaces.Update(contacts, surfaces)
  -- Suppress the icon-anchored previews only when the Whispers tab is
  -- actually showing — the full conversation is already on screen and the
  -- popup would be redundant. On the Groups tab, or under an addon panel or
  -- the options pane, the whisper isn't visible, so the popup is still the
  -- user's only surface. Compact layout: the docked button hides its card
  -- anyway (IncomingPreview.setSuppressed), on those views too.
  local registry = surfaces.getPanelRegistry and surfaces.getPanelRegistry()
  local total, unread = IconSurfaces.Counts(contacts, registry)
  local window = surfaces.getWindow()
  local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or "whispers"
  local whispersVisibleInPane = surfaces.isWindowVisible() and tabMode == "whispers" and not ChatCover.IsCovered(window)
  local preview = not whispersVisibleInPane and surfaces.buildMessagePreview(contacts) or nil
  local previewSender = preview and preview.senderName or nil
  local previewText = preview and preview.messageText or nil
  local previewClass = preview and preview.classTag or nil

  local icon = surfaces.getIcon()
  local minimap = surfaces.getMinimapIcon()
  IconSurfaces.ShowCounts(total, unread, icon, minimap, surfaces.getLdbObject())
  setCount(surfaces.getCompartment and surfaces.getCompartment(), total, unread)
  local detachedCard = surfaces.getDetachedPreview and surfaces.getDetachedPreview() or nil
  local detached = surfaces.previewDetached and surfaces.previewDetached() and detachedCard or nil
  if detached then
    if not showExternalPreview(detached, icon, preview, surfaces) then
      detached.setIncomingPreview(previewSender, previewText, previewClass, preview)
    end
    if icon and icon.setIncomingPreview then
      icon.setIncomingPreview(nil, nil, nil)
    end
  elseif icon and icon.setIncomingPreview and not showExternalPreview(icon, icon, preview, surfaces) then
    icon.setIncomingPreview(previewSender, previewText, previewClass, preview)
  end

  if minimap and minimap.setIncomingPreview then
    -- The minimap preview floats on UIParent, so it must not pop (or
    -- linger) while the minimap icon itself is hidden (icon mode "widget").
    if not detached and (not minimap.isShown or minimap.isShown()) then
      minimap.setIncomingPreview(previewSender, previewText, previewClass, preview)
    else
      minimap.setIncomingPreview(nil, nil, nil)
    end
  end

  if detachedCard and not detached then
    detachedCard.setIncomingPreview(nil, nil, nil)
  end

  -- Every unread change ends here, so this is where panels hear of one.
  if registry and registry.observeUnread then
    registry.observeUnread(contacts)
  end
end

ns.BootstrapWindowCoordinatorIconSurfaces = IconSurfaces
return IconSurfaces
