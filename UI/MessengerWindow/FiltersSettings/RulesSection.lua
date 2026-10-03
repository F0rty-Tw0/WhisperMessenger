local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeywordRules = ns.KeywordRules or require("WhisperMessenger.Model.Filters.KeywordRules")
local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local RemoveButton = ns.RemoveButton or require("WhisperMessenger.UI.Shared.RemoveButton")

-- "Keyword rules" section of the Filters page: each rule's words joined by
-- " + ", an on/off toggle, its blocked count and a remove button, then an
-- "Add rule…" button.
local RulesSection = {}

local ADD_DIALOG = "WHISPER_MESSENGER_ADD_KEYWORD_RULE"
local RULE_MAX_LETTERS = 128
local ROW_HEIGHT = 24
local GAP = 8
local WORD_SEPARATOR = " + "

local function text(key)
  return Localization.Text(key)
end

-- options = { filters, panel, onLayoutChanged }. Returns the section with
-- `bottom` and `redraw`.
function RulesSection.Create(factory, frame, anchor, options)
  local filters = options.filters
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  local toggleColors = SettingsControls.ToggleColors(Theme)
  local section = { rows = {} }

  local titleSection = SettingsControls.CreateSectionLabel(frame, text("Keyword rules"))
  titleSection.region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetText(text("All words must match"))
  hint:SetJustifyH("LEFT")
  hint:SetPoint("TOPLEFT", titleSection.region, "BOTTOMLEFT", 0, -GAP)

  local list = factory.CreateFrame("Frame", nil, frame)
  list:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -GAP)

  local function createRow()
    local row = factory.CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_HEIGHT)
    row.toggle = UIHelpers.createToggleRow(factory, row, "", false, toggleColors, { width = width, height = ROW_HEIGHT }, function(value)
      KeywordRules.SetEnabled(filters, row.index, value)
    end)
    row.toggle.row:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.toggle.row:Show()
    options.panel:bind(row.toggle, { type = "toggle" })
    row.removeButton = RemoveButton.Create(factory, row, function()
      KeywordRules.Remove(filters, row.index)
      section.redraw()
    end)
    row.removeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.blockedText = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    row.blockedText:SetPoint("RIGHT", row.toggle.dot, "LEFT", -GAP, 0)
    UIHelpers.setTextColor(row.blockedText, Theme.COLORS.text_secondary)
    return row
  end

  local function toggleWidth()
    return width - RemoveButton.SIZE - GAP
  end

  function section.redraw()
    local rules = filters.rules
    for index, rule in ipairs(rules) do
      local row = section.rows[index]
      if row == nil then
        row = createRow()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + GAP))
        section.rows[index] = row
      end
      row.index = index
      row:SetWidth(width)
      row.toggle.setWidth(toggleWidth())
      row.toggle.label:SetText(table.concat(rule.words, WORD_SEPARATOR))
      row.toggle.setValue(rule.enabled ~= false)
      row.blockedText:SetText(string.format(text("Blocked %d"), rule.blocked or 0))
      row:Show()
    end
    for index = #rules + 1, #section.rows do
      section.rows[index]:Hide()
    end
    list:SetSize(width, math.max(#rules * (ROW_HEIGHT + GAP), 1))
    if options.onLayoutChanged then
      options.onLayoutChanged()
    end
  end

  local addButton = options.panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Add rule…"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = width, ghost = true }
    ),
    { type = "optionButton" }
  )
  addButton:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -GAP)
  addButton:SetScript("OnClick", function()
    TextInputDialog.Show(ADD_DIALOG, {
      prompt = text("Add rule…"),
      accept = text("Add"),
      maxLetters = RULE_MAX_LETTERS,
      onAccept = function(typed)
        if KeywordRules.Add(filters, typed) ~= nil then
          section.redraw()
        end
      end,
    })
  end)
  section.bottom = addButton

  function section.refreshTheme()
    titleSection.refreshTheme(Theme)
    UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)
    for _, row in ipairs(section.rows) do
      UIHelpers.setTextColor(row.blockedText, Theme.COLORS.text_secondary)
      RemoveButton.Paint(row.removeButton, false)
    end
  end

  function section.refreshLayout(nextWidth)
    width = nextWidth
    titleSection.refreshLayout(nextWidth)
    section.redraw()
  end

  function section.setLanguage()
    titleSection.label:SetText(text("Keyword rules"))
    hint:SetText(text("All words must match"))
    addButton.label:SetText(text("Add rule…"))
    section.redraw()
  end

  section.refreshTheme()
  section.redraw()
  return section
end

ns.FiltersSettingsRulesSection = RulesSection
return RulesSection
