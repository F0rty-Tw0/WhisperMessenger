local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Popover = ns.ComposerPopover or require("WhisperMessenger.UI.Composer.Popover")

-- List of quick replies above the composer; clicking one hands its text to
-- onSelect. Rebuilt on every open so settings edits show up immediately.
local QuickReplyPicker = {}

local ROW_WIDTH = 260
local ROW_HEIGHT = PickerStyles.ROW_HEIGHT
local PADDING = 6
local LABEL_INSET = 8

local function createRow(factory, frame, picker, onSelect)
  local row = factory.CreateFrame("Button", nil, frame)
  row:SetSize(ROW_WIDTH, ROW_HEIGHT)

  local highlight = row:CreateTexture(nil, "BACKGROUND")
  highlight:SetAllPoints(row)
  PickerStyles.ApplyColor(highlight, PickerStyles.HighlightColor(0.35))
  highlight:Hide()
  row._highlight = highlight

  local label = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  label:SetPoint("LEFT", row, "LEFT", LABEL_INSET, 0)
  label:SetWidth(ROW_WIDTH - LABEL_INSET * 2)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  UIHelpers.setTextColor(label, Theme.COLORS.text_primary)
  row.label = label

  row:SetScript("OnEnter", function()
    if picker.enabled then
      highlight:Show()
    end
  end)
  row:SetScript("OnLeave", function()
    highlight:Hide()
  end)
  row:SetScript("OnClick", function()
    if not picker.enabled or row.replyText == nil then
      return
    end
    picker:close()
    onSelect(row.replyText)
  end)
  return row
end

function QuickReplyPicker.Create(factory, parent, anchorFrame, getReplies, onSelect)
  local popover = Popover.Create(factory, parent, anchorFrame)
  local frame = popover.frame
  local picker = { frame = frame, rows = {}, enabled = true }

  -- Returns the number of replies listed.
  local function rebuild()
    local replies = getReplies() or {}
    for index, text in ipairs(replies) do
      local row = picker.rows[index]
      if row == nil then
        row = createRow(factory, frame, picker, onSelect)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING - (index - 1) * ROW_HEIGHT)
        picker.rows[index] = row
      end
      row.replyText = text
      row.label:SetText(text)
      row:Show()
    end
    for index = #replies + 1, #picker.rows do
      picker.rows[index].replyText = nil
      picker.rows[index]:Hide()
    end
    frame:SetSize(ROW_WIDTH + PADDING * 2, #replies * ROW_HEIGHT + PADDING * 2)
    return #replies
  end

  -- Nothing to list -> stays closed.
  function picker:open()
    if not self.enabled or rebuild() == 0 then
      return false
    end
    popover.open()
    return true
  end

  function picker:close()
    popover.close()
  end

  function picker:toggle()
    if frame:IsShown() then
      popover.close()
      return false
    end
    return self:open()
  end

  function picker:setEnabled(enabled)
    self.enabled = enabled == true
    if not self.enabled then
      popover.close()
    end
  end

  function picker:refreshTheme()
    popover.refreshTheme()
    local highlightColor = PickerStyles.HighlightColor(0.35)
    for _, row in ipairs(self.rows) do
      PickerStyles.ApplyColor(row._highlight, highlightColor)
      UIHelpers.setTextColor(row.label, Theme.COLORS.text_primary)
    end
  end

  return picker
end

ns.ComposerQuickReplyPicker = QuickReplyPicker
return QuickReplyPicker
