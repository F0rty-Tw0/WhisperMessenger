local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local SettingsPanelFrame = {}

-- Controls start CONTENT_PADDING in from the left; the same gap on the right
-- keeps right-aligned values and button art clear of the scroll clip. The
-- scroll view already narrows its viewport for its own bar.
local function paneInnerWidth(outerWidth)
  local padding = (Theme.CONTENT_PADDING or 16) * 2
  if type(outerWidth) ~= "number" or outerWidth <= 0 then
    return nil
  end
  return outerWidth - padding
end

-- Centers the page's control column in a wide pane: the page frame is
-- inset by an equal side gap that shrinks to 0 as the pane narrows to the
-- column width. Returns the width the page lays out at.
local function centerColumn(panel, settings, innerWidth)
  local gap = math.max(0, math.floor((innerWidth - Theme.LAYOUT.SETTINGS_CONTROL_WIDTH) / 2))
  local frame = settings.frame
  if frame and frame.ClearAllPoints then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", panel, "TOPLEFT", gap, 0)
    frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -gap, 0)
  end
  return innerWidth - 2 * gap
end

local function createSettingsPanel(factory, parent, createSettingsView, config, onSettingChanged, extraOptions)
  local panel = factory.CreateFrame("Frame", nil, parent)
  panel:SetAllPoints(parent)
  local viewOptions = {
    onChange = onSettingChanged,
    onLayoutChanged = function()
      if panel._wmRemeasure then
        panel._wmRemeasure()
      end
    end,
  }
  for key, value in pairs(extraOptions or {}) do
    viewOptions[key] = value
  end
  local settings = createSettingsView(factory, panel, config, viewOptions)
  -- Propagate the inner panel's bottom marker up to the wrapper so the
  -- options scrollview's per-tab content sizing (in WindowScripts/Buttons)
  -- can find it. centerColumn insets the inner frame sideways only, so its
  -- top lines up with the wrapper's top — the SetPoint-chain walk gives the
  -- same y-down offset whether we start from the wrapper or the inner.
  if settings and settings.frame and settings.frame._wmBottomMarker then
    panel._wmBottomMarker = settings.frame._wmBottomMarker
  end
  if settings and settings.refreshLayout then
    local function relayout(outerWidth)
      local inner = paneInnerWidth(outerWidth)
      if inner then
        settings.refreshLayout(centerColumn(panel, settings, inner))
      end
    end
    panel._wmRelayout = relayout
    if panel.SetScript then
      panel:SetScript("OnSizeChanged", function(_, w)
        relayout(w)
      end)
    end
    if parent.GetWidth then
      relayout(parent:GetWidth())
    end
  end
  return panel, settings
end

SettingsPanelFrame.PaneInnerWidth = paneInnerWidth
SettingsPanelFrame.Create = createSettingsPanel

ns.MessengerWindowSettingsPanelFrame = SettingsPanelFrame

return SettingsPanelFrame
