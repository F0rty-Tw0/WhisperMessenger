local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewChrome = ns.ToggleIconPreviewChrome or require("WhisperMessenger.UI.ToggleIcon.PreviewChrome")

-- The preview's optional third line, under the message. Only an addon
-- preview's detail fills it; WM's own whispers keep two lines.
local PreviewDetailRow = {}

function PreviewDetailRow.Create(previewFrame, messageLabel, fontObject)
  local label = previewFrame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(label, fontObject)
  label:SetPoint("TOPLEFT", messageLabel, "BOTTOMLEFT", 0, PreviewMetrics.DETAIL_GAP)
  PreviewChrome.SingleLine(label)
  label:Hide()

  local row = { label = label }

  -- Shows a non-empty string; anything else empties and hides the line.
  function row.render(detail)
    if type(detail) == "string" and detail ~= "" then
      label:SetText(detail)
      label:Show()
    else
      label:SetText("")
      label:Hide()
    end
  end

  -- The label while it shows, for the size fit; nil while hidden.
  function row.shownLabel()
    return label:IsShown() and label or nil
  end

  return row
end

ns.ToggleIconPreviewDetailRow = PreviewDetailRow
return PreviewDetailRow
