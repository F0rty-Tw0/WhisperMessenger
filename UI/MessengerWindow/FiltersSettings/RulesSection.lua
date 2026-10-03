local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeywordRules = ns.KeywordRules or require("WhisperMessenger.Model.Filters.KeywordRules")
local RemoveButton = ns.RemoveButton or require("WhisperMessenger.UI.Shared.RemoveButton")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local RulePresets = ns.RulePresets or require("WhisperMessenger.Model.Filters.RulePresets")
local BlockedCount = ns.FiltersSettingsBlockedCount or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.BlockedCount")
local RuleDialogs = ns.FiltersSettingsRuleDialogs or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.RuleDialogs")

-- "Keyword rules" section of the Filters page: each rule's name (presets) or
-- words joined by " + " on one truncated line, this session's blocked count
-- below it, an on/off toggle and a remove button, then "Add rule…" and
-- "Reset to Defaults" buttons. Clicking a rule's label edits it.
local RulesSection = {}

local RESET_DIALOG = "WHISPER_MESSENGER_RESET_KEYWORD_RULES"
local GAP = 8
-- Half the space between the name line and the count line, at the row's centre.
local LINE_GAP = 1
-- The syntax lives in the page's "How filters work" section.
local HINT = "Click a rule to edit its words."
local RESET_PROMPT = "Reset keyword rules? Your own rules are deleted and the ready-made ones restored."

local function text(key)
  return Localization.Text(key)
end

-- Reset deletes the player's own rules, so it asks first.
local function confirmReset(onAccept)
  if type(_G.StaticPopup_Show) ~= "function" then
    return
  end
  _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
  _G.StaticPopupDialogs[RESET_DIALOG] = {
    text = text(RESET_PROMPT),
    button1 = text("Reset to Defaults"),
    button2 = text("Cancel"),
    OnAccept = onAccept,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  _G.StaticPopup_Show(RESET_DIALOG)
end

local function singleLine(label)
  label:SetWordWrap(false)
  if label.SetNonSpaceWrap then
    label:SetNonSpaceWrap(false)
  end
  if label.SetMaxLines then
    label:SetMaxLines(1)
  end
end

-- Ready-made titles are English locale keys; a player's own title is shown
-- as typed. A rule without one shows its words.
local function ruleLabel(rule)
  if rule.name == nil then
    return KeywordRules.Format(rule)
  end
  return rule.presetId and text(rule.name) or rule.name
end

-- options = { filters, panel, onLayoutChanged, onFiltersChanged }. Returns
-- the section with `bottom` and `redraw`.
function RulesSection.Create(factory, frame, anchor, options)
  local filters = options.filters
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  local toggleColors = SettingsControls.ToggleColors(Theme)
  local section = { rows = {} }

  local function changed()
    section.redraw()
    options.onFiltersChanged()
  end

  local titleSection = SettingsControls.CreateSectionLabel(frame, text("Keyword rules"))
  titleSection.region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetText(text(HINT))
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetWidth(width)
  hint:SetPoint("TOPLEFT", titleSection.region, "BOTTOMLEFT", 0, -GAP)

  local list = factory.CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -GAP)

  local function createRow()
    local row = factory.CreateFrame("Frame", nil, list)
    local layout = { width = width, height = Theme.FilterRowHeight() }
    row.toggle = UIHelpers.createToggleRow(factory, row, "", false, toggleColors, layout, function(value)
      KeywordRules.SetEnabled(filters, row.index, value)
      options.onFiltersChanged()
    end)
    row.toggle.row:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.toggle.row:Show()
    options.panel:bind(row.toggle, { type = "toggle" })
    row.removeButton = RemoveButton.Create(factory, row, function()
      KeywordRules.Remove(filters, row.index)
      changed()
    end)
    row.removeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    -- The name and count lines meet at the row's centre, level with the toggle.
    local name = row.toggle.label
    singleLine(name)
    name:ClearAllPoints()
    name:SetPoint("BOTTOMLEFT", row, "LEFT", 0, LINE_GAP)
    row.countText = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    row.countText:SetJustifyH("LEFT")
    singleLine(row.countText)
    row.countText:SetPoint("TOPLEFT", row, "LEFT", 0, -LINE_GAP)
    row.countText:SetPoint("TOPRIGHT", row.toggle.dot, "LEFT", -GAP, -LINE_GAP)
    UIHelpers.setTextColor(row.countText, Theme.COLORS.text_secondary)
    row.editButton = factory.CreateFrame("Button", nil, row)
    row.editButton:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.editButton:SetPoint("BOTTOMRIGHT", row.countText, "BOTTOMRIGHT", 0, 0)
    row.editButton:SetScript("OnEnter", function(self)
      PickerStyles.ShowTooltipText(self, KeywordRules.Format(filters.rules[row.index]))
    end)
    row.editButton:SetScript("OnLeave", function()
      PickerStyles.HideTooltip()
    end)
    row.editButton:SetScript("OnClick", function()
      PickerStyles.HideTooltip()
      RuleDialogs.Edit(factory, filters, filters.rules[row.index], changed)
    end)
    return row
  end

  local function toggleWidth()
    return width - RemoveButton.SIZE - GAP
  end

  function section.redraw()
    local rules = filters.rules
    local rowHeight = Theme.FilterRowHeight()
    for index, rule in ipairs(rules) do
      local row = section.rows[index]
      if row == nil then
        row = createRow()
        section.rows[index] = row
      end
      row.index = index
      row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * rowHeight)
      row:SetSize(width, rowHeight)
      row.toggle.setWidth(toggleWidth())
      row.toggle.label:SetText(ruleLabel(rule))
      row.toggle.setValue(rule.enabled ~= false)
      row.countText:SetText(BlockedCount.Text(rule.blocked))
      row:Show()
    end
    for index = #rules + 1, #section.rows do
      section.rows[index]:Hide()
    end
    list:SetSize(width, math.max(#rules * rowHeight, 1))
    if options.onLayoutChanged then
      options.onLayoutChanged()
    end
  end

  local function optionButton(label)
    return options.panel:bind(
      UIHelpers.createOptionButton(
        factory,
        frame,
        text(label),
        SettingsControls.OptionButtonColors(Theme),
        { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = width, ghost = true }
      ),
      { type = "optionButton" }
    )
  end

  local addButton = optionButton("Add rule…")
  addButton:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -GAP)
  addButton:SetScript("OnClick", function()
    RuleDialogs.Add(factory, filters, changed)
  end)

  local resetButton = optionButton("Reset to Defaults")
  resetButton:SetPoint("TOPLEFT", addButton, "BOTTOMLEFT", 0, -GAP)
  resetButton:SetScript("OnClick", function()
    confirmReset(function()
      RulePresets.Reset(filters)
      changed()
    end)
  end)
  section.bottom = resetButton

  function section.refreshTheme()
    titleSection.refreshTheme(Theme)
    UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)
    for _, row in ipairs(section.rows) do
      UIHelpers.setTextColor(row.countText, Theme.COLORS.text_secondary)
      RemoveButton.Paint(row.removeButton, false)
    end
  end

  function section.refreshLayout(nextWidth)
    width = nextWidth
    titleSection.refreshLayout(nextWidth)
    hint:SetWidth(nextWidth)
    section.redraw()
  end

  function section.setLanguage()
    titleSection.label:SetText(text("Keyword rules"))
    hint:SetText(text(HINT))
    addButton.label:SetText(text("Add rule…"))
    resetButton.label:SetText(text("Reset to Defaults"))
    section.redraw()
  end

  section.refreshTheme()
  section.redraw()
  return section
end

ns.FiltersSettingsRulesSection = RulesSection
return RulesSection
