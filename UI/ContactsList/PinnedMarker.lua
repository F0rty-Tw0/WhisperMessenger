local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Small solid pushpin shown in the pin slot (under the timestamp) on pinned
-- rows. It is the "pinned" signal at rest; on hover the Unpin button takes
-- the same slot. The unread badge owns that corner, so the marker hides
-- while a row has unread messages.
local PinnedMarker = {}

local function wanted(row)
  local item = row.item
  return item ~= nil and item.pinned == true and (item.unreadCount or 0) == 0
end

-- Create once per pooled row (centered on the pin button) and refresh.
function PinnedMarker.update(row)
  if row.pinnedMarker == nil then
    if not wanted(row) or row.pinButton == nil then
      return
    end
    local marker = row:CreateTexture(nil, "OVERLAY")
    marker:SetPoint("CENTER", row.pinButton, "CENTER", 0, 0)
    marker:SetTexture(Theme.TEXTURES.pinned_marker)
    row.pinnedMarker = marker
  end
  local glyphSize = Theme.LAYOUT.CONTACT_ACTION_SIZE - 2
  row.pinnedMarker:SetSize(glyphSize, glyphSize)
  UIHelpers.applyVertexColor(row.pinnedMarker, Theme.COLORS.text_secondary)
  PinnedMarker.setVisible(row, true)
end

-- Show the marker only when wanted; `visible = false` hides it (hover).
function PinnedMarker.setVisible(row, visible)
  if row.pinnedMarker == nil then
    return
  end
  row.pinnedMarker:SetShown(visible and wanted(row))
end

ns.ContactsListPinnedMarker = PinnedMarker
return PinnedMarker
