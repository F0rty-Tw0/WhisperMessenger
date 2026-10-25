local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local DataBroker = ns.MinimapIconDataBroker or require("WhisperMessenger.UI.MinimapIcon.DataBroker")

-- One unread sum and one preview feed every icon surface: the widget icon,
-- the minimap icon and the LibDataBroker text.
local IconSurfaces = {}

-- An external preview (another addon's) holds the widget until an own
-- whisper newer than it arrives; that whisper drops it. True when shown.
local function showExternalPreview(icon, preview, surfaces)
  local external = surfaces.getExternalPreview and surfaces.getExternalPreview() or nil
  if external == nil then
    return false
  end
  if icon.setExternalPreview and not (preview and (tonumber(preview.sentAt) or 0) > external.stamp) then
    icon.setExternalPreview(external)
    return true
  end
  if surfaces.dropExternalPreview then
    surfaces.dropExternalPreview()
  end
  return false
end

-- surfaces: { getWindow, isWindowVisible, buildMessagePreview, getIcon,
-- getMinimapIcon, getLdbObject, getExternalPreview?, dropExternalPreview? }.
function IconSurfaces.Update(contacts, surfaces)
  -- Suppress the icon-anchored previews only when the Whispers tab is
  -- actually showing — the full conversation is already on screen and the
  -- popup would be redundant. On the Groups tab the whisper isn't visible in
  -- the pane, so the popup is still the user's only surface.
  local unread = BadgeFilter.SumWhisperUnread(contacts)
  local window = surfaces.getWindow()
  local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or "whispers"
  local whispersVisibleInPane = surfaces.isWindowVisible() and tabMode == "whispers"
  local preview = not whispersVisibleInPane and surfaces.buildMessagePreview(contacts) or nil
  local previewSender = preview and preview.senderName or nil
  local previewText = preview and preview.messageText or nil
  local previewClass = preview and preview.classTag or nil

  local icon = surfaces.getIcon()
  if icon and icon.setUnreadCount then
    icon.setUnreadCount(unread)
  end
  if icon and icon.setIncomingPreview and not showExternalPreview(icon, preview, surfaces) then
    icon.setIncomingPreview(previewSender, previewText, previewClass)
  end

  local minimap = surfaces.getMinimapIcon()
  if minimap and minimap.setUnreadCount then
    minimap.setUnreadCount(unread)
  end
  if minimap and minimap.setIncomingPreview then
    -- The minimap preview floats on UIParent, so it must not pop (or
    -- linger) while the minimap icon itself is hidden (icon mode "widget").
    if not minimap.isShown or minimap.isShown() then
      minimap.setIncomingPreview(previewSender, previewText, previewClass)
    else
      minimap.setIncomingPreview(nil, nil, nil)
    end
  end

  local ldb = surfaces.getLdbObject()
  if ldb then
    ldb.unread = unread
    ldb.text = DataBroker.FormatText(unread)
  end
end

ns.BootstrapWindowCoordinatorIconSurfaces = IconSurfaces
return IconSurfaces
