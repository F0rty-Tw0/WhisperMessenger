local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Hover tooltip for a settings slider row. tooltip: one line (string) or
-- an array of lines; the first is the title.
local SliderTooltip = {}

function SliderTooltip.Attach(row, tooltip)
  if not tooltip or not row.SetScript then
    return
  end
  local lines = type(tooltip) == "table" and tooltip or { tooltip }
  row:SetScript("OnEnter", function()
    if _G.GameTooltip and _G.GameTooltip.SetOwner then
      _G.GameTooltip:SetOwner(row, "ANCHOR_TOP")
      _G.GameTooltip:SetText(lines[1])
      for i = 2, #lines do
        if _G.GameTooltip.AddLine then
          pcall(_G.GameTooltip.AddLine, _G.GameTooltip, lines[i], 1, 1, 1)
        end
      end
      _G.GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function()
    if _G.GameTooltip and _G.GameTooltip.Hide then
      _G.GameTooltip:Hide()
    end
  end)
end

ns.SettingsControlsSliderTooltip = SliderTooltip

return SliderTooltip
