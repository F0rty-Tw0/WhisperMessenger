local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local LauncherButton = ns.ComposerLauncherButton or require("WhisperMessenger.UI.Composer.LauncherButton")
local EmojiPicker = ns.ComposerEmojiPicker or require("WhisperMessenger.UI.Composer.EmojiPicker")
local QuickReplyPicker = ns.ComposerQuickReplyPicker or require("WhisperMessenger.UI.Composer.QuickReplyPicker")
local QuickReplies = ns.QuickReplies or require("WhisperMessenger.Model.QuickReplies")
local ComposerLayout = ns.ComposerLayout or require("WhisperMessenger.UI.Composer.ComposerLayout")

-- The composer's picker buttons (quick replies, emoji) and their pickers.
-- Picks are inserted at the input's cursor; nothing is ever sent from here.
local ComposerLaunchers = {}

local function quickReplyIconColor()
  return Theme.COLORS.action_icon or Theme.COLORS.text_secondary
end

-- options = { enabled, getMaxBytes, getQuickReplies, showEmoji }
-- showEmoji false hides the emoji button; anything else shows it.
function ComposerLaunchers.Create(factory, pane, input, options)
  local enabled = options.enabled == true
  local emojiShown = options.showEmoji ~= false
  local function isEnabled()
    return enabled
  end
  local emojiPicker, quickReplyPicker

  local emojiButton = LauncherButton.Create(factory, pane, {
    tooltip = "Emojis",
    isEnabled = isEnabled,
    onClick = function()
      emojiPicker:toggle()
    end,
  })
  emojiButton.icon:SetTexture(ReactionAssets.TEXTURE)
  local emojiCoords = ReactionAssets.GetTexCoords("wink")
  emojiButton.icon:SetTexCoord(emojiCoords[1], emojiCoords[2], emojiCoords[3], emojiCoords[4])

  local quickReplyButton = LauncherButton.Create(factory, pane, {
    tooltip = "Quick replies",
    hint = "Edit this list in Options > Behavior.",
    isEnabled = isEnabled,
    onClick = function()
      quickReplyPicker:toggle()
    end,
  })
  quickReplyButton.icon:SetTexture(Theme.TEXTURES.quick_reply_icon)
  UIHelpers.applyVertexColor(quickReplyButton.icon, quickReplyIconColor())

  -- Insert only when the whole text still fits the current cap.
  local function insertAtCursor(text)
    if not enabled then
      return
    end
    if #(input:GetText() or "") + #text <= options.getMaxBytes() then
      input:Insert(text)
    end
    if input.SetFocus then
      input:SetFocus()
    end
  end

  emojiPicker = EmojiPicker.Create(factory, pane, emojiButton, function(key)
    insertAtCursor(":" .. key .. ":")
  end)
  quickReplyPicker = QuickReplyPicker.Create(factory, pane, quickReplyButton, function()
    return QuickReplies.List(options.getQuickReplies and options.getQuickReplies() or nil)
  end, insertAtCursor)

  local launchers = {
    emojiButton = emojiButton,
    emojiPicker = emojiPicker,
    quickReplyButton = quickReplyButton,
    quickReplyPicker = quickReplyPicker,
  }

  function launchers.setEnabled(nextEnabled)
    enabled = nextEnabled == true
    emojiButton.paint(false)
    quickReplyButton.paint(false)
    emojiPicker:setEnabled(enabled)
    quickReplyPicker:setEnabled(enabled)
  end

  function launchers.refreshTheme()
    emojiButton.paint(enabled and emojiButton:IsMouseOver())
    quickReplyButton.paint(enabled and quickReplyButton:IsMouseOver())
    UIHelpers.applyVertexColor(quickReplyButton.icon, quickReplyIconColor())
    emojiPicker:refreshTheme()
    quickReplyPicker:refreshTheme()
  end

  -- True only when the shown state changed. Hiding also closes the picker.
  -- `shown` is a boolean; Composer converts the setting at its edge.
  function launchers.setEmojiShown(shown)
    if shown == emojiShown then
      return false
    end
    emojiShown = shown
    emojiButton:SetShown(shown)
    local pickerOpen = emojiPicker.frame:IsShown()
    if not shown and pickerOpen then
      emojiPicker:close()
    end

    return true
  end

  -- Buttons on the composer row: quick reply, emoji when shown, send.
  function launchers.buttonCount()
    if emojiShown then
      return ComposerLayout.FULL_BUTTON_COUNT
    end

    return ComposerLayout.FULL_BUTTON_COUNT - 1
  end

  emojiButton:SetShown(emojiShown)
  launchers.setEnabled(enabled)
  return launchers
end

ns.ComposerLaunchers = ComposerLaunchers
return ComposerLaunchers
