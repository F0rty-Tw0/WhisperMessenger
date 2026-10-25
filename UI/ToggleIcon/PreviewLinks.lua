local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")

-- Item links in the message preview. A link click must not also run the
-- preview's own click, so it swallows the mouse-up that comes with it. The
-- window keeps a link click the game never follows with a mouse-up from
-- swallowing a later click on the preview.
local PreviewLinks = {}

local LINK_CLICK_WINDOW_SECONDS = 0.5

local function now()
  return type(_G.GetTime) == "function" and _G.GetTime() or 0
end

-- Enables links on frame and sets onMouseUp as its OnMouseUp, skipping a link click's mouse-up.
function PreviewLinks.SetMouseUp(frame, onMouseUp)
  local linkClickedAt = nil
  Hyperlinks.EnableOn(frame, function()
    linkClickedAt = now()
  end)
  frame:SetScript("OnMouseUp", function(self, button)
    local clickedAt = linkClickedAt
    linkClickedAt = nil
    if clickedAt ~= nil and now() - clickedAt <= LINK_CLICK_WINDOW_SECONDS then
      return
    end
    onMouseUp(self, button)
  end)
end

ns.ToggleIconPreviewLinks = PreviewLinks

return PreviewLinks
