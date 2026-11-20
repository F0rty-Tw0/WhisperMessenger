local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor

local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local SendButtonStyle = ns.ComposerSendButtonStyle or require("WhisperMessenger.UI.Composer.SendButtonStyle")
local ComposerSurface = ns.ComposerSurface or require("WhisperMessenger.UI.Composer.ComposerSurface")
local ComposerLayout = ns.ComposerLayout or require("WhisperMessenger.UI.Composer.ComposerLayout")
local ComposerLaunchers = ns.ComposerLaunchers or require("WhisperMessenger.UI.Composer.ComposerLaunchers")
local ReplyState = ns.ComposerReplyState or require("WhisperMessenger.UI.Composer.ReplyState")
local ComposerLimit = ns.ComposerLimit or require("WhisperMessenger.UI.Composer.ComposerLimit")
local ComposerSendFocus = ns.ComposerSendFocus or require("WhisperMessenger.UI.Composer.ComposerSendFocus")
local ComposerSubmit = ns.ComposerSubmit or require("WhisperMessenger.UI.Composer.ComposerSubmit")
local ComposerRows = ns.ComposerRows or require("WhisperMessenger.UI.Composer.ComposerRows")
local ComposerInputBox = ns.ComposerInputBox or require("WhisperMessenger.UI.Composer.ComposerInputBox")
local ComposerRelayout = ns.ComposerRelayout or require("WhisperMessenger.UI.Composer.ComposerRelayout")
local ComposerHistory = ns.ComposerHistory or require("WhisperMessenger.UI.Composer.ComposerHistory")
local ComposerPadHint = ns.ComposerPadHint or require("WhisperMessenger.UI.Composer.ComposerPadHint")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

local Composer = {}

-- options.nativeChrome: Native WoW HUD -> Blizzard input border art.
-- options.onDraftChanged(conversationKey, text): typed text to keep as draft.
-- options.getQuickReplies(): saved quick-reply list (nil = defaults).
-- options.onReplyChanged(replyTo | nil): the open conversation's reply target.
-- options.getDeselectOnSend(): the "deselect after sending" setting.
-- options.onHeightChanged(height): the bar's new height, when it changes.
-- options.showEmojiButton: false builds without the emoji button.
-- options.onNavTargetsChanged(): a button was shown or hidden (gamepad rescan).
-- options.getSentHistory(fits): sent lines for Up/Down recall (nil = no recall).
function Composer.Create(factory, parent, selectedContact, onSend, onEscape, getDoubleEscapeToClose, onTyping, options)
  options = type(options) == "table" and options or {}
  local nativeChrome = options.nativeChrome == true
  local onDraftChanged = options.onDraftChanged
  local replies = ReplyState.Create(function()
    return selectedContact.conversationKey
  end, options.onReplyChanged)
  local pane = factory.CreateFrame("Frame", nil, parent)
  pane:SetScript("OnHide", function()
    PickerStyles.HideTooltip()
  end)
  pane:SetAllPoints(parent)

  local paneBg = pane:CreateTexture(nil, "BACKGROUND")
  paneBg:SetAllPoints(pane)
  applyColorTexture(paneBg, Theme.COLORS.bg_composer)

  -- Faint border on the composer's own pane (subtle `divider` color);
  -- ComposerSurface trims it to a single top hairline.
  local composerBorder = UIHelpers.createBorderBox(pane, Theme.COLORS.divider, Theme.DIVIDER_THICKNESS, "OVERLAY")

  local sendDisabled = selectedContact == nil
  local button = factory.CreateFrame("Button", nil, pane)
  local paintSendButton = SendButtonStyle.Create(button)

  local inputBox = ComposerInputBox.Create(factory, pane)
  local box, input = inputBox.box, inputBox.input
  -- Controller hint: only where the pad can focus the box (template box, gamepad API).
  local padHint
  if inputBox.scroll ~= nil and FlavorCompat.HasGamepadUI() then
    padHint = ComposerPadHint.Create(factory, pane, { input = input, box = box })
  end
  local rows = ComposerRows.Create(pane, Theme.FONTS.composer_input)
  local limit = ComposerLimit.Create(input)
  local sendFocus = ComposerSendFocus.Create(pane, input, {
    isOn = function()
      return options.getDeselectOnSend ~= nil and options.getDeselectOnSend() == true
    end,
    isEnabled = function()
      return not sendDisabled
    end,
  }, { createFrame = factory.CreateFrame })
  local launchers = ComposerLaunchers.Create(factory, pane, input, {
    enabled = not sendDisabled,
    getMaxBytes = limit.messageMaxBytes,
    getQuickReplies = options.getQuickReplies,
    showEmoji = options.showEmojiButton ~= false,
  })
  local layoutParts = {
    pane = pane,
    box = box,
    scroll = inputBox.scroll,
    input = input,
    sendButton = button,
    emojiButton = launchers.emojiButton,
    emojiIcon = launchers.emojiButton.icon,
    quickReplyButton = launchers.quickReplyButton,
  }
  local relayout = ComposerRelayout.Create({
    parent = parent,
    pane = pane,
    parts = layoutParts,
    rows = rows,
    input = input,
    multiLine = inputBox.multiLine,
    onHeightChanged = options.onHeightChanged,
    getButtonCount = launchers.buttonCount,
  })

  local surface
  if nativeChrome then
    surface = ComposerSurface.CreateNative(input, composerBorder, paneBg, box)
  else
    surface = ComposerSurface.Create(pane, box, composerBorder)
  end
  surface.apply()

  -- Placeholder text. Parented to the input: the modern rounded fill is drawn
  -- on the box, and the input renders above every box and pane region, which
  -- would hide a FontString of theirs behind the fill.
  local placeholder = input:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(placeholder, Theme.FONTS.composer_input)
  placeholder:SetPoint("LEFT", box, "LEFT", ComposerLayout.TEXT_INSET_X, 0)
  placeholder:SetText(Localization.Text("Enter to send"))
  setTextColor(placeholder, Theme.COLORS.text_secondary)
  placeholder:Show()
  if surface.native then
    surface.apply(placeholder)
  end

  LinkHooks.RegisterInput(input)

  button.disabled = sendDisabled
  paintSendButton(sendDisabled, false)

  button:SetScript("OnEnter", function(self)
    paintSendButton(sendDisabled, true)
    -- The glyph has no text, so name the action in a tooltip.
    PickerStyles.ShowTooltipText(self, Localization.Text("Send"))
  end)
  button:SetScript("OnLeave", function()
    paintSendButton(sendDisabled, false)
    PickerStyles.HideTooltip()
  end)

  local submitMessage = ComposerSubmit.Create({
    input = input,
    replies = replies,
    limit = limit,
    sendFocus = sendFocus,
    selectedContact = selectedContact,
    onSend = onSend,
    onDraftChanged = onDraftChanged,
    isDisabled = function()
      return sendDisabled
    end,
    afterClear = relayout.refresh,
  })

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
  local history

  -- A recalled line is saved as the draft but sends no typing notice.
  local function onTextChanged()
    local text = input.GetText and input:GetText() or input.text or ""
    if not limit.accept(text, loadingDraft) then
      return
    end
    history.textChanged(text)
    syncPlaceholder(text)
    relayout.refresh()
    if onDraftChanged and not loadingDraft and selectedContact.conversationKey ~= nil then
      onDraftChanged(selectedContact.conversationKey, text)
    end
    if onTyping then
      local muted = loadingDraft or history.putting()
      onTyping(selectedContact, muted and "" or text)
    end
  end

  history = ComposerHistory.Create(input, { getSentHistory = options.getSentHistory, fits = limit.fits, refresh = onTextChanged })
  ComposerInputBox.SetTextChanged(input, onTextChanged)

  local function loadDraft(text)
    history.stop()
    loadingDraft = true
    input:SetText(text or "")
    loadingDraft = false
    limit.remember()
    syncPlaceholder(text)
    relayout.refresh()
    replies.sync()
  end

  input:SetScript("OnEnterPressed", submitMessage)
  button:SetScript("OnClick", submitMessage)
  ComposerInputBox.WireEscape(input, replies, getDoubleEscapeToClose, onEscape)

  return {
    frame = pane,
    box = box,
    scroll = inputBox.scroll,
    input = input,
    inputFill = surface.rounded,
    sheen = surface.sheen,
    paneBg = paneBg,
    border = composerBorder,
    sendButton = button,
    emojiButton = launchers.emojiButton,
    emojiPicker = launchers.emojiPicker,
    quickReplyButton = launchers.quickReplyButton,
    quickReplyPicker = launchers.quickReplyPicker,
    placeholder = placeholder,
    padHint = padHint,
    submit = submitMessage,
    loadDraft = loadDraft,
    -- Cap for the conversation's channel; set before its draft loads.
    setMaxBytes = limit.setChannel,
    setReply = function(conversationKey, replyTo)
      replies.set(conversationKey, replyTo)
      if input.SetFocus then
        input:SetFocus()
      end
    end,
    clearReply = replies.clear,
    forgetReply = function(conversationKey)
      replies.set(conversationKey, nil)
    end,
    moveReply = replies.move,
    setLanguage = function()
      placeholder:SetText(Localization.Text("Enter to send"))
    end,
    setEnabled = function(enabled)
      sendDisabled = not enabled
      button.disabled = not enabled
      launchers.setEnabled(enabled)
      PickerStyles.HideTooltip()
      paintSendButton(sendDisabled, false)
      sendFocus.sync()
    end,
    refreshTheme = function()
      if surface.native then
        surface.apply(placeholder)
      else
        applyColorTexture(paneBg, Theme.COLORS.bg_composer)
        surface.apply()
        setTextColor(input, Theme.COLORS.text_primary)
        setTextColor(placeholder, Theme.COLORS.text_secondary)
      end
      paintSendButton(sendDisabled, false)
      launchers.refreshTheme()
      if padHint then
        padHint.refreshTheme()
      end
      relayout.refreshWidth()
    end,
    getHeight = relayout.getHeight,
    -- The font changed: the same text may take other rows or row heights.
    remeasure = relayout.refresh,
    -- maxBarHeight caps the rows (nil = up to two).
    relayout = relayout.resize,
    setEmojiButtonShown = function(shown)
      local changed = launchers.setEmojiShown(shown == true)
      if not changed then
        return
      end
      relayout.refresh()
      if options.onNavTargetsChanged then
        options.onNavTargetsChanged()
      end
    end,
  }
end

ns.Composer = Composer
return Composer
