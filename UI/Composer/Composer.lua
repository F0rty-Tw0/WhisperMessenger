local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Skins = ns.Skins or require("WhisperMessenger.UI.Theme.Skins")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local applyPaneBackground = UIHelpers.applyPaneBackground
local setTextColor = UIHelpers.setTextColor

local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")

local Composer = {}

function Composer.Create(factory, parent, selectedContact, onSend, onEscape, getDoubleEscapeToClose)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  pane:SetAllPoints(parent)

  -- Pane background. Under the Blizzard skin (Azeroth / wow_native) paint
  -- with the FriendsFrame banner texture (same one the conversation header
  -- uses) so the composer reads as a distinct bottom banner. The dark
  -- `pane_inset_texture` blends into the DialogBox window backdrop and
  -- makes the composer look like it has no background. Modern presets
  -- fall back to a flat `bg_composer` color paint.
  local paneBg = pane:CreateTexture(nil, "BACKGROUND")
  paneBg:SetAllPoints(pane)
  local skinSpec = Skins.Get(Skins.GetActive())
  applyPaneBackground(paneBg, Theme.COLORS.bg_composer, skinSpec and skinSpec.pane_header_texture)

  -- Thin themed border drawn on the composer's own pane. The
  -- `composer_pane_border` line created by LayoutBuilder sits on the parent
  -- composerPane and is covered by this child frame, so without this the
  -- border is never visible at runtime. Each theme's `composer_pane_border`
  -- color (gold under Azeroth, navy under wow_default, grey under ElvUI,
  -- brown under Plumber) shows through here.
  -- Use the subtle `divider` color (semi-transparent, matches the contacts
  -- and search dividers) rather than the full-alpha `composer_pane_border`,
  -- so the composer edge reads as a faint 1px line consistent with the
  -- rest of the window's chrome instead of a highlighted frame.
  local composerBorderColor = Theme.COLORS.divider
  local composerBorder = UIHelpers.createBorderBox(pane, composerBorderColor, Theme.DIVIDER_THICKNESS, "OVERLAY")

  -- Input background texture (sits behind the EditBox)
  local inputBg = pane:CreateTexture(nil, "BACKGROUND")
  local buttonW = 44
  local buttonH = 30
  local buttonGap = 8
  local inputW = parentWidth - 24 - buttonW - buttonGap
  local inputH = Theme.LAYOUT.COMPOSER_INPUT_HEIGHT
  local inputX, inputY = 12, 8
  inputBg:SetSize(inputW, inputH)
  inputBg:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  applyColorTexture(inputBg, Theme.COLORS.bg_message_input or Theme.COLORS.bg_input)

  -- Send button (compact rounded pill)
  local createRoundedBackground = UIHelpers.createRoundedBackground
  local button = factory.CreateFrame("Button", nil, pane)
  button:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -(inputX - 5), inputY + (inputH - buttonH) / 2)
  button:SetSize(buttonW, buttonH)

  local sendBg = createRoundedBackground(button, 8)

  local function applySendColor(color)
    sendBg.setColor(color)
    button.sendBg = button.sendBg or {}
    button.sendBg.color = { color[1], color[2], color[3], color[4] or 1 }
  end
  local buttonLabel = button:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(buttonLabel, Theme.FONTS.composer_input)
  buttonLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
  buttonLabel:SetText("Send")
  button.label = buttonLabel

  -- Plain EditBox (no template)
  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  input:SetSize(inputW, inputH)
  input:SetText("")

  UIHelpers.setFontObject(input, Theme.FONTS.composer_input)
  if input.SetTextColor then
    input:SetTextColor(
      Theme.COLORS.text_primary[1],
      Theme.COLORS.text_primary[2],
      Theme.COLORS.text_primary[3],
      Theme.COLORS.text_primary[4] or 1
    )
  end
  if input.SetTextInsets then
    input:SetTextInsets(8, 8, 4, 4)
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

  -- Placeholder text
  local placeholder = pane:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(placeholder, Theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", input, "LEFT", 8, 0)
  placeholder:SetText("Type a message and press Enter")
  setTextColor(placeholder, Theme.COLORS.text_secondary)
  placeholder:Show()

  LinkHooks.RegisterInput(input)

  local sendDisabled = selectedContact == nil
  button.disabled = sendDisabled

  local function sendButtonTextColor()
    if sendDisabled then
      return Theme.COLORS.send_button_text_disabled or Theme.COLORS.text_secondary
    end
    return Theme.COLORS.send_button_text or Theme.COLORS.text_primary
  end

  local sendBgColor = sendDisabled and Theme.COLORS.send_button_disabled or Theme.COLORS.send_button
  applySendColor(sendBgColor)
  setTextColor(buttonLabel, sendButtonTextColor())

  button:SetScript("OnEnter", function()
    if not sendDisabled then
      applySendColor(Theme.COLORS.send_button_hover)
      setTextColor(buttonLabel, Theme.COLORS.send_button_text or Theme.COLORS.text_primary)
    end
  end)
  button:SetScript("OnLeave", function()
    if sendDisabled then
      applySendColor(Theme.COLORS.send_button_disabled)
    else
      applySendColor(Theme.COLORS.send_button)
    end
    setTextColor(buttonLabel, sendButtonTextColor())
  end)

  local function submitMessage()
    if sendDisabled then
      return
    end

    local text = input.GetText and input:GetText() or input.text
    if text == nil or text == "" then
      return
    end

    onSend({
      conversationKey = selectedContact.conversationKey,
      target = selectedContact.displayName,
      displayName = selectedContact.displayName,
      channel = selectedContact.channel,
      bnetAccountID = selectedContact.bnetAccountID,
      guid = selectedContact.guid,
      gameAccountName = selectedContact.gameAccountName,
      text = text,
    })

    input:SetText("")
  end

  input:SetScript("OnTextChanged", function()
    local text = input.GetText and input:GetText() or input.text or ""
    if text == "" then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end)

  input:SetScript("OnEnterPressed", function()
    submitMessage()
  end)
  button:SetScript("OnClick", function()
    submitMessage()
  end)
  input:SetScript("OnEscapePressed", function()
    if getDoubleEscapeToClose and getDoubleEscapeToClose() then
      if input.ClearFocus then
        input:ClearFocus()
      end
      return
    end
    if onEscape then
      onEscape()
      return
    end
    if input.ClearFocus then
      input:ClearFocus()
    end
  end)

  return {
    frame = pane,
    input = input,
    inputBg = inputBg,
    paneBg = paneBg,
    border = composerBorder,
    sendButton = button,
    setEnabled = function(enabled)
      sendDisabled = not enabled
      button.disabled = not enabled
      if sendDisabled then
        applySendColor(Theme.COLORS.send_button_disabled)
      else
        applySendColor(Theme.COLORS.send_button)
      end
      setTextColor(buttonLabel, sendButtonTextColor())
    end,
    refreshTheme = function()
      local refreshedSkin = Skins.Get(Skins.GetActive())
      applyPaneBackground(paneBg, Theme.COLORS.bg_composer, refreshedSkin and refreshedSkin.pane_header_texture)
      applyColorTexture(inputBg, Theme.COLORS.bg_message_input or Theme.COLORS.bg_input)
      UIHelpers.applyBorderBoxColor(composerBorder, Theme.COLORS.divider)
      if input.SetTextColor then
        input:SetTextColor(
          Theme.COLORS.text_primary[1],
          Theme.COLORS.text_primary[2],
          Theme.COLORS.text_primary[3],
          Theme.COLORS.text_primary[4] or 1
        )
      end
      setTextColor(placeholder, Theme.COLORS.text_secondary)
      if sendDisabled then
        applySendColor(Theme.COLORS.send_button_disabled)
      else
        applySendColor(Theme.COLORS.send_button)
      end
      setTextColor(buttonLabel, sendButtonTextColor())
    end,
    relayout = function(parentW)
      -- Prefer the pane's live width over the passed-in hint: the caller
      -- passes the full content width, but composerPane has a right-margin
      -- anchor (-20 in fake_ui, -8 in production WoW) that makes the pane
      -- narrower. Using the hint would overflow the right padding.
      local effectiveW = sizeValue(parent, "GetWidth", "width", parentW)
      if type(effectiveW) ~= "number" or effectiveW <= 0 then
        effectiveW = parentW
      end
      if type(effectiveW) ~= "number" or effectiveW <= 0 then
        return
      end
      local newInputW = effectiveW - 24 - buttonW - buttonGap
      input:SetSize(newInputW, inputH)
      inputBg:SetSize(newInputW, inputH)
    end,
  }
end

ns.Composer = Composer
return Composer
