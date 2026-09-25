local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor

local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local EmojiPicker = ns.ComposerEmojiPicker or require("WhisperMessenger.UI.Composer.EmojiPicker")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local SendButtonStyle = ns.ComposerSendButtonStyle or require("WhisperMessenger.UI.Composer.SendButtonStyle")
local ComposerSurface = ns.ComposerSurface or require("WhisperMessenger.UI.Composer.ComposerSurface")
local ComposerLayout = ns.ComposerLayout or require("WhisperMessenger.UI.Composer.ComposerLayout")

local COMPOSER_MAX_BYTES = 255
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

local Composer = {}

local TRANSPARENT_COLOR = UIHelpers.TRANSPARENT

-- options.nativeChrome: Native WoW HUD -> Blizzard input border art.
-- options.onDraftChanged(conversationKey, text): typed text to keep as draft.
function Composer.Create(factory, parent, selectedContact, onSend, onEscape, getDoubleEscapeToClose, onTyping, options)
  options = type(options) == "table" and options or {}
  local nativeChrome = options.nativeChrome == true
  local onDraftChanged = options.onDraftChanged
  local pane = factory.CreateFrame("Frame", nil, parent)
  pane:SetScript("OnHide", function()
    PickerStyles.HideTooltip()
  end)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  pane:SetAllPoints(parent)

  local paneBg = pane:CreateTexture(nil, "BACKGROUND")
  paneBg:SetAllPoints(pane)
  applyColorTexture(paneBg, Theme.COLORS.bg_composer)

  -- Faint border on the composer's own pane (subtle `divider` color);
  -- ComposerSurface trims it to a single top hairline.
  local composerBorder = UIHelpers.createBorderBox(pane, Theme.COLORS.divider, Theme.DIVIDER_THICKNESS, "OVERLAY")

  local createRoundedBackground = UIHelpers.createRoundedBackground
  local button = factory.CreateFrame("Button", nil, pane)
  local emojiButton = factory.CreateFrame("Button", nil, pane)
  local emojiBg = createRoundedBackground(emojiButton, 8)
  emojiButton.bg = emojiBg
  local emojiIcon = emojiButton:CreateTexture(nil, "ARTWORK")
  emojiButton.icon = emojiIcon
  emojiIcon:SetPoint("CENTER", emojiButton, "CENTER", 0, 0)
  emojiIcon:SetTexture(ReactionAssets.TEXTURE)
  local emojiCoords = ReactionAssets.GetTexCoords("wink")
  emojiIcon:SetTexCoord(emojiCoords[1], emojiCoords[2], emojiCoords[3], emojiCoords[4])

  local function applyEmojiColor(color)
    emojiBg.setColor(color)
  end
  local paintSendButton = SendButtonStyle.Create(button)

  -- Plain EditBox (no template)
  local input = factory.CreateFrame("EditBox", nil, pane)
  input:SetText("")
  local layoutParts = { pane = pane, input = input, sendButton = button, emojiButton = emojiButton, emojiIcon = emojiIcon }
  ComposerLayout.Apply(layoutParts, parentWidth)

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
    input:SetMaxBytes(TextLimits.INPUT_MAX_BYTES)
  end
  local surface = nativeChrome and ComposerSurface.CreateNative(input, composerBorder, paneBg) or ComposerSurface.Create(pane, input, composerBorder)
  surface.apply()

  -- Placeholder text. Parented to the input: the modern rounded fill is drawn
  -- on the input frame, which renders above every pane region and would hide
  -- a pane-level FontString behind it.
  local placeholder = input:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(placeholder, Theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", input, "LEFT", 8, 0)
  placeholder:SetText(Localization.Text("Enter to send"))
  setTextColor(placeholder, Theme.COLORS.text_secondary)
  placeholder:Show()
  if surface.native then
    surface.apply(placeholder)
  end

  LinkHooks.RegisterInput(input)

  local function relayoutLauncher(width)
    ComposerLayout.Apply(layoutParts, width)
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

  paintSendButton(sendDisabled, false)
  applyEmojiColor(TRANSPARENT_COLOR)

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

  button:SetScript("OnEnter", function(self)
    paintSendButton(sendDisabled, true)
    -- The glyph has no text, so name the action in a tooltip.
    PickerStyles.ShowTooltipText(self, Localization.Text("Send"))
  end)
  button:SetScript("OnLeave", function()
    paintSendButton(sendDisabled, false)
    PickerStyles.HideTooltip()
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
      if onDraftChanged then
        onDraftChanged(selectedContact.conversationKey, "")
      end
    end
  end

  local function syncPlaceholder(text)
    if text == nil or text == "" then
      placeholder:Show()
    else
      placeholder:Hide()
    end
  end

  -- True while loadDraft swaps in another conversation's text: that text is
  -- already stored, and it is not the player typing.
  local loadingDraft = false

  input:SetScript("OnTextChanged", function()
    local text = input.GetText and input:GetText() or input.text or ""
    syncPlaceholder(text)
    if onDraftChanged and not loadingDraft and selectedContact.conversationKey ~= nil then
      onDraftChanged(selectedContact.conversationKey, text)
    end
    if onTyping then
      onTyping(selectedContact, loadingDraft and "" or text)
    end
  end)

  local function loadDraft(text)
    loadingDraft = true
    input:SetText(text or "")
    loadingDraft = false
    syncPlaceholder(text)
  end

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
    sheen = surface.sheen,
    paneBg = paneBg,
    border = composerBorder,
    sendButton = button,
    emojiButton = emojiButton,
    emojiPicker = emojiPicker,
    placeholder = placeholder,
    loadDraft = loadDraft,
    setLanguage = function()
      placeholder:SetText(Localization.Text("Enter to send"))
    end,
    setEnabled = function(enabled)
      sendDisabled = not enabled
      button.disabled = not enabled
      emojiButton.disabled = not enabled
      emojiPicker:setEnabled(enabled)
      PickerStyles.HideTooltip()
      paintSendButton(sendDisabled, false)
      applyEmojiColor(TRANSPARENT_COLOR)
    end,
    refreshTheme = function()
      if surface.native then
        surface.apply(placeholder)
      else
        applyColorTexture(paneBg, Theme.COLORS.bg_composer)
        surface.apply()
        if input.SetTextColor then
          input:SetTextColor(
            Theme.COLORS.text_primary[1],
            Theme.COLORS.text_primary[2],
            Theme.COLORS.text_primary[3],
            Theme.COLORS.text_primary[4] or 1
          )
        end
        setTextColor(placeholder, Theme.COLORS.text_secondary)
      end
      paintSendButton(sendDisabled, false)
      if not sendDisabled and emojiButton:IsMouseOver() then
        applyEmojiColor(PickerStyles.HighlightColor())
      else
        applyEmojiColor(TRANSPARENT_COLOR)
      end
      relayoutLauncher(currentParentWidth(parentWidth))
      emojiPicker:refreshTheme()
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
