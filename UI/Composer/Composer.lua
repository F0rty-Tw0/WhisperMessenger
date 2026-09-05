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
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local EmojiPicker = ns.ComposerEmojiPicker or require("WhisperMessenger.UI.Composer.EmojiPicker")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")

local COMPOSER_MAX_BYTES = 255

local Composer = {}

local TRANSPARENT_COLOR = { 0, 0, 0, 0 }

function Composer.Create(factory, parent, selectedContact, onSend, onEscape, getDoubleEscapeToClose, onTyping)
  local pane = factory.CreateFrame("Frame", nil, parent)
  pane:SetScript("OnHide", function()
    PickerStyles.HideTooltip()
  end)
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
  local inputH = Theme.LAYOUT.COMPOSER_INPUT_HEIGHT
  local inputX, inputY = 12, 8
  local function getLauncherLayout(width)
    local emojiIconSize = ReactionAssets.GetIconSize() * 2
    local emojiButtonSize = math.max(30, emojiIconSize)
    return emojiIconSize, emojiButtonSize, width - 24 - buttonW - emojiButtonSize - (buttonGap * 2)
  end
  local emojiIconSize, emojiButtonSize, inputW = getLauncherLayout(parentWidth)
  inputBg:SetSize(inputW, inputH)
  inputBg:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  applyColorTexture(inputBg, Theme.COLORS.bg_message_input or Theme.COLORS.bg_input)

  -- Send button (compact rounded pill)
  local createRoundedBackground = UIHelpers.createRoundedBackground
  local button = factory.CreateFrame("Button", nil, pane)
  button:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -(inputX - 5), inputY + (inputH - buttonH) / 2)
  button:SetSize(buttonW, buttonH)

  local emojiButton = factory.CreateFrame("Button", nil, pane)
  emojiButton:SetPoint("RIGHT", button, "LEFT", -buttonGap, 0)
  emojiButton:SetSize(emojiButtonSize, emojiButtonSize)
  local emojiBg = createRoundedBackground(emojiButton, 8)
  emojiButton.bg = emojiBg
  local emojiIcon = emojiButton:CreateTexture(nil, "ARTWORK")
  emojiButton.icon = emojiIcon
  emojiIcon:SetPoint("CENTER", emojiButton, "CENTER", 0, 0)
  emojiIcon:SetSize(emojiIconSize, emojiIconSize)
  emojiIcon:SetTexture(ReactionAssets.TEXTURE)
  local emojiCoords = ReactionAssets.GetTexCoords("wink")
  emojiIcon:SetTexCoord(emojiCoords[1], emojiCoords[2], emojiCoords[3], emojiCoords[4])

  local sendBg = createRoundedBackground(button, 8)

  local function applySendColor(color)
    sendBg.setColor(color)
    button.sendBg = button.sendBg or {}
    button.sendBg.color = { color[1], color[2], color[3], color[4] or 1 }
  end

  local function applyEmojiColor(color)
    emojiBg.setColor(color)
  end
  local buttonLabel = button:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(buttonLabel, Theme.FONTS.composer_input)
  buttonLabel:SetPoint("CENTER", button, "CENTER", 0, 0)
  buttonLabel:SetText(Localization.Text("Send"))
  button.label = buttonLabel

  -- Plain EditBox (no template)
  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", inputX, inputY)
  input:SetSize(inputW, inputH)
  input:SetText("")

  UIHelpers.setFontObject(input, Theme.FONTS.composer_input)
  if input.SetTextColor then
    input:SetTextColor(Theme.COLORS.text_primary[1], Theme.COLORS.text_primary[2], Theme.COLORS.text_primary[3], Theme.COLORS.text_primary[4] or 1)
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
  -- WoW's chat protocol caps a single whisper at 255 bytes server-side;
  -- past that the message is silently truncated. Enforce the cap at the
  -- keystroke so users see the limit instead of finding out from a
  -- truncated send.
  if input.SetMaxBytes then
    input:SetMaxBytes(COMPOSER_MAX_BYTES)
  end

  -- Placeholder text
  local placeholder = pane:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(placeholder, Theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", input, "LEFT", 8, 0)
  placeholder:SetText(Localization.Text("Enter to send"))
  setTextColor(placeholder, Theme.COLORS.text_secondary)
  placeholder:Show()

  LinkHooks.RegisterInput(input)

  local function relayoutLauncher(width)
    local iconSize, launcherSize, inputWidth = getLauncherLayout(width)
    emojiIcon:SetSize(iconSize, iconSize)
    emojiButton:SetSize(launcherSize, launcherSize)
    input:SetSize(inputWidth, inputH)
    inputBg:SetSize(inputWidth, inputH)
  end

  local function currentParentWidth(fallback)
    local width = sizeValue(parent, "GetWidth", "width", fallback)
    if type(width) ~= "number" or width <= 0 then
      return fallback
    end
    return width
  end

  local sendDisabled = selectedContact == nil
  button.disabled = sendDisabled
  emojiButton.disabled = sendDisabled

  local function sendButtonTextColor()
    if sendDisabled then
      return Theme.COLORS.send_button_text_disabled or Theme.COLORS.text_secondary
    end
    return Theme.COLORS.send_button_text or Theme.COLORS.text_primary
  end

  local sendBgColor = sendDisabled and Theme.COLORS.send_button_disabled or Theme.COLORS.send_button
  applySendColor(sendBgColor)
  applyEmojiColor(TRANSPARENT_COLOR)
  setTextColor(buttonLabel, sendButtonTextColor())

  local emojiPicker = EmojiPicker.Create(factory, pane, emojiButton, function(key)
    if sendDisabled then
      return
    end
    local token = ":" .. key .. ":"
    if #(input:GetText() or "") + #token <= COMPOSER_MAX_BYTES then
      input:Insert(token)
    end
    if input.SetFocus then
      input:SetFocus()
    end
  end)
  emojiPicker:setEnabled(not sendDisabled)

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

  emojiButton:SetScript("OnEnter", function(self)
    if not sendDisabled then
      applyEmojiColor(PickerStyles.HighlightColor())
      PickerStyles.ShowTooltipText(self, Localization.Text("Emojis"))
    end
  end)
  emojiButton:SetScript("OnLeave", function()
    applyEmojiColor(TRANSPARENT_COLOR)
    PickerStyles.HideTooltip()
  end)
  emojiButton:SetScript("OnClick", function()
    PickerStyles.HideTooltip()
    if not sendDisabled then
      emojiPicker:toggle()
    end
  end)

  local function submitMessage()
    if sendDisabled then
      return
    end

    local text = input.GetText and input:GetText() or input.text
    if text == nil or text == "" then
      return
    end

    local accepted = onSend({
      conversationKey = selectedContact.conversationKey,
      target = selectedContact.displayName,
      displayName = selectedContact.displayName,
      channel = selectedContact.channel,
      bnetAccountID = selectedContact.bnetAccountID,
      conversationID = selectedContact.conversationID,
      guid = selectedContact.guid,
      gameAccountName = selectedContact.gameAccountName,
      text = text,
    })

    if accepted ~= false then
      input:SetText("")
    end
  end

  input:SetScript("OnTextChanged", function()
    local text = input.GetText and input:GetText() or input.text or ""
    if text == "" then
      placeholder:Show()
    else
      placeholder:Hide()
    end
    if onTyping then
      onTyping(selectedContact, text)
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
    emojiButton = emojiButton,
    emojiPicker = emojiPicker,
    placeholder = placeholder,
    setLanguage = function()
      buttonLabel:SetText(Localization.Text("Send"))
      placeholder:SetText(Localization.Text("Enter to send"))
    end,
    setEnabled = function(enabled)
      sendDisabled = not enabled
      button.disabled = not enabled
      emojiButton.disabled = not enabled
      emojiPicker:setEnabled(enabled)
      PickerStyles.HideTooltip()
      if sendDisabled then
        applySendColor(Theme.COLORS.send_button_disabled)
      else
        applySendColor(Theme.COLORS.send_button)
      end
      applyEmojiColor(TRANSPARENT_COLOR)
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
      if not sendDisabled and emojiButton:IsMouseOver() then
        applyEmojiColor(PickerStyles.HighlightColor())
      else
        applyEmojiColor(TRANSPARENT_COLOR)
      end
      relayoutLauncher(currentParentWidth(parentWidth))
      emojiPicker:refreshTheme()
      setTextColor(buttonLabel, sendButtonTextColor())
    end,
    relayout = function(parentW)
      -- Prefer the pane's live width over the passed-in hint: the caller
      -- passes the full content width, but composerPane has a right-margin
      -- anchor (-20 in fake_ui, -8 in production WoW) that makes the pane
      -- narrower. Using the hint would overflow the right padding.
      local effectiveW = currentParentWidth(parentW)
      if type(effectiveW) ~= "number" or effectiveW <= 0 then
        return
      end
      relayoutLauncher(effectiveW)
    end,
  }
end

ns.Composer = Composer
return Composer
