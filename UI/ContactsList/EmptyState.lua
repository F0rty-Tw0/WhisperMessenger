local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject

local EmptyState = {}

-- Side gap between the hint text and the pane edges.
local FALLBACK_SIDE_PADDING = 16

-- Create builds a hidden frame hosting a centered FontString.
-- parent: the contacts list content frame
-- theme: optional theme override (defaults to the shared Theme module)
function EmptyState.Create(parent, theme)
  local resolvedTheme = theme or Theme
  local frame = _G.CreateFrame("Frame", nil, parent)
  -- The scroll content can be taller than the list; centre the hint in
  -- the visible viewport (the content's scroll frame) instead.
  local viewport = parent and parent.GetParent and parent:GetParent() or nil
  frame:SetAllPoints(viewport or parent)
  frame:Hide()

  -- Spans the pane width, so the text wraps to whatever width the pane has.
  local padding = resolvedTheme.CONTENT_PADDING or FALLBACK_SIDE_PADDING
  local label = frame:CreateFontString(nil, "ARTWORK")
  setFontObject(label, (resolvedTheme.FONTS and resolvedTheme.FONTS.empty_state) or "GameFontNormal")
  label:SetPoint("LEFT", frame, "LEFT", padding, 0)
  label:SetPoint("RIGHT", frame, "RIGHT", -padding, 0)
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  label:SetWordWrap(true)
  label:SetText("")

  local colors = resolvedTheme.COLORS or {}
  local textColor = colors.text_secondary or { 0.55, 0.55, 0.62, 1.0 }
  label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1.0)

  frame.label = label
  frame._theme = resolvedTheme

  return frame
end

-- Show makes the empty-state frame visible and sets its message text.
function EmptyState.Show(frame, message)
  frame.label:SetText(message or "")
  local colors = (frame._theme and frame._theme.COLORS) or {}
  local textColor = colors.text_secondary or { 0.55, 0.55, 0.62, 1.0 }
  frame.label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1.0)
  frame:Show()
end

-- Hide makes the empty-state frame invisible and clears the label.
function EmptyState.Hide(frame)
  frame.label:SetText("")
  frame:Hide()
end

ns.ContactsListEmptyState = EmptyState
return EmptyState
