local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")
local SendButtonStyle = ns.ComposerSendButtonStyle or require("WhisperMessenger.UI.Composer.SendButtonStyle")
local ComposerLimit = ns.ComposerLimit or require("WhisperMessenger.UI.Composer.ComposerLimit")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local ComposerSurface = ns.ComposerSurface or require("WhisperMessenger.UI.Composer.ComposerSurface")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local GlyphCoverage = ns.ThemeGlyphCoverage or require("WhisperMessenger.UI.Theme.GlyphCoverage")
local setTextColor = UIHelpers.setTextColor

-- The preview card's one-line reply input plus send arrow. UI only: the
-- caller decides what a submit, a hold change or a disabled click means.
local PreviewReplyRow = {}

local INPUT_RADIUS = 6
local TEXT_INSET = 8
local SEND_GAP = 2
local COVER_LEVEL_LIFT = 5

local function noop(_) end

local function createInput(factory, rowFrame, theme)
  local input = factory.CreateFrame("EditBox", nil, rowFrame)
  input:SetText("")
  UIHelpers.setFontObject(input, theme.FONTS.composer_input)
  if input.SetTextInsets then
    input:SetTextInsets(TEXT_INSET, TEXT_INSET, 0, 0)
  end
  if input.SetAutoFocus then
    input:SetAutoFocus(false)
  end
  if input.SetAltArrowKeyMode then
    input:SetAltArrowKeyMode(false)
  end
  if input.SetHyperlinksEnabled then
    input:SetHyperlinksEnabled(true)
  end
  return input
end

local function layout(rowFrame, parentFrame, input, sendButton, cover)
  local size = PreviewMetrics.REPLY_ROW_HEIGHT
  -- The gap is the row's bottom margin: it keeps the input off the ~5px HUD tooltip border.
  rowFrame:SetHeight(size)
  rowFrame:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", PreviewMetrics.LEFT_PAD, PreviewMetrics.REPLY_ROW_GAP)
  rowFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -PreviewMetrics.RIGHT_PAD, PreviewMetrics.REPLY_ROW_GAP)
  sendButton:SetSize(size, size)
  sendButton:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
  input:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 0, 0)
  input:SetPoint("BOTTOMRIGHT", sendButton, "BOTTOMLEFT", -SEND_GAP, 0)
  cover:SetAllPoints(rowFrame)
  if cover.SetFrameLevel and rowFrame.GetFrameLevel then
    cover:SetFrameLevel(rowFrame:GetFrameLevel() + COVER_LEVEL_LIFT)
  end
end

-- options = { theme, onSubmit(text) -> bool, onHoldChanged(holding),
-- onFocusChanged(focused), onFocusGained(), onDisabledClick() }
function PreviewReplyRow.Create(factory, parentFrame, options)
  options = options or {}
  local theme = options.theme or Theme
  local onSubmit = options.onSubmit or noop
  local onHoldChanged = options.onHoldChanged or noop
  local onFocusChanged = options.onFocusChanged or noop
  local onFocusGained = options.onFocusGained or noop
  local onDisabledClick = options.onDisabledClick or noop

  local rowFrame = factory.CreateFrame("Frame", nil, parentFrame)
  local input = createInput(factory, rowFrame, theme)
  -- Native WoW HUD: Blizzard's input border instead of the rounded fill.
  local native = Hud.IsOn()
  local fill
  if native then
    ComposerSurface.CreateNativeBorder(input)
  else
    fill = UIHelpers.createRoundedBackground(input, INPUT_RADIUS)
  end
  local sendButton = factory.CreateFrame("Button", nil, rowFrame)
  local paintSend = SendButtonStyle.Create(sendButton)
  local cover = factory.CreateFrame("Frame", nil, rowFrame)
  layout(rowFrame, parentFrame, input, sendButton, cover)
  if cover.EnableMouse then
    cover:EnableMouse(true)
  end
  cover:Hide()

  -- Parented to the input so the fill or border art never covers it.
  local placeholder = input:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(placeholder, theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", input, "LEFT", TEXT_INSET, 0)
  placeholder:SetText(Localization.Text("Reply…"))
  placeholder:Show()

  local limit = ComposerLimit.Create(input)
  local enabled = true
  local holding = false
  local sendHovered = false

  -- Every read of the text goes through here: a secret or odd value reads as empty.
  local function getText()
    local raw = input:GetText()
    if SecretValue.Is(raw) or type(raw) ~= "string" then
      return ""
    end
    return raw
  end

  local function isHolding()
    return input:HasFocus() == true or getText() ~= ""
  end

  local function syncHold()
    local now = isHolding()
    if now ~= holding then
      holding = now
      onHoldChanged(now)
    end
  end

  local function syncPlaceholder()
    placeholder:SetShown(getText() == "")
  end

  local function paint()
    paintSend(not enabled, sendHovered)
  end

  local function submit()
    local text = getText()
    if enabled and string.find(text, "%S") then
      onSubmit(text)
    end
  end

  input:SetScript("OnTextChanged", function()
    local text = getText()
    GlyphCoverage.Apply(input, text)
    if not limit.accept(text) then
      return
    end
    syncPlaceholder()
    syncHold()
  end)
  input:SetScript("OnEditFocusGained", function()
    if not enabled then
      input:ClearFocus()
      return
    end
    onFocusChanged(true)
    syncHold()
    onFocusGained()
  end)
  input:SetScript("OnEditFocusLost", function()
    onFocusChanged(false)
    syncHold()
  end)
  input:SetScript("OnEnterPressed", submit)
  input:SetScript("OnEscapePressed", function()
    input:ClearFocus()
  end)
  sendButton:SetScript("OnClick", submit)
  sendButton:SetScript("OnEnter", function()
    sendHovered = true
    paint()
  end)
  sendButton:SetScript("OnLeave", function()
    sendHovered = false
    paint()
  end)
  cover:SetScript("OnMouseDown", function()
    onDisabledClick()
  end)

  LinkHooks.RegisterInput(input)

  local row = {
    frame = rowFrame,
    input = input,
    sendButton = sendButton,
    cover = cover,
    placeholder = placeholder,
    getText = getText,
    isHolding = isHolding,
  }

  function row.setTarget(channel)
    limit.setChannel(channel)
  end

  function row.setEnabled(nextEnabled, reasonText)
    enabled = nextEnabled == true
    if enabled then
      placeholder:SetText(Localization.Text("Reply…"))
    else
      placeholder:SetText(type(reasonText) == "string" and reasonText or "")
    end
    if input.EnableMouse then
      input:EnableMouse(enabled)
    end
    cover:SetShown(not enabled)
    paint()
    -- Last: dropping focus can re-enter setEnabled through onHoldChanged.
    if not enabled then
      input:ClearFocus()
    end
    syncHold()
  end

  function row.isEnabled()
    return enabled
  end

  function row.clear()
    input:SetText("")
    input:ClearFocus()
    limit.remember()
    placeholder:Show()
    syncHold()
  end

  function row.focus()
    if enabled then
      input:SetFocus()
    end
  end

  function row.setShown(shown)
    if shown ~= true then
      input:ClearFocus()
    end
    rowFrame:SetShown(shown == true)
  end

  function row.isShown()
    return rowFrame:IsShown()
  end

  function row.applyTheme(activeTheme)
    theme = activeTheme or theme
    local colors = theme.COLORS
    if native then
      setTextColor(input, ComposerSurface.NATIVE_TEXT_COLOR)
      setTextColor(placeholder, ComposerSurface.NATIVE_PLACEHOLDER_COLOR)
    else
      fill.setColor(colors.bg_message_input or colors.bg_input)
      setTextColor(input, colors.text_primary)
      setTextColor(placeholder, colors.text_secondary)
    end
    paint()
  end

  function row.height()
    return PreviewMetrics.REPLY_ROW_HEIGHT + PreviewMetrics.REPLY_ROW_GAP
  end

  row.applyTheme(theme)
  rowFrame:Hide()
  return row
end

ns.ToggleIconPreviewReplyRow = PreviewReplyRow

return PreviewReplyRow
