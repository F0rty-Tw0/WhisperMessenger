local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local QuickReplies = ns.QuickReplies or require("WhisperMessenger.Model.QuickReplies")
local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- "Quick replies" section of the Behavior page: the saved replies, each with
-- a remove button, and an add button (up to QuickReplies.MAX_ENTRIES).
local QuickRepliesSettings = {}

local ROW_HEIGHT = PickerStyles.ROW_HEIGHT
local REMOVE_SIZE = 16
-- Add button alpha once the list holds QuickReplies.MAX_ENTRIES.
local FULL_LIST_ADD_ALPHA = 0.5
local ADD_DIALOG_NAME = "WHISPER_MESSENGER_ADD_QUICK_REPLY"

local function text(key)
  return Localization.Text(key)
end

local function paintRemove(button, hovered)
  UIHelpers.applyVertexColor(button.icon, hovered and Theme.COLORS.danger_text or Theme.COLORS.action_icon or Theme.COLORS.text_secondary)
end

local function createRow(factory, list, onRemove)
  local row = factory.CreateFrame("Frame", nil, list)
  row:SetHeight(ROW_HEIGHT)

  local removeButton = factory.CreateFrame("Button", nil, row)
  removeButton:SetSize(REMOVE_SIZE, REMOVE_SIZE)
  removeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  removeButton.icon = removeButton:CreateTexture(nil, "ARTWORK")
  removeButton.icon:SetAllPoints(removeButton)
  removeButton.icon:SetTexture(Theme.TEXTURES.trash_icon)
  paintRemove(removeButton, false)
  removeButton:SetScript("OnEnter", function(self)
    paintRemove(self, true)
    PickerStyles.ShowTooltipText(self, text("Remove"))
  end)
  removeButton:SetScript("OnLeave", function(self)
    paintRemove(self, false)
    PickerStyles.HideTooltip()
  end)
  removeButton:SetScript("OnClick", function()
    PickerStyles.HideTooltip()
    onRemove(row.index)
  end)
  row.removeButton = removeButton

  local label = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetPoint("RIGHT", removeButton, "LEFT", -8, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  UIHelpers.setTextColor(label, Theme.COLORS.text_primary)
  row.label = label
  return row
end

-- options = { config, panel, onChange, onLayoutChanged }. Returns the section
-- with `bottom` (the frame the next control anchors below).
function QuickRepliesSettings.Create(factory, frame, anchor, options)
  local config = options.config
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  UIHelpers.setTextColor(title, Theme.COLORS.text_secondary)

  local list = factory.CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

  local section = { rows = {} }
  local addButton

  local function redraw()
    local replies = QuickReplies.List(config.quickReplies)
    title:SetText(string.format("%s (%d/%d)", text("Quick replies"), #replies, QuickReplies.MAX_ENTRIES))
    for index, reply in ipairs(replies) do
      local row = section.rows[index]
      if row == nil then
        row = createRow(factory, list, section.remove)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        section.rows[index] = row
      end
      row.index = index
      row:SetWidth(width)
      row.label:SetText(reply)
      row:Show()
    end
    for index = #replies + 1, #section.rows do
      section.rows[index]:Hide()
    end
    list:SetSize(width, math.max(#replies * ROW_HEIGHT, 1))
    addButton:SetAlpha(QuickReplies.CanAdd(config.quickReplies) and 1 or FULL_LIST_ADD_ALPHA)
  end

  local function save(nextList)
    if nextList == nil then
      return
    end
    options.onChange("quickReplies", nextList)
    config.quickReplies = nextList
    redraw()
    if options.onLayoutChanged then
      options.onLayoutChanged()
    end
  end

  function section.remove(index)
    save(QuickReplies.Remove(config.quickReplies, index))
  end

  addButton = options.panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Add quick reply"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = width, ghost = true }
    ),
    { type = "optionButton" }
  )
  addButton:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)
  addButton:SetScript("OnClick", function()
    if not QuickReplies.CanAdd(config.quickReplies) then
      return
    end
    TextInputDialog.Show(ADD_DIALOG_NAME, {
      prompt = text("Add quick reply"),
      accept = text("Add"),
      maxBytes = TextLimits.INPUT_MAX_BYTES,
      onAccept = function(typed)
        save(QuickReplies.Add(config.quickReplies, typed))
      end,
    })
  end)
  section.bottom = addButton

  function section.refreshTheme()
    UIHelpers.setTextColor(title, Theme.COLORS.text_secondary)
    for _, row in ipairs(section.rows) do
      UIHelpers.setTextColor(row.label, Theme.COLORS.text_primary)
      paintRemove(row.removeButton, false)
    end
  end

  function section.refreshLayout(nextWidth)
    width = nextWidth
    redraw()
  end

  function section.setLanguage()
    addButton.label:SetText(text("Add quick reply"))
    redraw()
  end

  redraw()
  return section
end

ns.MessengerWindowQuickRepliesSettings = QuickRepliesSettings
return QuickRepliesSettings
